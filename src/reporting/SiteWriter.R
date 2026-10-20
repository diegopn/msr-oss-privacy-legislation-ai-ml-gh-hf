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
        ELIGIBLE = state$eligible, REPOSITORIES_WITH_EVIDENCE = state$repositories_with_evidence,
        PROVENANCE = state$provenance,
        CUTOFF = private$config$settings$protocol$cutoff,
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
      selection <- SiteDataSource$new(private$config)$select()
      if (selection$source == "pilot") return(private$pilot_state(selection$summary))
      result <- list(source = "official", status = "analysis_pending",
        message = "Coleta oficial integral concluída.",
        catalogued = "—", eligible = "—", repositories_with_evidence = "—", generated = private$tools$now(),
        source_run_ids = selection$record$run_ids, coverage = private$public_coverage(selection$record$coverage),
        provenance = private$provenance(selection$record, "official"))
      store <- AuditStore$new(selection$path, private$config, readonly = TRUE)
      on.exit(store$close(), add = TRUE)
      AnalysisGate$new(private$config, store)$verify_recorded_runs(selection$record$run_ids)
      manifest <- private$config$path(file.path(private$config$settings$paths$analysis, "manifest.json"))
      counts <- store$counts()
      result$catalogued <- as.character(sum(counts$catalogued$n))
      result$eligible <- as.character(sum(counts$eligible$n))
      result$repositories_with_evidence <- as.character(sum(counts$repositories_with_evidence$n))
      if (!file.exists(manifest)) return(result)
      data <- private$tools$decode(paste(readLines(manifest, warn = FALSE), collapse = "\n"))
      runs <- unname(unlist(selection$record$run_ids, use.names = FALSE))
      manifest_runs <- vapply(data$runs, function(run) run$run_id, "")
      if (!identical(data$config_hash, private$config$fingerprint) || !identical(runs, manifest_runs)) return(result)
      result$status <- "analysis_ready"
      result$message <- "Coleta oficial integral e amostragem concluídas."
      result
    },
    pilot_state = function(summary) {
      coverage <- summary$coverage
      result <- list(source = "pilot", status = "preliminary_pilot",
        message = "Prévia preliminar baseada apenas nos dados limitados do piloto; não são resultados científicos.",
        catalogued = private$number(coverage$catalogued), eligible = private$number(coverage$eligible),
        repositories_with_evidence = private$display_count(private$repository_evidence_count(coverage)),
        generated = private$tools$now(),
        collected = summary$collected, source_run_ids = summary$run_ids,
        coverage = private$public_coverage(coverage), limits = summary$limits,
        spaces_included = isTRUE(summary$spaces_included),
        provenance = private$provenance(summary, "pilot"))
      result
    },
    number = function(value) {
      if (is.null(value) || !length(value) || is.na(value[[1L]])) return("0")
      format(as.integer(value[[1L]]), big.mark = ",", scientific = FALSE, trim = TRUE)
    },
    display_count = function(value) {
      if (is.character(value)) return(value)
      private$number(value)
    },
    repository_evidence_count = function(coverage) {
      if (!is.null(coverage$repositories_with_evidence)) return(coverage$repositories_with_evidence)
      if (identical(as.integer(coverage$legal_discussions), 0L)) return(0L)
      "—"
    },
    public_coverage = function(coverage) {
      platform <- function(value) list(catalogued = value$catalogued, eligible = value$eligible,
        repositories_with_evidence = private$repository_evidence_count(value))
      list(catalogued = coverage$catalogued, eligible = coverage$eligible,
        repositories_with_evidence = private$repository_evidence_count(coverage),
        github = platform(coverage$github), huggingface = platform(coverage$huggingface))
    },
    provenance = function(data, source) {
      if (source == "pilot") {
        coverage <- data$coverage
        hf <- coverage$huggingface
        spaces_count <- if (is.list(hf$spaces)) hf$spaces$catalogued else 0L
        kernels_count <- if (is.list(hf$kernels)) hf$kernels$catalogued else 0L
        values <- list(started = data$collected$started, finished = data$collected$finished,
          github_run = data$run_ids$github, hf_run = data$run_ids$huggingface,
          protocol_version = data$protocol$version, cutoff = data$protocol$cutoff,
          github_catalogued = coverage$github$catalogued, github_eligible = coverage$github$eligible,
          github_evidence_repositories = private$display_count(private$repository_evidence_count(coverage$github)),
          hf_catalogued = hf$catalogued, hf_eligible = hf$eligible,
          hf_evidence_repositories = private$display_count(private$repository_evidence_count(hf)),
          spaces_count = spaces_count,
          spaces_scope = if (isTRUE(data$spaces_included)) "spaces_included" else "spaces_not_collected",
          kernels_count = kernels_count,
          kernels_scope = if (isTRUE(data$kernels_included)) "kernels_included" else "kernels_not_collected",
          model_limit = data$limits$hf_discovered_per_type, hf_eligible_limit = data$limits$hf_eligible_per_type,
          discussion_limit = data$limits$hf_discussions_per_repo,
          github_results_limit = data$limits$github_results_per_term)
        key <- "pilot"
        fallback <- sprintf(paste0("<strong>Dados preliminares e limitados do piloto.</strong> Execuções %s (GitHub) e %s (Hugging Face), entre %s e %s UTC. Protocolo %s; corte %s UTC. ",
          "Cobertura de repositórios únicos: GitHub, %s catalogados, %s elegíveis e %s com menções a leis; Hugging Face, %s catalogados, %s elegíveis e %s com menções a leis. ",
          "Spaces: %s; Kernels: %s. Limites aplicados: até %s repositórios descobertos e %s elegíveis por tipo no HF, %s Discussions por repositório e até %s resultados de busca por termo no GitHub. ",
          "Estes números não representam a população."),
          values$github_run, values$hf_run, values$started, values$finished, values$protocol_version, values$cutoff, values$github_catalogued,
          values$github_eligible, values$github_evidence_repositories, values$hf_catalogued, values$hf_eligible,
          values$hf_evidence_repositories, if (isTRUE(data$spaces_included)) sprintf("busca executada (%s repositórios encontrados)", values$spaces_count) else "não incluídos neste piloto",
          if (isTRUE(data$kernels_included)) sprintf("busca executada (%s repositórios encontrados)", values$kernels_count) else "não incluídos neste piloto",
          values$model_limit, values$hf_eligible_limit, values$discussion_limit, values$github_results_limit)
      } else {
        coverage <- data$coverage
        hf <- coverage$huggingface
        values <- list(saved = data$saved_at, github_run = data$run_ids$github, hf_run = data$run_ids$huggingface,
          github_catalogued = coverage$github$catalogued, github_eligible = coverage$github$eligible,
          github_evidence_repositories = private$display_count(private$repository_evidence_count(coverage$github)),
          hf_catalogued = hf$catalogued, hf_eligible = hf$eligible,
          hf_evidence_repositories = private$display_count(private$repository_evidence_count(hf)))
        key <- "official"
        fallback <- sprintf(paste0("<strong>Coleta oficial integral validada em %s UTC.</strong> Execuções %s (GitHub) e %s (Hugging Face). ",
          "Cobertura verificada de repositórios únicos: GitHub, %s catalogados, %s elegíveis e %s com menções a leis; ",
          "Hugging Face, %s catalogados, %s elegíveis e %s com menções a leis."),
          values$saved, values$github_run, values$hf_run, values$github_catalogued, values$github_eligible,
          values$github_evidence_repositories, values$hf_catalogued, values$hf_eligible, values$hf_evidence_repositories)
      }
      attributes <- paste0(" data-value-", names(values), "=\"", vapply(values, private$html, ""), "\"")
      paste0("<p class=\"source-provenance\" data-i18n=\"", key, "\"", paste(attributes, collapse = ""), ">",
        fallback, "</p>")
    },
    html = function(value) {
      value <- as.character(value)
      value <- gsub("&", "&amp;", value, fixed = TRUE)
      value <- gsub("\"", "&quot;", value, fixed = TRUE)
      value <- gsub("<", "&lt;", value, fixed = TRUE)
      value <- gsub(">", "&gt;", value, fixed = TRUE)
      value
    },
    references = function() {
      path <- private$config$path("inputs/reference/literature_methods.md")
      paste(readLines(path, warn = FALSE), collapse = "\n")
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
