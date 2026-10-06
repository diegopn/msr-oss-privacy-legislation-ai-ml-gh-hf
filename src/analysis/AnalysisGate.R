AnalysisGate <- R6::R6Class("AnalysisGate",
  public = list(
    initialize = function(config, store) {
      private$config <- config
      private$store <- store
    },
    verify = function() {
      private$config$require_references()
      journal <- CollectionJournal$new(private$config)$read()
      for (platform in c("github", "huggingface")) private$platform(platform, journal[[platform]])
      integrity <- private$store$query("PRAGMA integrity_check")[[1L]]
      if (!identical(integrity, "ok")) stop("Banco com falha de integridade")
      invisible(TRUE)
    }
  ),
  private = list(
    config = NULL, store = NULL,
    platform = function(platform, journal) {
      runs <- private$store$query("SELECT * FROM runs WHERE platform=? AND pilot=0 ORDER BY rowid DESC LIMIT 1",
                                  list(platform))
      if (nrow(runs) != 1L) stop("Coleta científica ausente: ", platform, call. = FALSE)
      private$verify_protocol(runs, platform)
      if (is.null(journal) || journal$status != "completed" || journal$run_id != runs$run_id) {
        stop("A última tentativa de coleta não foi concluída: ", platform, call. = FALSE)
      }
      private$verify_responses(runs$run_id)
    },
    verify_protocol = function(runs, platform) {
      expected <- list(status = "completed", cutoff = private$config$settings$protocol$cutoff,
        version = private$config$settings$protocol$version, config_hash = private$config$fingerprint)
      actual <- as.list(runs[1L, names(expected), drop = FALSE])
      if (!identical(actual, expected)) stop("Coleta incompleta ou incompatível: ", platform)
    },
    verify_responses = function(run_id) {
      responses <- private$store$query("SELECT DISTINCT path,sha256 FROM responses WHERE run_id=?", list(run_id))
      for (index in seq_len(nrow(responses))) {
        path <- private$config$path(responses$path[[index]])
        if (!file.exists(path)) stop("Evidência bruta ausente: ", path)
        hash <- digest::digest(file = path, algo = "sha256", serialize = FALSE)
        if (hash != responses$sha256[[index]]) stop("Evidência bruta alterada: ", path)
      }
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
