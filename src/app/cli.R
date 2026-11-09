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
      steps <- c(run = 4L, pilot = 2L, github = 1L, huggingface = 1L, analyze = 2L)
      private$site_failed <- FALSE
      private$progress$begin(paste0(labels[[mode]], " | corte: ", private$config$settings$protocol$cutoff),
        steps[[mode]], private$started)
      private$progress$activity("Verificando configuração e referências")
    },
    execute = function(options) {
      platforms <- if (options$mode %in% c("github", "huggingface")) options$mode else c("github", "huggingface")
      lock <- RunLock$new(private$root, platforms = platforms)
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
        "--github e --huggingface podem rodar ao mesmo tempo; cada coleta usa seu próprio banco.",
        "Use --analyze após as duas coletas para consultar os dois bancos e gerar o site.",
        "--run coleta as duas plataformas, analisa e gera o site em uma única execução.",
        "O piloto usa um banco separado e não gera o site.",
        "Arquivos preenchidos de revisão são lidos de caminhos fixos em inputs/final/.",
        "O piloto substitui seus dados anteriores; coletas completas preservam histórico.",
        "Publicação é manual; nenhuma execução faz commit, push ou deploy."), collapse = "\n"), "\n")
    },
    analyze = function(options) {
      paths <- list(github = private$config$database_path("github"),
        huggingface = private$config$database_path("huggingface"))
      for (platform in names(paths)) if (!file.exists(paths[[platform]])) {
        stop("Banco científico de ", platform, " ausente. Execute as duas coletas primeiro.", call. = FALSE)
      }
      stores <- PlatformStores$new(lapply(paths, AuditStore$new, config = private$config, readonly = TRUE))
      on.exit(stores$close(), add = TRUE)
      private$progress$stage("Preparação dos CSVs e amostra")
      private$progress$activity("Verificando coletas e preparando a amostra")
      result <- AnalysisExporter$new(private$config, stores)$run(private$review_file("coding_reviewed"),
        private$review_file("consensus_reviewed"))
      private$progress$event(paste("CSVs e amostra preparados em:", result$path))
      stores$close()
      private$record_site_source(paths)
      private$site()
      invisible(result)
    },
    collect = function(options) {
      if (options$mode == "pilot") return(private$collect_pilot())
      if (options$mode == "run") return(private$collect_complete())
      private$collect_platform_only(options$mode)
    },
    collect_pilot = function() {
      manager <- DatabaseManager$new(private$config, pilot = TRUE, fresh = TRUE)
      store <- AuditStore$new(manager$staging, private$config)
      succeeded <- FALSE
      on.exit({
        store$close()
        if (!succeeded) manager$preserve_failure()
      }, add = TRUE)
      private$collect_platforms(c("github", "huggingface"), store, TRUE)
      private$pilot_report(store)
      store$close()
      manager$promote()
      succeeded <- TRUE
      private$progress$event(paste("Banco do piloto:", manager$target))
      invisible(manager$target)
    },
    collect_platform_only = function(platform) {
      manager <- DatabaseManager$new(private$config, platform = platform, fresh = FALSE)
      store <- AuditStore$new(manager$staging, private$config, recover = TRUE)
      succeeded <- FALSE
      on.exit({
        store$close()
        if (!succeeded) manager$preserve_failure()
      }, add = TRUE)
      private$platform(platform, store, FALSE)
      store$close()
      manager$promote()
      succeeded <- TRUE
      private$progress$event(paste("Banco da coleta", platform, ":", manager$target))
      invisible(manager$target)
    },
    collect_complete = function() {
      private$config$require_references()
      platforms <- c("github", "huggingface")
      managers <- setNames(lapply(platforms, function(platform) {
        DatabaseManager$new(private$config, platform = platform, fresh = TRUE)
      }), platforms)
      stores_list <- lapply(managers, function(manager) AuditStore$new(manager$staging, private$config, recover = TRUE))
      stores <- PlatformStores$new(stores_list)
      promoted <- character()
      succeeded <- FALSE
      on.exit({
        stores$close()
        if (!succeeded) {
          for (platform in rev(promoted)) managers[[platform]]$rollback_promotion()
          for (manager in managers) manager$preserve_failure()
        }
      }, add = TRUE)
      private$collect_platforms(platforms, stores, FALSE)
      private$prepare_analysis(stores)
      stores$close()
      for (platform in platforms) {
        managers[[platform]]$promote()
        promoted <- c(promoted, platform)
      }
      succeeded <- TRUE
      paths <- lapply(managers, function(manager) manager$target)
      private$progress$event(paste("Bancos científicos:", paste(paste(names(paths), unlist(paths), sep = "="), collapse = " | ")))
      private$record_site_source(paths)
      private$site()
      invisible(paths)
    },
    collect_platforms = function(platforms, stores, pilot) {
      for (platform in platforms) {
        store <- if (inherits(stores, "PlatformStores")) stores$for_platform(platform) else stores
        private$platform(platform, store, pilot)
      }
      invisible(TRUE)
    },
    prepare_analysis = function(stores) {
      private$progress$stage("Preparação dos CSVs e amostra")
      private$progress$activity("Verificando coletas e preparando a amostra")
      result <- AnalysisExporter$new(private$config, stores)$run(private$review_file("coding_reviewed"),
        private$review_file("consensus_reviewed"))
      private$progress$event(paste("CSVs e amostra preparados em:", result$path))
      invisible(result)
    },
    record_site_source = function(database_paths) {
      transition <- SiteDataSource$new(private$config)$lock_official(database_paths, complete_run = TRUE)
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
        stop("Coleta ", label, " incompleta: ", problems$pending + problems$gaps,
          " diagnósticos sem verificação; banco oficial anterior preservado.")
      }
      unverified <- problems$pending + problems$gaps
      label_status <- if (unverified > 0L) paste0("concluída | ", unverified,
        " item(ns) pendente(s)/inconclusivo(s)") else "concluída"
      private$progress$report(paste("Coleta", label, label_status))
      private$report_unresolved_problems(store, store$run_id)
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
    report_unresolved_problems = function(store, run_id) {
      rows <- store$query(paste(
        "SELECT code,resource,detail FROM problems WHERE run_id=? AND resolved=0",
        "ORDER BY code,resource,problem_id"), list(run_id))
      if (!nrow(rows)) return(invisible(NULL))
      format_value <- function(value) if (is.na(value) || !nzchar(value)) "(sem detalhe)" else value
      details <- vapply(seq_len(nrow(rows)), function(index) {
        paste0("- [", rows$code[[index]], "] ", format_value(rows$resource[[index]]),
          " — ", format_value(rows$detail[[index]]))
      }, "")
      private$progress$event(paste(c(paste0("Itens com erro ainda pendentes/inconclusivos (", nrow(rows), "):",
        " a coleta continua concluída"), details), collapse = "\n"))
      invisible(rows)
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
