SiteWriter <- R6::R6Class("SiteWriter",
  public = list(
    initialize = function(config) {
      private$config <- config
      private$tools <- ProtocolTools$new()
    },
    prepare = function() {
      state <- private$state()
      template_path <- private$config$path("site/index-template.md")
      if (!file.exists(template_path)) stop("Template do site ausente: ", template_path, call. = FALSE)
      template <- readLines(template_path, warn = FALSE)
      text <- paste(template, collapse = "\n")
      values <- list(STATUS = state$message, CATALOGUED = state$catalogued,
        ELIGIBLE = state$eligible, DISCUSSIONS = state$discussions,
        CUTOFF = private$config$settings$protocol$cutoff,
        RQ3_STATUS = state$rq3_message, RQ3_RESULTS = state$rq3_table,
        REFERENCES = private$references())
      for (name in names(values)) text <- gsub(paste0("{{", name, "}}"), values[[name]], text, fixed = TRUE)
      if (grepl("\\{\\{[A-Z_]+\\}\\}", text)) stop("Marcador de template sem valor")
      writeLines(text, private$config$path("index.qmd"), useBytes = TRUE)
      writeLines(private$tools$json(state), private$config$path("site/summary.json"))
      invisible(state)
    },
    render = function() {
      if (!nzchar(Sys.which("quarto"))) stop("Quarto não encontrado")
      self$prepare()
      output <- suppressWarnings(system2("quarto", c("render", shQuote(private$config$root)), stdout = TRUE, stderr = TRUE))
      status <- attr(output, "status")
      if (!is.null(status) && status != 0L) stop(paste(c(paste("Quarto terminou com erro", status),
        utils::tail(output, 20L)), collapse = "\n"), call. = FALSE)
      invisible(private$config$path("_site/index.html"))
    }
  ),
  private = list(
    config = NULL, tools = NULL,
    state = function() {
      result <- list(status = "no_collection", message = "Coleta científica ainda não executada.",
        catalogued = "—", eligible = "—", discussions = "—", generated = private$tools$now(),
        rq3_status = "human_evaluation_pending", rq3_message = "RQ3 pendente: ainda não há anotações reais de etapas e consenso importados.",
        rq3_table = "As etapas não são atribuídas automaticamente. Não há resultados humanos para apresentar.")
      path <- private$config$path(private$config$settings$paths$database)
      if (!file.exists(path)) return(result)
      store <- AuditStore$new(path, private$config)
      on.exit(store$close(), add = TRUE)
      valid <- tryCatch({ AnalysisGate$new(private$config, store)$verify(); TRUE }, error = function(e) FALSE)
      if (!valid) {
        result$status <- "collection_incomplete"
        result$message <- "As duas últimas coletas ainda não satisfazem o protocolo. Resultados científicos pendentes."
        return(result)
      }
      manifest <- private$config$path(file.path(private$config$settings$paths$analysis, "manifest.json"))
      result$status <- "analysis_pending"
      result$message <- "Coletas concluídas. Execute a análise para preparar a amostra humana."
      if (!file.exists(manifest)) return(result)
      data <- private$tools$decode(paste(readLines(manifest, warn = FALSE), collapse = "\n"))
      runs <- store$query("SELECT run_id FROM runs WHERE pilot=0 ORDER BY rowid")$run_id
      manifest_runs <- vapply(data$runs, function(run) run$run_id, "")
      if (!identical(data$config_hash, private$config$fingerprint) || !identical(runs, manifest_runs)) return(result)
      result$status <- "ready_for_human_review"
      result$message <- "Coletas e amostragem concluídas. Avaliação humana pendente; categorias não atribuídas automaticamente."
      counts <- store$counts()
      result$catalogued <- as.character(sum(counts$catalogued$n))
      result$eligible <- as.character(sum(counts$eligible$n))
      result$discussions <- as.character(sum(counts$legal_discussions$n))
      private$stage_results(result, data)
    },
    stage_results = function(result, manifest) {
      rq3 <- manifest$rq3
      if (!private$stage_current(rq3)) return(result)
      result$rq3_status <- rq3$status
      if (rq3$status == "human_evaluation_pending") return(result)
      result$rq3_message <- if (rq3$status == "human_evaluation_complete")
        "RQ3: duas avaliações independentes e consenso importados para toda a amostra. Contrastes inferenciais continuam sujeitos à adequação do desenho."
        else "RQ3 parcialmente anotada: há avaliações ou consensos pendentes. As descrições disponíveis são provisórias."
      if (rq3$coverage$consensus_complete > 0L) result$rq3_table <- private$stage_table(utils::read.csv(private$config$path("outputs/tables/rq3/stages.csv")))
      result
    },
    stage_current = function(rq3) {
      if (!identical(rq3$codebook_version, private$config$stages$version) ||
          !identical(rq3$codebook_hash, private$config$stage_fingerprint)) return(FALSE)
      expected <- file.path("outputs/tables/rq3", c("stages.csv", "agreement.csv", "stage-categories.csv", "contrasts.csv", "examples.csv"))
      if (!setequal(names(rq3$sha256), expected)) return(FALSE)
      for (file in expected) {
        path <- private$config$path(file)
        if (!file.exists(path) || digest::digest(file = path, algo = "sha256", serialize = FALSE) != rq3$sha256[[file]]) return(FALSE)
      }
      TRUE
    },
    stage_table = function(rows) {
      lines <- c("| Etapa | GitHub n/N (%) | Hugging Face n/N (%) |", "|---|---:|---:|")
      for (stage in private$config$stages$stages) {
        gh <- rows[rows$stage_id == stage$id & rows$platform == "github", ]
        hf <- rows[rows$stage_id == stage$id & rows$platform == "huggingface", ]
        lines <- c(lines, paste0("| ", stage$label, " | ", private$rate(gh), " | ", private$rate(hf), " |"))
      }
      lines <- c(lines, "", "| Hub | Indeterminadas | Etapas pendentes em relevantes | Relevância pendente |",
        "|---|---:|---:|---:|")
      for (platform in c("github", "huggingface")) {
        row <- rows[rows$platform == platform, ][1L, ]
        label <- if (platform == "github") "GitHub" else "Hugging Face"
        lines <- c(lines, sprintf("| %s | %d | %d | %d |", label, row$n_indeterminate, row$n_stage_pending, row$n_relevance_pending))
      }
      paste(lines, collapse = "\n")
    },
    rate = function(row) {
      value <- if (is.na(row$proportion)) "indefinida" else sprintf("%.1f%%", 100 * row$proportion)
      sprintf("%d/%d (%s)", row$n_stage, row$denominator, value)
    },
    references = function() {
      path <- private$config$path("inputs/reference/literature_methods.md")
      paste(readLines(path, warn = FALSE), collapse = "\n")
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
