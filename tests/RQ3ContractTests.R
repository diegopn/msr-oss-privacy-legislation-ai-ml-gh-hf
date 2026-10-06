RQ3ContractTests <- R6::R6Class("RQ3ContractTests",
  public = list(
    initialize = function(config) {
      private$config <- config
      private$factory <- FixtureFactory$new(config)
    },
    run = function() {
      private$instrument()
      private$annotations()
      private$statistics()
      private$source_roles()
      private$integration()
    }
  ),
  private = list(
    config = NULL, factory = NULL,
    setup = function() {
      fixture <- private$factory$create()
      fixture$config$osi$licenses <- Filter(function(x) x$id %in% c("MIT", "Apache-2.0"), fixture$config$osi$licenses)
      mock <- MockHubTransport$new(private$factory)
      journal <- CollectionJournal$new(fixture$config)
      for (platform in c("github", "huggingface")) {
        http <- private$factory$http(fixture, platform, mock$perform)
        collector <- if (platform == "github") GitHubCollector$new(fixture$config, fixture$store, http) else
          HuggingFaceCollector$new(fixture$config, fixture$store, http)
        collector$run()
        journal$record(platform, fixture$store$run_id, "completed", fixture$config)
      }
      fixture
    },
    read = function(path) utils::read.csv(path, colClasses = "character", na.strings = character(), check.names = FALSE),
    fill = function(rows, sources) {
      rows$relevance <- "1"; rows$categories <- "C01"
      rows$stage_status <- "identified"; rows$stages <- "S02;S06"
      rows$notes <- "Exemplo artificial para contrato; não é avaliação humana."
      rows$stage_evidence <- vapply(rows$unit_key, function(unit) {
        source <- sources[sources$unit_key == unit & nzchar(sources$text), ][1L, ]
        ProtocolTools$new()$json(lapply(c("S02", "S06"), function(stage) list(
          stage_id = stage, artifact_key = source$artifact_key, excerpt = substr(source$text, 1L, 20L))))
      }, "")
      rows
    },
    instrument = function() testthat::test_that("RQ3 tem nove etapas próprias e preserva o protocolo da coleta", {
      testthat::expect_identical(vapply(private$config$stages$stages, function(x) x$id, ""), sprintf("S%02d", 1:9))
      testthat::expect_identical(private$config$stages$version, "ml-stages-1.0.0")
      testthat::expect_identical(private$config$stages$source_doi, "10.1109/ICSE-SEIP.2019.00042")
      testthat::expect_identical(private$config$fingerprint, "26591bcf4151981cfa267c93518bfe73cc7b56eb2d3f4e9e8e30cc9a0d6ee376")
      testthat::expect_length(private$config$taxonomy$categories, 24L)
      testthat::expect_identical(private$config$settings$protocol$version, "1.1.0")
    }),
    annotations = function() testthat::test_that("importação de etapas valida multilabel, evidências, identidade e cobertura", {
      fixture <- private$setup(); on.exit(fixture$cleanup(), add = TRUE)
      export <- AnalysisExporter$new(fixture$config, fixture$store)$run()
      template <- private$read(file.path(export$path, "coding.csv"))
      sources <- private$read(file.path(export$path, "coding-sources.csv"))
      testthat::expect_true(all(template$stage_status == "pending"))
      testthat::expect_true(all(template$stages == "" & template$stage_evidence == ""))
      instrument <- StageAnnotations$new(fixture$config, sources)
      rows <- private$fill(template, sources)
      path <- fixture$config$path("independent.csv")
      utils::write.csv(rows, path, row.names = FALSE, na = "")
      testthat::expect_equal(instrument$read(path, template), rows)
      invalid <- function(changed, pattern) {
        utils::write.csv(changed, path, row.names = FALSE, na = "")
        testthat::expect_error(instrument$read(path, template), pattern)
      }
      bad <- rows; bad$stages[1] <- "S99"; invalid(bad, "Etapa")
      bad <- rows; bad$stages[1] <- "S02;S02"; invalid(bad, "repetida")
      bad <- rows; bad$stage_status[1] <- "indeterminate"; invalid(bad, "indeterminada")
      bad <- rows; bad$stage_status[1] <- "pending"; invalid(bad, "pendente")
      bad <- rows; bad$stage_codebook_version[1] <- "old"; invalid(bad, "Versão")
      bad <- rows; bad$stage_codebook_hash[1] <- "old"; invalid(bad, "Conteúdo")
      bad <- rows; bad$stage_evidence[1] <- "broken"; invalid(bad, "Evidência")
      bad <- rows; bad$stage_evidence[1] <- "[]"; invalid(bad, "Evidência")
      bad <- rows; bad$stage_evidence[1] <- ProtocolTools$new()$json(list(list(
        stage_id = "S02", artifact_key = sources$artifact_key[1], excerpt = "Texto inventado"))); invalid(bad, "trecho|Evidência")
      bad <- rows; bad$stage_evidence[1] <- rows$stage_evidence[2]; invalid(bad, "unidade")
      bad <- rows; bad$reviewer[1] <- "other"; invalid(bad, "avaliador")
      invalid(rows[-1L, ], "amostra")
      invalid(rbind(rows, rows[1L, ]), "duplicada")
      bad <- rows; bad$unit_key[1] <- "outside"; invalid(bad, "amostra")
      bad <- rows; bad$relevance[1] <- "0"; invalid(bad, "relevante")
      bad <- rows; bad$stage_evidence <- NULL; invalid(bad, "Colunas")
      decided <- rows
      decided$stage_status[1] <- "indeterminate"; decided$stages[1] <- ""
      evidence <- jsonlite::fromJSON(decided$stage_evidence[1], simplifyVector = FALSE)[[1L]]
      evidence$stage_id <- "indeterminate"
      decided$stage_evidence[1] <- ProtocolTools$new()$json(list(evidence))
      utils::write.csv(decided, path, row.names = FALSE)
      testthat::expect_silent(instrument$read(path, template))
      decided$notes[1] <- ""; invalid(decided, "Justificativa")
      legacy <- rows[, setdiff(names(rows), c("stage_status", "stages", "stage_evidence", "stage_codebook_version", "stage_codebook_hash"))]
      utils::write.csv(legacy, path, row.names = FALSE)
      old <- instrument$read(path, template)
      testthat::expect_true(all(old$stage_status == "pending" & old$stages == ""))
      testthat::expect_equal(old$relevance, legacy$relevance)
      decided <- rows; decided$stage_status[1] <- "not_applicable"; decided$relevance[1] <- "0"
      decided$stages[1] <- ""; decided$stage_evidence[1] <- ""
      utils::write.csv(decided, path, row.names = FALSE)
      testthat::expect_silent(instrument$read(path, template))
      decided$relevance[1] <- "1"; invalid(decided, "zero")
      minimal <- rows[, c("unit_key", "reviewer", "codebook_version", "relevance", "categories", "notes",
        "stage_codebook_version", "stage_codebook_hash", "stage_status", "stages", "stage_evidence")]
      utils::write.csv(minimal, path, row.names = FALSE)
      testthat::expect_equal(instrument$read(path, template)$repo_key, rows$repo_key)
    }),
    statistics = function() testthat::test_that("RQ3 distingue denominadores, zero HF, pendências e kappa indefinido", {
      units <- data.frame(unit_key = letters[1:4], repo_key = c("g", "g", "h", "h"), platform = rep(c("github", "huggingface"), each = 2),
        repo_type = c("repository", "repository", "model", "dataset"), url = letters[1:4])
      rows <- do.call(rbind, lapply(private$config$settings$sampling$reviewers, function(reviewer)
        transform(units, reviewer = reviewer, stage_codebook_version = private$config$stages$version,
          relevance = "1", categories = "C01", stage_status = "identified", stages = "S01")))
      rows$stages[c(3,4,6,7,8)] <- "S01;S02"
      consensus <- transform(units, reviewer = "adjudicator", relevance = "1", categories = "C01;C02",
        stage_codebook_version = private$config$stages$version, stage_status = "identified", stages = "S02;S06")
      consensus$stage_status[3:4] <- c("indeterminate", "pending"); consensus$stages[3:4] <- ""
      analysis <- StageAnalysis$new(private$config, units)
      result <- analysis$run(rows, consensus)
      agreement <- result$tables$agreement
      s02 <- agreement[agreement$stage_id == "S02" & agreement$platform == "all", ]
      testthat::expect_equal(s02$pairs, 4L)
      testthat::expect_equal(s02$observed, 0.75)
      testthat::expect_equal(s02$kappa, 0.5)
      testthat::expect_identical(agreement$reason[agreement$stage_id == "S01" & agreement$platform == "all"], "expected_agreement_one")
      stages <- result$tables$stages
      gh <- stages[stages$platform == "github", ]
      hf <- stages[stages$platform == "huggingface", ]
      testthat::expect_true(all(gh$denominator == 2L))
      testthat::expect_equal(sum(gh$proportion), 2)
      testthat::expect_true(all(hf$denominator == 1L & hf$n_indeterminate == 1L & hf$n_stage_pending == 1L))
      testthat::expect_equal(nrow(result$tables$stage_categories), 8L)
      testthat::expect_identical(result$status, "human_evaluation_partial")
      testthat::expect_true(all(is.na(result$tables$contrasts$p_value)))
      testthat::expect_true(all(result$tables$contrasts$reason == "human_annotation_pending"))
      consensus$stage_status[3:4] <- "not_applicable"; consensus$relevance[3:4] <- "0"
      result <- analysis$run(rows, consensus)
      hf <- result$tables$stages[result$tables$stages$platform == "huggingface", ]
      testthat::expect_true(all(hf$n_relevant == 0L & hf$denominator == 0L & is.na(hf$proportion)))
      testthat::expect_true(all(result$tables$contrasts$reason == "no_relevant_discussions"))
      testthat::expect_identical(result$status, "human_evaluation_complete")
      consensus$stage_status[3:4] <- "identified"; consensus$relevance[3:4] <- "1"; consensus$stages[3:4] <- "S02"
      result <- analysis$run(rows, consensus)
      testthat::expect_true(all(result$tables$contrasts$reason == "project_comparability_and_cluster_design_pending"))
      pending <- rows; pending$stage_status <- "pending"; pending$stages <- ""
      result <- analysis$run(pending, transform(consensus, stage_status = "pending", relevance = "", stages = ""))
      testthat::expect_identical(result$status, "human_evaluation_pending")
      testthat::expect_true(all(result$tables$agreement$pairs == 0L & is.na(result$tables$agreement$kappa)))
      indeterminate <- transform(rows, stage_status = "indeterminate", stages = "")
      result <- analysis$run(indeterminate, transform(consensus, stage_status = "indeterminate", stages = ""))
      testthat::expect_true(all(result$tables$agreement$pairs == 0L))
      testthat::expect_true(all(result$tables$agreement$n_indeterminate_ratings > 0L))
      empty <- analysis$run(rows[FALSE, ], consensus[FALSE, ])
      testthat::expect_true(all(is.na(empty$tables$stages$proportion)))
    }),
    source_roles = function() testthat::test_that("texto inicial HF exige autoria e data, preservando comentários e eventos de contexto", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("huggingface")
      fixture$store$repository(list(key = "repo", platform = "huggingface", type = "model", id = "org/test",
        status = "eligible", reason = "test", ai = list(signals = list())))
      created <- "2022-01-01T00:00:00Z"
      main <- list(key = "unit", unit_key = "unit", repo_key = "repo", platform = "huggingface",
        kind = "discussion", created = created, text = "Title", url = "url", metadata = list(author = "person"))
      fixture$store$artifact(main)
      events <- list(
        list(key = "e0", type = "title-change", author = "person", date = created, text = "Old title"),
        list(key = "e1", type = "comment", author = "person", date = created, text = "Initial body"),
        list(key = "e2", type = "comment", author = "bot", date = "2022-01-02T00:00:00Z", text = "Automated context"))
      for (event in events) {
        artifact <- main; artifact$key <- event$key; artifact$kind <- "event"
        artifact$created <- event$date; artifact$text <- event$text
        artifact$metadata <- list(type = event$type, author = event$author)
        fixture$store$artifact(artifact)
      }
      sources <- PopulationBuilder$new(fixture$store)$sources("unit")
      testthat::expect_identical(sources$source_role[match(c("unit", "e0", "e1", "e2"), sources$artifact_key)],
        c("initial_title", "event_context", "initial", "comment_context"))
      testthat::expect_true("Automated context" %in% sources$text)
    }),
    integration = function() testthat::test_that("análise preserva decisões independentes e consenso, sem substituir planilhas", {
      fixture <- private$setup(); on.exit(fixture$cleanup(), add = TRUE)
      exporter <- AnalysisExporter$new(fixture$config, fixture$store)
      result <- exporter$run()
      coding <- private$read(file.path(result$path, "coding.csv"))
      sources <- private$read(file.path(result$path, "coding-sources.csv"))
      consensus <- private$read(file.path(result$path, "consensus.csv"))
      rows <- private$fill(coding, sources)
      consensus <- private$fill(consensus, sources); consensus$reviewer <- "adjudicator"
      independent_path <- fixture$config$path("manual-independent.csv")
      consensus_path <- fixture$config$path("manual-consensus.csv")
      utils::write.csv(rows, independent_path, row.names = FALSE)
      utils::write.csv(consensus, consensus_path, row.names = FALSE)
      before <- digest::digest(file = independent_path, algo = "sha256")
      testthat::expect_error(exporter$run(NULL, consensus_path), "independentes")
      result <- exporter$run(independent_path, consensus_path)
      manifest <- jsonlite::fromJSON(file.path(result$path, "manifest.json"), simplifyVector = FALSE)
      testthat::expect_identical(manifest$rq3$status, "human_evaluation_complete")
      testthat::expect_identical(manifest$rq3$codebook_version, "ml-stages-1.0.0")
      testthat::expect_equal(manifest$rq3$coverage$independent_complete, 6L)
      testthat::expect_equal(manifest$rq3$coverage$consensus_complete, 3L)
      testthat::expect_identical(digest::digest(file = independent_path, algo = "sha256"), before)
      testthat::expect_equal(readBin(file.path(result$path, "independent-input.csv"), "raw", n = file.info(independent_path)$size),
        readBin(independent_path, "raw", n = file.info(independent_path)$size))
      testthat::expect_true(file.exists(fixture$config$path("outputs/tables/rq3/stages.csv")))
      testthat::expect_true(file.exists(fixture$config$path("outputs/tables/rq3/agreement.csv")))
      examples <- private$read(fixture$config$path("outputs/tables/rq3/examples.csv"))
      testthat::expect_equal(nrow(examples), 6L)
      testthat::expect_true(all(examples$artifact_key %in% sources$artifact_key))
      testthat::expect_true(all(examples$reviewer == "adjudicator"))
      testthat::expect_true(all(c("initial", "comment_context", "unresolved_context") %in% sources$source_role))
      testthat::expect_true(any(sources$kind == "comment" & grepl("CCPA CPRA", sources$text, fixed = TRUE)))
      file.copy(private$config$path("site"), fixture$config$root, recursive = TRUE)
      dir.create(fixture$config$path("inputs/reference"), recursive = TRUE)
      file.copy(private$config$path("inputs/reference/literature_methods.md"), fixture$config$path("inputs/reference/literature_methods.md"))
      dir.create(dirname(fixture$config$path(fixture$config$settings$paths$database)), recursive = TRUE, showWarnings = FALSE)
      file.copy(fixture$store$path, fixture$config$path(fixture$config$settings$paths$database))
      SiteWriter$new(fixture$config)$prepare()
      page <- paste(readLines(fixture$config$path("index.qmd")), collapse = "\n")
      testthat::expect_match(page, "RQ3")
      testthat::expect_match(page, "Requisitos do modelo")
      testthat::expect_false(grepl("GDPR CCPA CPRA Data Protection Act", page, fixed = TRUE))
      state <- jsonlite::fromJSON(fixture$config$path("site/summary.json"))
      testthat::expect_identical(state$rq3_status, "human_evaluation_complete")
      table_path <- fixture$config$path("outputs/tables/rq3/stages.csv")
      bytes <- readBin(table_path, "raw", n = file.info(table_path)$size)
      writeLines("altered", table_path)
      SiteWriter$new(fixture$config)$prepare()
      testthat::expect_identical(jsonlite::fromJSON(fixture$config$path("site/summary.json"))$rq3_status, "human_evaluation_pending")
      writeBin(bytes, table_path)
      fixture$config$stages$version <- "ml-stages-2.0.0"
      SiteWriter$new(fixture$config)$prepare()
      testthat::expect_identical(jsonlite::fromJSON(fixture$config$path("site/summary.json"))$rq3_status, "human_evaluation_pending")
      fixture$config$stages$version <- "ml-stages-1.0.0"
      exporter$run()
      SiteWriter$new(fixture$config)$prepare()
      state <- jsonlite::fromJSON(fixture$config$path("site/summary.json"))
      testthat::expect_identical(state$rq3_status, "human_evaluation_pending")
      testthat::expect_match(paste(readLines(fixture$config$path("index.qmd")), collapse = "\n"), "RQ3 pendente")
      testthat::expect_identical(digest::digest(file = independent_path, algo = "sha256"), before)
    })
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
