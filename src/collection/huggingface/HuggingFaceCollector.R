HuggingFaceCollector <- R6::R6Class("HuggingFaceCollector",
  public = list(
    initialize = function(config, store, http, pilot = FALSE) {
      private$config <- config
      private$store <- store
      private$progress <- http$progress
      private$pilot <- pilot
      private$client <- HuggingFaceClient$new(http, config, store)
      private$policy <- EligibilityPolicy$new(config)
      private$ai <- AIClassifier$new(config)
      private$matcher <- TextMatcher$new(config)
      private$tools <- ProtocolTools$new()
      private$time <- TimePolicy$new(config$settings$protocol$cutoff)
    },
    run = function() {
      private$store$start("huggingface", private$pilot)
      for (type in c("model", "dataset")) private$collect_type(type)
      private$store$finish()
    }
  ),
  private = list(
    config = NULL, store = NULL, pilot = FALSE, client = NULL, policy = NULL,
    ai = NULL, matcher = NULL, tools = NULL, time = NULL, progress = NULL,
    collect_type = function(type) {
      progress <- list(seen = new.env(parent = emptyenv()), discovered = 0L, processed = 0L)
      maximum <- private$config$limit("hf_discovered_per_type", private$pilot)
      label <- if (type == "model") "modelos" else "datasets"
      private$progress$scope(paste("Tipo:", label), label, timer = "Tipo")
      for (license in private$config$osi$licenses) {
        if (progress$discovered >= maximum) break
        private$progress$activity("Descobrindo projetos", paste(label, "| licença:", license$id))
        private$client$walk_discovery(type, license$hf_filter, function(item) {
          progress <<- private$process_items(list(item), progress, type, maximum)
          progress$discovered < maximum
        })
      }
      private$progress$report(paste("Coleta de", label, "concluída"), counts = FALSE)
    },
    process_items = function(items, progress, type, maximum) {
      for (item in items) {
          id <- private$tools$scalar(item$id, private$tools$scalar(item$modelId))
          if (!nzchar(id)) {
            private$store$problem("invalid_repository_response", "Hugging Face discovery",
              "Projeto sem identificador; item descartado")
            next
          }
          if (exists(id, progress$seen, inherits = FALSE)) next
          if (progress$discovered >= maximum) break
          progress$seen[[id]] <- TRUE
          progress$discovered <- progress$discovered + 1L
          repo <- private$repository(type, item)
          if (is.null(repo) || repo$status != "eligible") next
          if (progress$processed >= private$config$limit("hf_eligible_per_type", private$pilot)) next
          private$discussions(repo)
          progress$processed <- progress$processed + 1L
      }
      progress
    },
    repository = function(type, item) {
      repo <- private$client$repository(type, item)
      if (is.null(repo)) return(NULL)
      ai <- private$ai$huggingface(repo$metadata, repo$card)
      decision <- private$policy$assess(repo, ai)
      repo$status <- decision$status
      repo$reason <- decision$reason
      repo$ai <- ai
      private$store$repository(repo)
      repo
    },
    excluded_discussion = function(item) {
      any(c(isTRUE(item$isPullRequest), !identical(item$status, "closed"),
        private$policy$bot(item$author, "huggingface"), !private$time$eligible(item$createdAt)))
    },
    discussions = function(repo) {
      discussions <- private$client$discussions(repo,
        private$config$limit("hf_discussions_per_repo", private$pilot))
      seen <- character()
      for (item in discussions) {
        if (private$excluded_discussion(item)) next
        if (item$num %in% seen) next
        seen <- c(seen, item$num)
        discussion <- private$client$discussion(repo, item$num)
        if (is.null(discussion) || private$excluded_discussion(discussion)) next
        private$discussion(repo, discussion)
      }
    },
    discussion = function(repo, item) {
      if (!private$time$eligible(item$createdAt)) return(invisible(NULL))
      key <- private$tools$key("huggingface", "discussion", paste(repo$type, repo$id, item$num, sep = ":"))
      prefix <- if (repo$type == "dataset") "datasets/" else ""
      url <- paste0("https://huggingface.co/", prefix, repo$id, "/discussions/", item$num)
      main <- list(key = key, unit_key = key, repo_key = repo$key, platform = "huggingface",
        kind = "discussion", created = item$createdAt, text = private$tools$scalar(item$title),
        url = url, metadata = item)
      private$save(main, main$created)
      for (event in item$events) private$event(event, main)
    },
    event = function(event, main) {
      if (!private$time$eligible(event$createdAt)) return(invisible(NULL))
      text <- private$tools$text(list(event$data$latest$raw, event$data$content, event$data$title,
                                      event$data$oldTitle, event$data$newTitle))
      if (!nzchar(text)) return(invisible(NULL))
      id <- private$tools$scalar(event$id)
      if (!nzchar(id)) {
        private$store$problem("event_id_missing", main$url, "Evento textual sem identificador")
        return(invisible(NULL))
      }
      artifact <- list(key = paste0(main$key, ":event:", id), unit_key = main$key,
        repo_key = main$repo_key, platform = "huggingface", kind = "event",
        created = event$createdAt, text = text, url = main$url, metadata = event)
      private$save(artifact, main$created)
    },
    save = function(artifact, created) {
      private$store$artifact(artifact)
      for (evidence in private$matcher$find(artifact, created)) private$store$evidence(evidence, "huggingface")
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
