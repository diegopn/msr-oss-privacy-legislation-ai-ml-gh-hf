GitHubClient <- R6::R6Class("GitHubClient",
  public = list(
    initialize = function(http, config, store) {
      private$http <- http
      private$config <- config
      private$store <- store
      private$tools <- ProtocolTools$new()
      private$pages <- Pagination$new(http, store)
      private$ai <- AIClassifier$new(config)
      private$policy <- EligibilityPolicy$new(config)
    },
    repository = function(identifier) {
      private$http$progress$activity("Avaliando repositórios")
      url <- paste0("https://api.github.com/repos/", identifier)
      response <- private$http$get(url, optional = TRUE)
      if (is.null(response)) {
        private$store$unavailable(identifier, "repository_unavailable")
        return(private$record(identifier, list(), list(status = "review", evidence = list()), FALSE))
      }
      metadata <- response$data
      if (!is.list(metadata)) {
        private$store$problem("invalid_repository_response", url, "Metadados do repositório não são um objeto JSON")
        return(private$record(identifier, list(), list(status = "review", evidence = list()), FALSE))
      }
      preliminary <- private$record(identifier, metadata, list(status = "review", evidence = list()), TRUE)
      if (private$policy$assess(preliminary, preliminary$ai)$status == "excluded") return(preliminary)
      files <- private$files(url, metadata)
      ai <- private$ai$github(metadata, files$manifests, files$readme)
      private$record(identifier, metadata, ai, TRUE)
    },
    comments = function(issue, limit = Inf) {
      private$http$progress$activity("Coletando comentários")
      url <- paste0(issue$comments_url, "?per_page=", private$config$settings$http$page_size)
      private$pages$collect(url, limit = limit)
    }
  ),
  private = list(
    http = NULL, config = NULL, store = NULL, tools = NULL, pages = NULL, ai = NULL, policy = NULL,
    record = function(id, metadata, ai, available) {
      list(key = private$tools$key("github", "repository", id), platform = "github",
        type = "repository", id = id, created = private$tools$scalar(metadata$created_at),
        private = metadata$private, disabled = metadata$disabled, available = available,
        license = metadata$license$spdx_id, fork = metadata$fork, archived = metadata$archived,
        metadata = metadata, ai = ai)
    },
    files = function(url, metadata) {
      preliminary <- private$ai$github(metadata)
      needs_readme <- !length(preliminary$evidence$discovery)
      response <- private$http$get(paste0(url, "/contents"), optional = TRUE)
      if (is.null(response)) return(list(manifests = list(), readme = ""))
      entries <- response$data
      if (!is.list(entries)) {
        private$store$problem("invalid_repository_files", url, "Listagem de arquivos não é uma lista JSON")
        return(list(manifests = list(), readme = ""))
      }
      names <- vapply(entries, function(entry) private$tools$scalar(entry$name), "")
      desired <- private$config$settings$ai$manifests
      chosen <- which(names %in% desired)
      manifests <- list()
      for (index in chosen) manifests[[names[[index]]]] <- private$content(entries[[index]]$url)
      readme <- ""
      if (needs_readme) {
        readmes <- which(grepl("^readme(\\.(md|rst|txt|markdown))?$", names, ignore.case = TRUE))
        if (length(readmes)) readme <- private$content(entries[[readmes[[1L]]]]$url)
      }
      list(manifests = manifests, readme = readme)
    },
    content = function(url) {
      response <- private$http$get(url, optional = TRUE)
      if (is.null(response)) return("")
      data <- response$data
      if (!is.list(data) || !identical(data$encoding, "base64") || is.null(data$content)) {
        private$store$problem("content_unreadable", url, "Arquivo sem conteúdo base64 completo")
        return("")
      }
      tryCatch(rawToChar(jsonlite::base64_dec(gsub("\\s", "", data$content, perl = TRUE))),
        error = function(error) {
          private$store$problem("content_unreadable", url, conditionMessage(error))
          ""
        })
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
