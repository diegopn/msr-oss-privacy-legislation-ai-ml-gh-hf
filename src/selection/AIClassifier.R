AIClassifier <- R6::R6Class("AIClassifier",
  public = list(
    initialize = function(config) {
      private$ai <- config$settings$ai
      private$tools <- ProtocolTools$new()
      private$version <- config$settings$protocol$version
    },
    github = function(metadata, manifests = list(), readme = "", code = list()) {
      discovery_text <- private$tools$text(list(metadata$name, metadata$description,
                                               metadata$html_url, metadata$topics, readme))
      discovery <- private$tools$matches(discovery_text, c(private$ai$terms, private$ai$topics))
      dependencies <- private$file_matches(manifests, private$ai$libraries)
      source <- private$file_matches(code, private$ai$libraries)
      production <- private$file_matches(code, private$ai$production_signals)
      consumption <- private$file_matches(code, private$ai$consumption_signals)
      technical <- length(dependencies) + length(source) > 0L ||
        (length(production) > 0L && length(consumption) > 0L)
      signals <- c(private$tools$signals(discovery_text, discovery, "github:metadata_and_readme",
        "ai_discovery", private$version),
        private$file_signals(manifests, private$ai$libraries, "manifest", "ai_library"),
        private$file_signals(code, private$ai$libraries, "code", "ai_library"),
        private$file_signals(code, private$ai$production_signals, "code", "model_production"),
        private$file_signals(code, private$ai$consumption_signals, "code", "model_consumption"))
      private$result(length(discovery) > 0L && technical,
                     list(discovery = discovery, dependencies = dependencies, source = source,
                          production = production, consumption = consumption), signals)
    },
    huggingface = function(metadata, card = list()) {
      structured <- list(metadata$pipeline_tag, metadata$library_name,
        metadata$task_categories, metadata$task_ids,
        metadata$cardData$pipeline_tag, metadata$cardData$library_name,
        metadata$cardData$task_categories, metadata$cardData$task_ids,
        card$pipeline_tag, card$library_name, card$task_categories, card$task_ids)
      values <- tolower(unlist(structured, use.names = FALSE))
      tasks <- intersect(values, private$ai$hf_tasks)
      libraries <- intersect(values, private$ai$hf_libraries)
      # Somente prefixos estruturados nas tags. Tags genéricas não confirmam IA.
      tags <- unlist(metadata$tags, use.names = FALSE)
      task_tags <- sub("^(task|task_categories|task_ids|pipeline_tag):", "",
                       tags[grepl("^(task|task_categories|task_ids|pipeline_tag):", tags)])
      library_tags <- sub("^library:", "", tags[grepl("^library:", tags)])
      tasks <- unique(c(tasks, intersect(task_tags, private$ai$hf_tasks)))
      libraries <- unique(c(libraries, intersect(library_tags, private$ai$hf_libraries)))
      private$result(length(tasks) + length(libraries) > 0L,
        list(tasks = tasks, libraries = libraries),
        c(private$tools$signals(private$tools$text(c(structured, tags)), tasks,
            "huggingface:structured_metadata_or_card_header", "ai_task", private$version),
          private$tools$signals(private$tools$text(c(structured, tags)), libraries,
            "huggingface:structured_metadata_or_card_header", "ai_library", private$version)))
    }
  ),
  private = list(
    ai = NULL, tools = NULL, version = NULL,
    result = function(accepted, evidence, signals) {
      list(status = if (accepted) "eligible" else "review", evidence = evidence, signals = signals)
    },
    file_signals = function(files, terms, origin, label) {
      result <- list()
      for (name in names(files)) result <- c(result, private$tools$signals(files[[name]], terms,
        paste0(origin, ":", name), label, private$version))
      result
    },
    file_matches = function(files, vocabulary) {
      output <- list()
      for (name in names(files)) {
        terms <- private$tools$matches(files[[name]], vocabulary)
        if (length(terms)) output[[name]] <- list(terms = terms, text = files[[name]])
      }
      output
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
