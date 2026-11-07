RunLock <- R6::R6Class("RunLock",
  public = list(
    initialize = function(root, platforms = c("github", "huggingface")) {
      valid <- c("github", "huggingface")
      if (!length(platforms) || any(!platforms %in% valid) || anyDuplicated(platforms)) {
        stop("Plataformas inválidas para a trava da execução.", call. = FALSE)
      }
      private$paths <- file.path(root, ".run-lock", platforms)
      dir.create(file.path(root, ".run-lock"), recursive = TRUE, showWarnings = FALSE)
      for (path in private$paths) {
        if (!dir.create(path, showWarnings = FALSE)) {
          self$release()
          stop("Outra execução está usando a plataforma correspondente. Verifique o processo antes de remover a trava.",
               call. = FALSE)
        }
        private$owned <- c(private$owned, path)
        writeLines(as.character(Sys.getpid()), file.path(path, "pid"))
      }
    },
    release = function() {
      if (length(private$owned)) unlink(private$owned, recursive = TRUE)
      private$owned <- character()
      invisible(TRUE)
    }
  ), private = list(paths = character(), owned = character()),
  lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
