AnalysisGate <- R6::R6Class("AnalysisGate",
  public = list(
    initialize = function(config, store) {
      private$config <- config
      private$stores <- PlatformStores$new(store)
    },
    verify = function() {
      private$config$require_references()
      journal <- CollectionJournal$new(private$config)$read()
      for (platform in c("github", "huggingface")) private$platform(platform, journal[[platform]])
      private$stores$verify_integrity()
      invisible(TRUE)
    },
    verify_recorded_runs = function(run_ids) {
      private$config$require_references()
      if (!is.list(run_ids) || !all(c("github", "huggingface") %in% names(run_ids))) {
        stop("Registro da fonte oficial sem identificadores das duas plataformas.", call. = FALSE)
      }
      for (platform in c("github", "huggingface")) {
        private$verify_recorded_platform(platform, as.character(run_ids[[platform]]))
      }
      private$stores$verify_integrity()
      invisible(TRUE)
    },
    verify_recovery = function(platform, run_id) {
      store <- private$stores$for_platform(platform)
      unresolved <- store$query("SELECT COUNT(*) n FROM problems WHERE run_id=? AND resolved=0", list(run_id))$n[[1L]]
      private$check_recovery(store, run_id, unresolved)
      invisible(TRUE)
    }
  ),
  private = list(
    config = NULL, stores = NULL,
    platform = function(platform, journal) {
      store <- private$stores$for_platform(platform)
      runs <- store$query("SELECT * FROM runs WHERE platform=? AND pilot=0 ORDER BY rowid DESC LIMIT 1",
                                  list(platform))
      if (nrow(runs) != 1L) stop("Coleta científica ausente: ", platform, call. = FALSE)
      private$verify_protocol(runs, platform)
      if (is.null(journal) || journal$status != "completed" || journal$run_id != runs$run_id) {
        stop("A última tentativa de coleta não foi concluída: ", platform, call. = FALSE)
      }
      if (platform == "github") {
        unresolved <- store$query("SELECT COUNT(*) n FROM problems WHERE run_id=? AND resolved=0",
          list(runs$run_id))$n[[1L]]
        if (unresolved > 0L || nrow(store$recovery_summary(runs$run_id)) > 0L) {
          private$check_recovery(store, runs$run_id, unresolved)
        }
      }
      private$verify_responses(store, runs$run_id)
    },
    verify_protocol = function(runs, platform) {
      expected <- list(status = "completed", cutoff = private$config$settings$protocol$cutoff,
        version = private$config$settings$protocol$version, config_hash = private$config$fingerprint)
      actual <- as.list(runs[1L, names(expected), drop = FALSE])
      if (!identical(actual, expected)) stop("Coleta incompleta ou incompatível: ", platform)
    },
    verify_responses = function(store, run_id) {
      responses <- store$query("SELECT DISTINCT path,sha256 FROM responses WHERE run_id=?", list(run_id))
      for (index in seq_len(nrow(responses))) {
        path <- private$config$path(responses$path[[index]])
        if (!file.exists(path)) stop("Evidência bruta ausente: ", path)
        hash <- digest::digest(file = path, algo = "sha256", serialize = FALSE)
        if (hash != responses$sha256[[index]]) stop("Evidência bruta alterada: ", path)
      }
    },
    verify_recorded_platform = function(platform, run_id) {
      store <- private$stores$for_platform(platform)
      runs <- store$query("SELECT * FROM runs WHERE run_id=? AND platform=? AND pilot=0", list(run_id, platform))
      if (nrow(runs) != 1L) stop("Snapshot oficial sem execução integral registrada: ", platform, call. = FALSE)
      private$verify_protocol(runs, platform)
      private$verify_responses(store, run_id)
      unresolved <- store$query("SELECT COUNT(*) n FROM problems WHERE run_id=? AND resolved=0", list(run_id))$n[[1L]]
      summary_exists <- platform == "github" && nrow(store$recovery_summary(run_id)) > 0L
      if (platform == "github" && (unresolved > 0L || summary_exists)) {
        private$check_recovery(store, run_id, unresolved)
      }
    },
    check_recovery = function(store, run_id, unresolved) {
      summary <- store$recovery_summary(run_id)
      if (nrow(summary) == 0L) return(invisible(TRUE))
      if (nrow(summary) != 1L || !private$recovery_metrics_valid(store, run_id, summary, unresolved)) {
        stop("Resumo da recuperação não corresponde às pendências registradas.", call. = FALSE)
      }
      invisible(TRUE)
    },
    recovery_metrics_valid = function(store, run_id, summary, unresolved) {
      pending <- store$recovery_item_count(run_id)
      final <- as.integer(summary$final_pending[[1L]])
      diagnostics <- as.integer(summary$final_diagnostics[[1L]])
      all(c(is.finite(final), final >= 0L, final == pending, is.finite(diagnostics),
        diagnostics >= 0L, diagnostics == unresolved))
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
