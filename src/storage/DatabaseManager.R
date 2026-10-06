DatabaseManager <- R6::R6Class("DatabaseManager",
  public = list(
    staging = NULL, target = NULL,
    initialize = function(config, pilot = FALSE, fresh = FALSE) {
      private$config <- config
      private$pilot <- pilot
      relative <- if (pilot) config$settings$paths$pilot_database else config$settings$paths$database
      self$target <- config$path(relative)
      if (pilot) private$reset_pilot()
      dir.create(dirname(self$target), recursive = TRUE, showWarnings = FALSE)
      self$staging <- tempfile(".staging-", dirname(self$target), ".sqlite")
      if (!fresh && file.exists(self$target)) {
        if (!file.copy(self$target, self$staging)) stop("Não foi possível preparar o banco temporário")
      }
    },
    promote = function() {
      if (!private$pilot && file.exists(self$target)) {
        archive <- private$config$path(private$config$settings$paths$archive)
        dir.create(archive, recursive = TRUE, showWarnings = FALSE)
        destination <- tempfile(paste0(basename(self$target), "-"), archive, ".sqlite")
        if (!file.copy(self$target, destination)) stop("Não foi possível arquivar o banco anterior")
      }
      if (!file.rename(self$staging, self$target)) stop("Não foi possível promover o banco temporário")
      invisible(self$target)
    },
    preserve_failure = function() {
      if (!file.exists(self$staging)) return(invisible(NULL))
      destination <- sub("\\.sqlite$", "-failed.sqlite", self$staging)
      if (!file.rename(self$staging, destination)) destination <- self$staging
      message("Banco de diagnóstico preservado em: ", destination)
      invisible(destination)
    }
  ), private = list(
    config = NULL, pilot = FALSE,
    reset_pilot = function() {
      paths <- private$config$settings$paths
      directories <- c(dirname(self$target), private$config$path(file.path(paths$raw, "pilot")))
      directories <- vapply(directories, normalizePath, "", mustWork = FALSE)
      root <- paste0(normalizePath(private$config$root, mustWork = TRUE), "/")
      traversal <- vapply(strsplit(directories, "/", fixed = TRUE), function(parts) ".." %in% parts, logical(1))
      if (any(basename(directories) != "pilot" | !startsWith(directories, root) | traversal)) {
        stop("A limpeza exige subpastas pilot dentro do projeto")
      }
      official <- vapply(unlist(paths[c("database", "raw", "archive", "analysis")]), function(path) {
        normalizePath(private$config$path(path), mustWork = FALSE)
      }, "")
      if (any(vapply(directories, function(directory) {
        any(official == directory | startsWith(official, paste0(directory, "/")))
      }, logical(1)))) stop("As pastas pilot não podem conter dados oficiais")
      for (directory in directories) {
        if (unlink(directory, recursive = TRUE) != 0L) stop("Falha ao limpar o piloto anterior: ", directory)
      }
    }
  ),
  lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
