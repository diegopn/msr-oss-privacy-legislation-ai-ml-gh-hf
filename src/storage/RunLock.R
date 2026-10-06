RunLock <- R6::R6Class("RunLock",
  public = list(
    initialize = function(root) {
      private$path <- file.path(root, ".run-lock")
      dir.create(dirname(private$path), recursive = TRUE, showWarnings = FALSE)
      if (!dir.create(private$path, showWarnings = FALSE)) {
        stop("Outra execução possui .run-lock. Verifique o processo antes de remover o lock.",
             call. = FALSE)
      }
      writeLines(as.character(Sys.getpid()), file.path(private$path, "pid"))
      private$owned <- TRUE
    },
    release = function() {
      if (private$owned) unlink(private$path, recursive = TRUE)
      private$owned <- FALSE
      invisible(TRUE)
    }
  ), private = list(path = NULL, owned = FALSE),
  lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
