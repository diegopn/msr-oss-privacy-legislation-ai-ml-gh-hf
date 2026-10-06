CollectionJournal <- R6::R6Class("CollectionJournal",
  public = list(
    initialize = function(config) {
      private$path <- file.path(dirname(config$path(config$settings$paths$database)), "latest-collections.json")
      private$tools <- ProtocolTools$new()
    },
    read = function() {
      if (!file.exists(private$path)) return(list())
      private$tools$decode(paste(readLines(private$path, warn = FALSE), collapse = "\n"))
    },
    record = function(platform, run_id, status, config) {
      data <- self$read()
      data[[platform]] <- list(run_id = run_id, status = status,
        config_hash = config$fingerprint, cutoff = config$settings$protocol$cutoff,
        recorded = private$tools$now())
      dir.create(dirname(private$path), recursive = TRUE, showWarnings = FALSE)
      temporary <- tempfile("journal-", dirname(private$path))
      writeLines(private$tools$json(data), temporary)
      if (!file.rename(temporary, private$path)) stop("Falha ao atualizar o diário de coletas")
    }
  ), private = list(path = NULL, tools = NULL),
  lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
