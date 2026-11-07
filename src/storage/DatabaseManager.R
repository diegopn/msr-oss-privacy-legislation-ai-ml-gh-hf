DatabaseManager <- R6::R6Class("DatabaseManager",
  public = list(
    staging = NULL, target = NULL,
    initialize = function(config, pilot = FALSE, fresh = FALSE, platform = NULL) {
      private$config <- config
      private$pilot <- pilot
      if (!pilot && (length(platform) != 1L || !platform %in% c("github", "huggingface"))) {
        stop("Informe a plataforma do banco oficial.", call. = FALSE)
      }
      private$platform <- if (pilot) "pilot" else platform
      self$target <- config$database_path(if (pilot) NULL else platform, pilot = pilot)
      if (pilot) private$reset_pilot()
      dir.create(dirname(self$target), recursive = TRUE, showWarnings = FALSE)
      self$staging <- tempfile(paste0(".staging-", private$platform, "-"), dirname(self$target), ".sqlite")
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
        private$previous <- destination
      }
      private$had_target <- file.exists(self$target)
      if (!file.rename(self$staging, self$target)) {
        if (!is.null(private$previous)) file.copy(private$previous, self$target, overwrite = TRUE)
        stop("Não foi possível promover o banco temporário")
      }
      private$promoted <- TRUE
      invisible(self$target)
    },
    rollback_promotion = function() {
      if (!private$promoted) return(invisible(FALSE))
      if (private$had_target && !is.null(private$previous) && file.exists(private$previous)) {
        if (!file.copy(private$previous, self$target, overwrite = TRUE)) {
          stop("Falha ao restaurar o banco oficial anterior: ", self$target, call. = FALSE)
        }
      } else unlink(self$target)
      private$promoted <- FALSE
      invisible(TRUE)
    },
    preserve_failure = function() {
      if (!file.exists(self$staging)) return(invisible(NULL))
      destination <- sub("\\.sqlite$", "-failed.sqlite", self$staging)
      if (!file.rename(self$staging, destination)) destination <- self$staging
      message("Banco de diagnóstico preservado em: ", destination)
      invisible(destination)
    }
  ), private = list(
    config = NULL, pilot = FALSE, platform = NULL, previous = NULL,
    had_target = FALSE, promoted = FALSE,
    reset_pilot = function() {
      paths <- private$config$settings$paths
      directories <- c(dirname(self$target), private$config$path(file.path(paths$raw, "pilot")))
      directories <- vapply(directories, normalizePath, "", mustWork = FALSE)
      root <- paste0(normalizePath(private$config$root, mustWork = TRUE), "/")
      traversal <- vapply(strsplit(directories, "/", fixed = TRUE), function(parts) ".." %in% parts, logical(1))
      if (any(basename(directories) != "pilot" | !startsWith(directories, root) | traversal)) {
        stop("A limpeza exige subpastas pilot dentro do projeto")
      }
      official_paths <- c(paths[c("github_database", "huggingface_database", "raw", "archive", "analysis")])
      official <- vapply(unlist(official_paths), function(path) {
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
