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
      private$config <- ProjectConfig$new(private$root, options$config)
      if (options$mode == "check") return(private$check())
      if (options$mode == "test") return(private$test())
      if (options$mode == "prepare-site") return(SiteWriter$new(private$config)$prepare())
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
        github = "Coleta GitHub", huggingface = "Coleta Hugging Face", analyze = "Preparação dos dados e amostra", site = "Geração do site")
      steps <- c(run = 4L, pilot = 2L, github = 2L, huggingface = 2L, analyze = 2L, site = 1L)
      private$site_failed <- FALSE
      private$progress$begin(paste0(labels[[mode]], " | corte: ", private$config$settings$protocol$cutoff),
        steps[[mode]], private$started)
      private$progress$activity("Verificando configuração e referências")
    },
    execute = function(options) {
      lock <- RunLock$new(private$root)
      on.exit(lock$release(), add = TRUE)
      if (options$mode == "site") {
        private$progress$stage("Geração do site")
        path <- SiteWriter$new(private$config)$render()
        private$progress$event(paste("Site gerado:", path))
        return(path)
      }
      if (options$mode == "analyze") return(private$analyze(options))
      private$collect(options)
    },
    options = function(args) {
      args <- private$normalize_flags(args)
      result <- list(mode = "help", config = "config/settings.yml", coding = NULL, consensus = NULL)
      index <- 1L
      mode_set <- FALSE
      while (index <= length(args)) {
        option <- args[[index]]
        if (option %in% c("--help", "-h")) return(result)
        private$validate_option(option, index, length(args))
        value <- args[[index + 1L]]
        name <- sub("^--", "", option)
        if (name == "mode" && mode_set) stop("Selecione apenas uma modalidade por execução")
        if (name == "mode") mode_set <- TRUE
        result[[name]] <- value
        index <- index + 2L
      }
      private$validate_options(result)
      result
    },
    normalize_flags = function(args) {
      aliases <- c("--pilot" = "pilot", "--run" = "run", "--github" = "github",
        "--huggingface" = "huggingface", "--analyze" = "analyze",
        "--test" = "test", "--check" = "check", "--site" = "site")
      unlist(lapply(args, function(arg) {
        if (arg %in% names(aliases)) return(c("--mode", unname(aliases[[arg]])))
        arg
      }), use.names = FALSE)
    },
    validate_option = function(option, index, size) {
      if (!option %in% c("--mode", "--config", "--coding", "--consensus") || index == size) stop("Opção inválida: ", option)
    },
    validate_options = function(result) {
      allowed <- c("help", "check", "test", "site", "prepare-site", "pilot", "github", "huggingface", "analyze", "run")
      if (!result$mode %in% allowed) stop("Modalidade inválida: ", result$mode)
      if (!is.null(result$coding) && !result$mode %in% c("analyze", "run")) stop("--coding exige analyze ou run")
      if (!is.null(result$consensus) && (!result$mode %in% c("analyze", "run") || is.null(result$coding))) stop("--consensus exige --coding em analyze ou run")
    },
    help = function() {
      cat(paste(c("Projeto de discussões sobre legislação de privacidade em IA/ML",
        "Uso: Rscript main.R <modalidade> [--config arquivo] [--coding arquivo.csv] [--consensus arquivo.csv]",
        "Modalidades: --pilot | --run | --github | --huggingface | --analyze",
        "Forma alternativa: --mode pilot|run|github|huggingface|analyze",
        "Apoio: check | test | site | help",
        "Sem argumentos: ajuda. Nunca inicia uma coleta por acidente.",
        "O piloto não gera o site; coletas e análise geram o site ao concluir.",
        "Instalação local: Rscript main.R --install.",
        "O piloto substitui seus dados anteriores; coletas completas preservam histórico.",
        "Testes não consultam APIs.",
        "Publicação é manual; nenhuma execução faz commit, push ou deploy."), collapse = "\n"), "\n")
    },
    check = function() {
      cat("Configuração válida. Corte: ", private$config$settings$protocol$cutoff, "\n", sep = "")
      cat("Tópicos: 24; leis: 4; termos legais: 7; conceitos: ", length(private$config$concepts$concepts),
          "; categorias: ", length(private$config$taxonomy$categories), "\n", sep = "")
      private$config$require_references()
      cat("Referências disponíveis; fingerprint: ", private$config$fingerprint, "\n", sep = "")
      cat("Quarto: ", if (nzchar(Sys.which("quarto"))) "disponível" else "ausente", "\n", sep = "")
      invisible(TRUE)
    },
    test = function() {
      if (!requireNamespace("testthat", quietly = TRUE) || !requireNamespace("cyclocomp", quietly = TRUE)) {
        stop("Instale testthat e cyclocomp para executar a suíte")
      }
      TestRunner$new(private$config, private$environment)$run()
    },
    analyze = function(options) {
      path <- private$config$path(private$config$settings$paths$database)
      if (!file.exists(path)) stop("Banco científico ausente. Execute as duas coletas primeiro.")
      store <- AuditStore$new(path, private$config)
      on.exit(store$close(), add = TRUE)
      private$progress$stage("Preparação dos CSVs e amostra")
      private$progress$activity("Verificando coletas e preparando a amostra")
      result <- AnalysisExporter$new(private$config, store)$run(options$coding, options$consensus)
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
        result <- AnalysisExporter$new(private$config, store)$run(options$coding, options$consensus)
        private$progress$event(paste("CSVs e amostra preparados em:", result$path))
      }
      if (pilot) private$pilot_report(store)
      store$close()
      manager$promote()
      succeeded <- TRUE
      private$progress$event(paste(if (pilot) "Banco do piloto:" else "Banco científico:", manager$target))
      if (!pilot) private$site()
      invisible(manager$target)
    },
    pilot_report = function(store) {
      path <- file.path(dirname(private$config$path(private$config$settings$paths$pilot_database)), "summary.json")
      summary <- list(scope = "limited_pilot_not_scientific_population",
        limits = private$config$settings$pilot, counts = store$counts(),
        runs = store$query("SELECT * FROM runs ORDER BY rowid"))
      writeLines(ProtocolTools$new()$json(summary), path)
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
        " | elegíveis: ", total(counts$eligible), " | ", if (platform == "github") "issues" else "Discussions",
        " com menções: ", total(counts$legal_discussions), " | requisições: ", requests,
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
