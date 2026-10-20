SiteDataSource <- R6::R6Class("SiteDataSource",
  public = list(
    initialize = function(config) {
      private$config <- config
      private$tools <- ProtocolTools$new()
      private$marker <- config$path("site/collection-source.json")
      private$pilot_summary_path <- config$path("site/pilot-summary.json")
    },
    select = function() {
      state <- private$read_state()
      if (!isTRUE(state$official_locked)) {
        if (!identical(state$source, "pilot")) stop("Fonte do site inválida: esperava piloto antes da transição oficial.", call. = FALSE)
        if (!file.exists(private$pilot_summary_path)) {
          stop("Resumo do piloto ausente; o site não pode escolher dados por data nem usar uma fonte parcial.", call. = FALSE)
        }
        summary <- private$read_json(private$pilot_summary_path, "Resumo do piloto")
        private$validate_pilot(summary)
        return(list(source = "pilot", summary = summary, state = state))
      }
      if (!identical(state$source, "official") || !is.list(state$official)) {
        stop("Registro da fonte oficial inválido; geração interrompida sem retorno ao piloto.", call. = FALSE)
      }
      record <- state$official
      snapshot <- private$config$path(private$tools$scalar(record$snapshot_path))
      if (!file.exists(snapshot)) {
        stop("Fonte oficial já travada, mas o snapshot oficial está indisponível: ", snapshot,
          ". O site não retornará ao piloto.", call. = FALSE)
      }
      hash <- digest::digest(file = snapshot, algo = "sha256", serialize = FALSE)
      if (!identical(hash, private$tools$scalar(record$sha256))) {
        stop("Snapshot oficial alterado ou corrompido; geração interrompida sem retorno ao piloto.", call. = FALSE)
      }
      store <- AuditStore$new(snapshot, private$config, readonly = TRUE)
      on.exit(store$close(), add = TRUE)
      tryCatch(AnalysisGate$new(private$config, store)$verify_recorded_runs(record$run_ids), error = function(error) {
        stop("Snapshot oficial indisponível ou inválido; geração interrompida sem retorno ao piloto: ",
          conditionMessage(error), call. = FALSE)
      })
      list(source = "official", path = snapshot, record = record, state = state)
    },
    update_pilot = function(summary) {
      if (!file.exists(private$marker)) return(FALSE)
      state <- private$read_state()
      if (isTRUE(state$official_locked)) return(FALSE)
      private$validate_pilot(summary)
      private$write_json(private$pilot_summary_path, summary)
      TRUE
    },
    pilot_summary = function(store) {
      coverage <- private$coverage(store)
      runs <- store$query(paste("SELECT run_id,platform,status,cutoff,version,config_hash,started,finished",
        "FROM runs WHERE pilot=1 ORDER BY rowid"))
      if (!private$valid_pilot_runs(runs)) stop("Não há um piloto concluído das duas plataformas para resumir.", call. = FALSE)
      by_platform <- split(runs, runs$platform)
      run_ids <- lapply(c("github", "huggingface"), function(platform) {
        data <- by_platform[[platform]]
        if (is.null(data) || !nrow(data)) return("")
        data$run_id[[nrow(data)]]
      })
      names(run_ids) <- c("github", "huggingface")
      list(schema_version = 1L, source = "pilot", scope = "limited_pilot_not_scientific_population",
        protocol = list(version = as.character(runs$version[[1L]]), cutoff = as.character(runs$cutoff[[1L]]),
          config_hash = as.character(runs$config_hash[[1L]])),
        collected = list(started = min(runs$started), finished = max(runs$finished)),
        run_ids = run_ids, limits = private$config$settings$pilot, coverage = coverage,
        spaces_included = private$spaces_included(runs), kernels_included = private$kernels_included(runs))
    },
    lock_official = function(database_path, complete_run = FALSE) {
      if (!isTRUE(complete_run)) stop("Apenas --run pode travar a primeira fonte oficial.", call. = FALSE)
      if (!file.exists(database_path)) stop("Banco da coleta oficial ausente: ", database_path, call. = FALSE)
      store <- AuditStore$new(database_path, private$config, readonly = TRUE)
      on.exit(store$close(), add = TRUE)
      AnalysisGate$new(private$config, store)$verify()
      runs <- store$query(paste("SELECT run_id,platform,status,pilot,cutoff,version,config_hash,started,finished",
        "FROM runs WHERE pilot=0 AND platform IN ('github','huggingface') ORDER BY rowid"))
      latest <- lapply(c("github", "huggingface"), function(platform) {
        rows <- runs[runs$platform == platform, , drop = FALSE]
        if (!nrow(rows)) stop("Coleta oficial ausente: ", if (platform == "github") "GitHub" else "Hugging Face", call. = FALSE)
        rows[nrow(rows), , drop = FALSE]
      })
      names(latest) <- c("github", "huggingface")
      run_ids <- lapply(latest, function(rows) rows$run_id[[1L]])
      problems <- store$query("SELECT COUNT(*) n FROM problems WHERE resolved=0 AND run_id IN (?,?)",
        unname(unlist(run_ids)))$n[[1L]]
      if (problems > 0L) {
        previous <- private$read_state()
        return(list(locked = FALSE, source = previous$source,
          reason = "A coleta terminou com lacunas de cobertura não verificadas."))
      }
      integrity <- store$query("PRAGMA integrity_check")[[1L]]
      if (!identical(integrity, "ok")) stop("Banco oficial com falha de integridade; transição do site preservada.", call. = FALSE)
      coverage <- private$coverage(store)
      relative_directory <- file.path(private$config$settings$paths$archive, "site-source")
      directory <- private$config$path(relative_directory)
      dir.create(directory, recursive = TRUE, showWarnings = FALSE)
      identity <- private$tools$hash(paste(unlist(run_ids), collapse = "\n"))
      filename <- paste0(substr(identity, 1L, 24L), ".sqlite")
      relative_snapshot <- file.path(relative_directory, filename)
      snapshot <- private$config$path(relative_snapshot)
      if (file.exists(snapshot)) {
        existing_hash <- digest::digest(file = snapshot, algo = "sha256", serialize = FALSE)
        source_hash <- digest::digest(file = database_path, algo = "sha256", serialize = FALSE)
        if (!identical(existing_hash, source_hash)) {
          stop("Já existe um snapshot diferente para os mesmos identificadores; fonte anterior preservada.", call. = FALSE)
        }
      } else {
        temporary <- tempfile(".site-source-", directory, ".sqlite")
        if (!file.copy(database_path, temporary)) stop("Não foi possível preservar o snapshot oficial; fonte anterior mantida.", call. = FALSE)
        on.exit(unlink(temporary), add = TRUE)
        if (!file.rename(temporary, snapshot)) stop("Não foi possível finalizar o snapshot oficial; fonte anterior mantida.", call. = FALSE)
      }
      snapshot_hash <- digest::digest(file = snapshot, algo = "sha256", serialize = FALSE)
      info <- list(snapshot_path = relative_snapshot, sha256 = snapshot_hash,
        saved_at = private$tools$now(), config_hash = as.character(latest$github$config_hash[[1L]]),
        protocol_version = as.character(latest$github$version[[1L]]), cutoff = as.character(latest$github$cutoff[[1L]]),
        run_ids = run_ids, coverage = coverage)
      previous <- private$read_state()
      history <- previous$history
      if (!is.list(history)) history <- list()
      history[[length(history) + 1L]] <- info
      state <- list(schema_version = 1L, policy = "permanent_official_after_verified_full_collection",
        source = "official", official_locked = TRUE,
        locked_at = if (isTRUE(previous$official_locked)) previous$locked_at else info$saved_at,
        official = info, history = history)
      private$write_json(private$marker, state)
      invisible(list(locked = TRUE, state = state))
    }
  ),
  private = list(
    config = NULL, tools = NULL, marker = NULL, pilot_summary_path = NULL,
    read_json = function(path, label) tryCatch(private$tools$decode(paste(readLines(path, warn = FALSE), collapse = "\n")),
      error = function(error) stop(label, " inválido: ", conditionMessage(error), call. = FALSE)),
    read_state = function() {
      if (!file.exists(private$marker)) stop("Registro persistente da fonte do site ausente: ", private$marker, call. = FALSE)
      state <- private$read_json(private$marker, "Registro persistente da fonte")
      if (!private$valid_state_schema(state)) {
        stop("Registro persistente da fonte do site inválido.", call. = FALSE)
      }
      if (identical(state$source, "pilot") && private$has_official_history(state)) {
        stop("O registro já contém uma transição oficial; retorno ao piloto é proibido.", call. = FALSE)
      }
      if (isTRUE(state$official_locked) != identical(state$source, "official")) {
        stop("Registro persistente da transição oficial inconsistente.", call. = FALSE)
      }
      state
    },
    valid_state_schema = function(state) {
      is.list(state) && private$valid_state_version(state) &&
        private$valid_state_policy(state) && private$valid_state_source(state)
    },
    valid_state_version = function(state) identical(as.integer(state$schema_version), 1L),
    valid_state_policy = function(state) identical(state$policy, "permanent_official_after_verified_full_collection"),
    valid_state_source = function(state) {
      state$source %in% c("pilot", "official") && is.logical(state$official_locked) && length(state$official_locked) == 1L
    },
    validate_pilot = function(summary) {
      if (!private$valid_pilot_summary(summary)) {
        stop("Resumo do piloto incompleto ou incompatível; site não será gerado.", call. = FALSE)
      }
      invisible(TRUE)
    },
    valid_pilot_summary = function(summary) {
      is.list(summary) && private$valid_pilot_identity(summary) &&
        private$valid_pilot_provenance(summary) && private$valid_pilot_coverage(summary)
    },
    valid_pilot_identity = function(summary) {
      identical(as.integer(summary$schema_version), 1L) &&
        identical(summary$source, "pilot") &&
        identical(summary$scope, "limited_pilot_not_scientific_population")
    },
    valid_pilot_provenance = function(summary) {
      is.list(summary$collected) && private$valid_pilot_run_ids(summary) &&
        private$valid_pilot_protocol(summary) && private$valid_pilot_limits(summary)
    },
    valid_pilot_run_ids = function(summary) {
      is.list(summary$run_ids) && all(c("github", "huggingface") %in% names(summary$run_ids)) &&
        all(nzchar(unlist(summary$run_ids[c("github", "huggingface")], use.names = FALSE)))
    },
    valid_pilot_protocol = function(summary) {
      is.list(summary$protocol) && all(c("version", "cutoff", "config_hash") %in% names(summary$protocol))
    },
    valid_pilot_limits = function(summary) {
      is.list(summary$limits) && is.logical(summary$spaces_included) && length(summary$spaces_included) == 1L
    },
    valid_pilot_coverage = function(summary) {
      is.list(summary$coverage) &&
        all(c("catalogued", "eligible", "legal_discussions", "github", "huggingface") %in% names(summary$coverage)) &&
        is.list(summary$coverage$huggingface) &&
        all(c("models", "datasets", "spaces") %in% names(summary$coverage$huggingface))
    },
    spaces_included = function(runs) {
      versions <- tryCatch(base::package_version(runs$version), error = function(error) NULL)
      !is.null(versions) && length(versions) == nrow(runs) &&
        all(versions >= base::package_version("1.2.0"))
    },
    kernels_included = function(runs) {
      versions <- tryCatch(base::package_version(runs$version), error = function(error) NULL)
      !is.null(versions) && length(versions) == nrow(runs) &&
        all(versions >= base::package_version("1.3.0"))
    },
    valid_pilot_runs = function(runs) {
      nrow(runs) > 0L && private$pilot_runs_completed(runs) &&
        private$pilot_platforms_complete(runs) && private$pilot_protocol_consistent(runs)
    },
    pilot_runs_completed = function(runs) !any(runs$status != "completed"),
    pilot_platforms_complete = function(runs) setequal(unique(runs$platform), c("github", "huggingface")),
    pilot_protocol_consistent = function(runs) {
      length(unique(runs$version)) == 1L && length(unique(runs$cutoff)) == 1L &&
        length(unique(runs$config_hash)) == 1L
    },
    has_official_history = function(state) {
      if (!is.list(state$history) || !length(state$history)) return(FALSE)
      any(vapply(state$history, function(item) is.list(item) &&
        is.list(item$run_ids) && !is.null(item$snapshot_path) && !is.null(item$sha256), logical(1)))
    },
    write_json = function(path, value) {
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      temporary <- tempfile(".site-source-", dirname(path))
      on.exit(unlink(temporary), add = TRUE)
      writeLines(private$tools$json(value), temporary, useBytes = TRUE)
      if (!file.rename(temporary, path)) stop("Falha ao atualizar o registro de fonte: ", path, call. = FALSE)
      invisible(path)
    },
    coverage = function(store) {
      counts <- store$counts()
      total <- function(table, platform, type = NULL) {
        rows <- table[table$platform == platform, , drop = FALSE]
        if (!is.null(type)) rows <- rows[rows$repo_type == type, , drop = FALSE]
        as.integer(sum(rows$n))
      }
      hf_type <- function(type) list(catalogued = total(counts$catalogued, "huggingface", type),
        eligible = total(counts$eligible, "huggingface", type),
        repositories_with_evidence = total(counts$repositories_with_evidence, "huggingface", type),
        legal_discussions = total(counts$legal_discussions, "huggingface", type))
      list(catalogued = as.integer(sum(counts$catalogued$n)),
        eligible = as.integer(sum(counts$eligible$n)),
        repositories_with_evidence = as.integer(sum(counts$repositories_with_evidence$n)),
        legal_discussions = as.integer(sum(counts$legal_discussions$n)),
        github = list(catalogued = total(counts$catalogued, "github"),
          eligible = total(counts$eligible, "github"),
          repositories_with_evidence = total(counts$repositories_with_evidence, "github"),
          legal_discussions = total(counts$legal_discussions, "github")),
        huggingface = list(catalogued = total(counts$catalogued, "huggingface"),
          eligible = total(counts$eligible, "huggingface"),
          repositories_with_evidence = total(counts$repositories_with_evidence, "huggingface"),
          legal_discussions = total(counts$legal_discussions, "huggingface"),
          models = hf_type("model"), datasets = hf_type("dataset"), spaces = hf_type("space"),
          kernels = hf_type("kernel")))
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
