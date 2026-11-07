CollectionJournal <- R6::R6Class("CollectionJournal",
  public = list(
    initialize = function(config) {
      private$directories <- lapply(c("github", "huggingface"), function(platform) {
        dirname(config$database_path(platform))
      })
      names(private$directories) <- c("github", "huggingface")
      private$tools <- ProtocolTools$new()
    },
    read = function(platform = NULL) {
      platforms <- if (is.null(platform)) c("github", "huggingface") else platform
      if (any(!platforms %in% c("github", "huggingface"))) stop("Plataforma inválida no diário.", call. = FALSE)
      records <- lapply(platforms, function(item) {
        path <- private$path(item)
        if (!file.exists(path)) return(NULL)
        private$tools$decode(paste(readLines(path, warn = FALSE), collapse = "\n"))
      })
      names(records) <- platforms
      if (!is.null(platform)) records[[1L]] else records[!vapply(records, is.null, logical(1))]
    },
    record = function(platform, run_id, status, config) {
      if (!platform %in% c("github", "huggingface")) stop("Plataforma inválida no diário.", call. = FALSE)
      data <- list(platform = platform, run_id = run_id, status = status,
        config_hash = config$fingerprint, cutoff = config$settings$protocol$cutoff,
        recorded = private$tools$now())
      path <- private$path(platform)
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      temporary <- tempfile("journal-", dirname(path))
      on.exit(unlink(temporary), add = TRUE)
      writeLines(private$tools$json(data), temporary)
      if (!file.rename(temporary, path)) stop("Falha ao atualizar o diário de coletas")
    }
  ), private = list(
    directories = NULL, tools = NULL,
    path = function(platform) file.path(private$directories[[platform]], paste0("latest-collection-", platform, ".json"))
  ),
  lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
