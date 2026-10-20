ProjectApplication <- R6::R6Class("ProjectApplication",
  public = list(
    initialize = function(root, environment, http_factory = NULL, progress = NULL, started = NULL) {
      private$root <- root
      private$environment <- environment
      private$progress <- if (is.null(progress)) ConsoleProgress$new() else progress
      private$started <- started
      private$http_factory <- if (is.null(http_factory)) function(platform, config, store) {
        HttpClient$new(platform, config, store)
      } else http_factory
    },
    run = function(args) {
      options <- private$options(args)
      if (options$mode == "help") return(private$help())
      private$config <- ProjectConfig$new(private$root)
      private$begin(options$mode)
      completed <- FALSE
      on.exit(if (!completed) private$progress$finish("Execução interrompida"), add = TRUE)
      result <- private$execute(options)
      completed <- TRUE
      label <- if (private$site_failed) "Dados concluídos; geração do site falhou" else
        if (options$mode == "pilot") "Piloto concluído; resultados limitados ao piloto" else "Execução concluída"
      private$progress$finish(label)
      invisible(result)
    }
  ),
  private = list(
    root = NULL, environment = NULL, config = NULL, http_factory = NULL,
    progress = NULL, started = NULL, site_failed = FALSE,
    begin = function(mode) {
      labels <- c(run = "Execução completa | GitHub + Hugging Face", pilot = "Piloto limitado | GitHub + Hugging Face",
        github = "Coleta GitHub", huggingface = "Coleta Hugging Face", analyze = "Preparação dos dados e amostra")
      steps <- c(run = 4L, pilot = 2L, github = 2L, huggingface = 2L, analyze = 2L)
      private$site_failed <- FALSE
      private$progress$begin(paste0(labels[[mode]], " | corte: ", private$config$settings$protocol$cutoff),
        steps[[mode]], private$started)
      private$progress$activity("Verificando configuração e referências")
    },
    execute = function(options) {
      lock <- RunLock$new(private$root)
      on.exit(lock$release(), add = TRUE)
      if (options$mode == "analyze") return(private$analyze(options))
      private$collect(options)
    },
    options = function(args) {
      modes <- c("--pilot" = "pilot", "--run" = "run", "--github" = "github",
        "--huggingface" = "huggingface", "--analyze" = "analyze")
      if (!length(args)) return(list(mode = "help"))
      allowed <- c(names(modes), "--help", "-h")
      unknown <- args[!args %in% allowed]
      if (length(unknown)) stop("Opção inválida: ", unknown[[1L]])
      if (length(args) > 1L) stop("Selecione apenas uma modalidade por execução")
      if (args[[1L]] %in% c("--help", "-h")) return(list(mode = "help"))
      list(mode = unname(modes[[args[[1L]]]]))
    },
    help = function() {
      cat(paste(c("Projeto de discussões sobre legislação de privacidade em IA/ML",
        "Modalidades: --pilot | --run | --github | --huggingface | --analyze",
        "Ajuda: --help ou -h",
        "Sem argumentos: ajuda. Nunca inicia uma coleta por acidente.",
        "O piloto não gera o site; coletas e análise geram o site ao concluir.",
        "Arquivos preenchidos de revisão são lidos de caminhos fixos em inputs/final/.",
        "O piloto substitui seus dados anteriores; coletas completas preservam histórico.",
        "Publicação é manual; nenhuma execução faz commit, push ou deploy."), collapse = "\n"), "\n")
    },
    analyze = function(options) {
      path <- private$config$path(private$config$settings$paths$database)
      if (!file.exists(path)) stop("Banco científico ausente. Execute as duas coletas primeiro.")
      store <- AuditStore$new(path, private$config)
      on.exit(store$close(), add = TRUE)
      private$progress$stage("Preparação dos CSVs e amostra")
      private$progress$activity("Verificando coletas e preparando a amostra")
      result <- AnalysisExporter$new(private$config, store)$run(private$review_file("coding_reviewed"),
        private$review_file("consensus_reviewed"))
      private$progress$event(paste("CSVs e amostra preparados em:", result$path))
      private$site()
      invisible(result)
    },
    collect = function(options) {
      pilot <- options$mode == "pilot"
      complete <- options$mode == "run"
      if (complete) private$config$require_references()
      platforms <- if (pilot || complete) c("github", "huggingface") else options$mode
      manager <- DatabaseManager$new(private$config, pilot, fresh = pilot || complete)
      store <- AuditStore$new(manager$staging, private$config, recover = !pilot)
      succeeded <- FALSE
      on.exit({
        store$close()
        if (!succeeded) manager$preserve_failure()
      }, add = TRUE)
      for (platform in platforms) private$platform(platform, store, pilot)
      if (complete) {
        private$progress$stage("Preparação dos CSVs e amostra")
        private$progress$activity("Verificando coletas e preparando a amostra")
        result <- AnalysisExporter$new(private$config, store)$run(private$review_file("coding_reviewed"),
          private$review_file("consensus_reviewed"))
        private$progress$event(paste("CSVs e amostra preparados em:", result$path))
      }
      if (pilot) private$pilot_report(store)
      store$close()
      manager$promote()
      succeeded <- TRUE
      private$progress$event(paste(if (pilot) "Banco do piloto:" else "Banco científico:", manager$target))
      if (complete) private$record_site_source(manager$target)
      if (!pilot) private$site()
      invisible(manager$target)
    },
    record_site_source = function(database_path) {
      transition <- SiteDataSource$new(private$config)$lock_official(database_path, complete_run = TRUE)
      if (isTRUE(transition$locked)) return(invisible(transition))
      retained <- if (identical(transition$source, "official"))
        "O último snapshot oficial válido será mantido." else "O resumo preliminar do piloto será mantido."
      private$progress$event(paste("Fonte do site mantida:", transition$reason, retained))
      invisible(transition)
    },
    review_file = function(name) {
      paths <- c(coding_reviewed = "inputs/final/coding-reviewed.csv",
        consensus_reviewed = "inputs/final/consensus-reviewed.csv")
      path <- private$config$path(unname(paths[[name]]))
      if (file.exists(path)) path else NULL
    },
    pilot_report = function(store) {
      path <- file.path(dirname(private$config$path(private$config$settings$paths$pilot_database)), "summary.json")
      source <- SiteDataSource$new(private$config)
      summary <- list(scope = "limited_pilot_not_scientific_population",
        limits = private$config$settings$pilot, counts = store$counts(),
        runs = store$query("SELECT * FROM runs ORDER BY rowid"))
      writeLines(ProtocolTools$new()$json(summary), path)
      if (source$update_pilot(source$pilot_summary(store))) private$progress$event("Resumo preliminar do site atualizado com o piloto atual.")
      private$progress$event(paste("Resumo do piloto:", path))
    },
    platform = function(platform, store, pilot) {
      store$clear_platform(platform)
      label <- if (platform == "github") "GitHub" else "Hugging Face"
      private$progress$stage(paste("Coleta", label), function() private$collection_counts(store, platform))
      journal <- CollectionJournal$new(private$config)
      http <- private$http_factory(platform, private$config, store)
      http$progress <- private$progress
      collector <- if (platform == "github") GitHubCollector$new(private$config, store, http, pilot) else
        HuggingFaceCollector$new(private$config, store, http, pilot)
      if (!pilot) journal$record(platform, "pending", "running", private$config)
      status <- tryCatch(collector$run(), error = function(error) {
        if (!is.null(store$run_id)) store$finish("failed")
        if (!pilot) journal$record(platform, ProtocolTools$new()$scalar(store$run_id), "failed", private$config)
        stop(error)
      })
      if (!pilot) journal$record(platform, store$run_id, status, private$config)
      problems <- private$problem_counts(store, platform, store$run_id)
      if (status != "completed") {
        stop("Coleta ", platform, " com problemas pendentes; banco oficial preservado.")
      }
      unverified <- problems$pending + problems$gaps
      label_status <- if (problems$pending > 0L) paste0("concluída | ", unverified,
        " diagnósticos registrados; itens sem verificação desconsiderados na análise") else
        if (problems$gaps > 0L) paste0("concluída | ", private$gap_summary(problems$gaps)) else "concluída"
      private$progress$report(paste("Coleta", label, label_status))
      invisible(status)
    },
    collection_counts = function(store, platform) {
      counts <- store$counts()
      total <- function(data) sum(data$n[data$platform == platform])
      run_id <- ProtocolTools$new()$scalar(store$run_id)
      problems <- private$problem_counts(store, platform, run_id)
      requests <- store$query("SELECT COUNT(*) n FROM responses WHERE run_id=? AND attempt>0", list(run_id))$n
      reused <- store$query("SELECT COUNT(*) n FROM responses WHERE run_id=? AND attempt=0", list(run_id))$n
      paste0("Acumulado da plataforma: repositórios avaliados: ", total(counts$catalogued),
        " | elegíveis: ", total(counts$eligible), " | repositórios com menções a leis: ",
        total(counts$repositories_with_evidence), " | requisições: ", requests,
        if (reused > 0L) paste0(" | respostas reaproveitadas: ", reused) else "",
        " | diagnósticos registrados: ", problems$pending + problems$gaps)
    },
    problem_counts = function(store, platform, run_id) {
      codes <- store$query("SELECT code FROM problems WHERE run_id=? AND resolved=0", list(run_id))$code
      tolerated <- store$search_gap_codes(platform)
      list(pending = sum(!codes %in% tolerated), gaps = sum(codes %in% tolerated))
    },
    gap_summary = function(count) {
      paste0(count, " ", if (count == 1L) "intervalo sem resultado verificável" else
        "intervalos sem resultados verificáveis", "; desconsiderados na análise")
    },
    site = function() {
      private$progress$stage("Geração do site")
      private$progress$activity("Renderizando página")
      tryCatch({
        path <- SiteWriter$new(private$config)$render()
        private$progress$event(paste("Site gerado:", path))
      }, error = function(error) {
        private$site_failed <- TRUE
        path <- private$config$path("outputs/metadata/site-failure.txt")
        dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
        writeLines(c(ProtocolTools$new()$now(), conditionMessage(error)), path)
        private$progress$event(paste("Dados concluídos; geração do site falhou. Diagnóstico:", path))
      })
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
