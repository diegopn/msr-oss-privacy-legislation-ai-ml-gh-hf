AnalysisExporter <- R6::R6Class("AnalysisExporter",
  public = list(
    initialize = function(config, store) {
      private$config <- config
      private$store <- store
      private$tools <- ProtocolTools$new()
      private$builder <- PopulationBuilder$new(store)
    },
    run = function(coding_file = NULL, consensus_file = NULL) {
      AnalysisGate$new(private$config, private$store)$verify()
      population <- private$builder$build()
      sampled <- StratifiedSampler$new(private$config)$draw(population)
      destination <- private$config$path(private$config$settings$paths$analysis)
      parent <- dirname(destination)
      dir.create(parent, recursive = TRUE, showWarnings = FALSE)
      temporary <- tempfile(".analysis-", parent)
      dir.create(temporary)
      on.exit(unlink(temporary, recursive = TRUE), add = TRUE)
      sources <- private$builder$sources(unique(sampled$sample$unit_key))
      instrument <- StageAnnotations$new(private$config, sources)
      coding <- instrument$augment(private$coding(sampled$sample, sources))
      independent <- instrument$read(coding_file, coding)
      consensus <- instrument$consensus(coding)
      adjudicated <- instrument$read(consensus_file, consensus, TRUE, independent)
      kappa <- private$kappa(coding_file, independent)
      rq3 <- StageAnalysis$new(private$config, consensus)$run(independent, adjudicated)
      files <- list(population = population, sample = sampled$sample, strata = sampled$strata,
        coding = coding, consensus = consensus, taxonomy = private$taxonomy(),
        development_stages = instrument$codebook(), coding_sources = sources)
      private$write_csv(files, temporary)
      private$input_copy(coding_file, file.path(temporary, "independent-input.csv"))
      private$input_copy(consensus_file, file.path(temporary, "consensus-input.csv"))
      rq3$tables$examples <- instrument$examples(adjudicated)
      tables <- private$tables(rq3$tables)
      on.exit(unlink(tables$temporary, recursive = TRUE), add = TRUE)
      rq3$tables <- NULL
      rq3$sha256 <- tables$hashes
      private$manifest(temporary, kappa, rq3)
      private$publish(tables$temporary, tables$destination)
      private$publish(temporary, destination)
      private$report(rq3)
      invisible(list(path = destination, sample = sampled$sample, kappa = kappa, rq3 = rq3))
    }
  ),
  private = list(
    config = NULL, store = NULL, tools = NULL, builder = NULL,
    coding = function(sample, sources) {
      unique <- sample[!duplicated(sample$unit_key), c("unit_key", "repo_key", "platform", "repo_type", "url"), drop = FALSE]
      unique$text <- vapply(unique$unit_key, private$builder$texts, "")
      unique$initial_text <- vapply(unique$unit_key, function(unit)
        paste(sources$text[sources$unit_key == unit & sources$source_role %in% c("initial", "initial_title")], collapse = "\n\n"), "")
      unique$comment_context <- vapply(unique$unit_key, function(unit)
        paste(sources$text[sources$unit_key == unit & !sources$source_role %in% c("initial", "initial_title")], collapse = "\n\n"), "")
      unique$rq1_context_status <- vapply(unique$unit_key, function(unit)
        if (any(sources$unit_key == unit & sources$source_role == "unresolved_context")) "initial_text_unresolved" else "separated", "")
      output <- list()
      for (reviewer in private$config$settings$sampling$reviewers) {
        rows <- unique
        rows$reviewer <- rep(reviewer, nrow(rows))
        rows$codebook_version <- rep(private$config$taxonomy$version, nrow(rows))
        rows$relevance <- rep("", nrow(rows))
        rows$categories <- rep("", nrow(rows))
        rows$notes <- rep("", nrow(rows))
        output[[reviewer]] <- rows
      }
      do.call(rbind, output)
    },
    taxonomy = function() {
      categories <- private$config$taxonomy$categories
      columns <- c("id", "label", "cluster", "description", "example")
      as.data.frame(setNames(lapply(columns, function(column) vapply(categories, `[[`, "", column)), columns))
    },
    kappa = function(path, rows) {
      if (is.null(path)) return(list(kappa = NA_real_, pairs = 0L, reason = "human_coding_pending"))
      KappaCalculator$new()$compute(rows, private$config$settings$sampling$reviewers)
    },
    write_csv = function(files, path) {
      for (name in names(files)) utils::write.csv(files[[name]], file.path(path, paste0(gsub("_", "-", name), ".csv")),
        row.names = FALSE, na = "", fileEncoding = "UTF-8")
    },
    input_copy = function(source, target) {
      if (!is.null(source) && !file.copy(source, target)) stop("Falha ao preservar planilha importada")
    },
    tables = function(files) {
      destination <- private$config$path("outputs/tables/rq3")
      dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
      temporary <- tempfile(".rq3-", dirname(destination))
      dir.create(temporary)
      for (name in names(files)) files[[name]]$stage_codebook_version <- rep(private$config$stages$version, nrow(files[[name]]))
      private$write_csv(files, temporary)
      paths <- list.files(temporary, full.names = TRUE)
      hashes <- setNames(vapply(paths, function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE), ""),
        file.path("outputs/tables/rq3", basename(paths)))
      list(temporary = temporary, destination = destination, hashes = as.list(hashes))
    },
    report = function(rq3) {
      path <- private$config$path("outputs/reports/rq3.json")
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      temporary <- tempfile(".rq3-", dirname(path))
      on.exit(unlink(temporary), add = TRUE)
      writeLines(private$tools$json(rq3), temporary)
      if (!file.rename(temporary, path)) stop("Falha ao gravar relatório RQ3")
    },
    manifest = function(path, kappa, rq3) {
      files <- list.files(path, full.names = TRUE)
      hashes <- setNames(vapply(files, function(file) digest::digest(file = file, algo = "sha256", serialize = FALSE), ""), basename(files))
      data <- list(status = "collection_completed_human_evaluation_pending", generated = private$tools$now(),
        config_hash = private$config$fingerprint, protocol = private$config$settings$protocol,
        codebook_version = private$config$taxonomy$version, sampling = private$config$settings$sampling,
        rng = RNGkind(), counts = private$store$counts(), kappa = kappa, rq3 = rq3, sha256 = as.list(hashes),
        runtime = private$runtime(),
        runs = private$store$query("SELECT * FROM runs WHERE pilot=0 ORDER BY rowid"),
        limitations = c("Current metadata and edited text; no full historical reconstruction",
          "GitHub root manifests; no source traversal", "HF license index coverage unvalidated",
          "No BERT execution; automatic outputs are not human validation",
          "RQ3 describes the manual sample; inference requires comparable projects and a clustered design",
          "Other RQ1/RQ2 dissertation analyses are outside this extension"))
      writeLines(private$tools$json(data), file.path(path, "manifest.json"))
    },
    runtime = function() {
      packages <- c("R6", "yaml", "jsonlite", "httr2", "DBI", "RSQLite", "digest")
      versions <- setNames(vapply(packages, function(package) as.character(utils::packageVersion(package)), ""), packages)
      list(R = R.version.string, platform = R.version$platform, locale = Sys.getlocale(),
           packages = as.list(versions))
    },
    publish = function(temporary, destination) {
      old <- NULL
      if (dir.exists(destination)) {
        archive <- file.path(dirname(destination), "archive")
        dir.create(archive, recursive = TRUE, showWarnings = FALSE)
        old <- tempfile("analysis-", archive)
        if (!file.rename(destination, old)) stop("Falha ao arquivar a análise anterior")
      }
      if (!file.rename(temporary, destination)) {
        if (!is.null(old)) file.rename(old, destination)
        stop("Falha ao publicar os arquivos de análise")
      }
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
