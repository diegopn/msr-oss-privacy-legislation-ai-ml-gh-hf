PlatformStores <- R6::R6Class("PlatformStores",
  public = list(
    initialize = function(stores) {
      if (inherits(stores, "PlatformStores")) stores <- stores$as_list()
      if (inherits(stores, "AuditStore")) stores <- list(github = stores, huggingface = stores)
      platforms <- c("github", "huggingface")
      if (!is.list(stores) || !all(platforms %in% names(stores)) ||
          !all(vapply(stores[platforms], inherits, logical(1), what = "AuditStore"))) {
        stop("São necessários bancos AuditStore para GitHub e Hugging Face.", call. = FALSE)
      }
      private$stores <- stores[platforms]
    },
    for_platform = function(platform) {
      if (!platform %in% names(private$stores)) stop("Plataforma inválida.", call. = FALSE)
      private$stores[[platform]]
    },
    as_list = function() private$stores,
    counts = function() {
      values <- lapply(private$unique_connections(), function(store) store$counts())
      names <- names(values[[1L]])
      setNames(lapply(names, function(name) {
        rows <- lapply(values, `[[`, name)
        rows <- Filter(function(value) nrow(value) > 0L, rows)
        if (!length(rows)) return(values[[1L]][[name]][FALSE, , drop = FALSE])
        do.call(rbind, rows)
      }), names)
    },
    runs = function(pilot = FALSE) {
      rows <- lapply(private$unique_connections(), function(store) {
        store$query("SELECT * FROM runs WHERE pilot=? ORDER BY started", list(as.integer(pilot)))
      })
      rows <- Filter(function(value) nrow(value) > 0L, rows)
      if (!length(rows)) return(data.frame())
      result <- do.call(rbind, rows)
      result[order(result$started), , drop = FALSE]
    },
    verify_integrity = function() {
      results <- vapply(private$unique_connections(), function(store) {
        store$query("PRAGMA integrity_check")[[1L]]
      }, "")
      if (any(results != "ok")) stop("Banco com falha de integridade.", call. = FALSE)
      invisible(TRUE)
    },
    close = function() {
      for (store in private$unique_connections()) store$close()
      invisible(TRUE)
    }
  ),
  private = list(
    stores = NULL,
    unique_connections = function() {
      unique <- list()
      for (platform in names(private$stores)) {
        store <- private$stores[[platform]]
        if (!any(vapply(unique, function(existing) identical(existing, store), logical(1)))) {
          unique[[length(unique) + 1L]] <- store
        }
      }
      unique
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
