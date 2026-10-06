StageAnnotations <- R6::R6Class("StageAnnotations",
  public = list(
    initialize = function(config, sources) {
      private$config <- config
      private$sources <- sources
      private$stages <- vapply(config$stages$stages, function(x) x$id, "")
    },
    augment = function(rows) {
      rows$stage_codebook_version <- rep(private$config$stages$version, nrow(rows))
      rows$stage_codebook_hash <- rep(private$config$stage_fingerprint, nrow(rows))
      rows$stage_status <- rep("pending", nrow(rows))
      rows$stages <- rep("", nrow(rows))
      rows$stage_evidence <- rep("", nrow(rows))
      rows
    },
    consensus = function(coding) {
      rows <- coding[!duplicated(coding$unit_key), , drop = FALSE]
      rows$reviewer <- rep("", nrow(rows))
      rows
    },
    read = function(path, template, consensus = FALSE, independent = NULL) {
      if (is.null(path)) return(template)
      rows <- utils::read.csv(path, colClasses = "character", na.strings = character(), check.names = FALSE)
      base <- rows
      if (consensus) base$reviewer[base$reviewer == ""] <- "pending_consensus"
      CodingValidator$new(private$config, unique(template$unit_key))$validate(base)
      fields <- c("stage_codebook_version", "stage_codebook_hash", "stage_status", "stages", "stage_evidence")
      if (!any(fields %in% names(rows)) && !consensus) return(self$augment(private$metadata(rows, template)))
      if (!all(c(fields, "notes") %in% names(rows))) stop("Colunas de etapas ausentes")
      if (anyNA(rows[c(fields, "notes")])) stop("Campos de etapas ausentes")
      if (!all(rows$stage_codebook_version == private$config$stages$version)) stop("Versão do instrumento de etapas incompatível")
      if (!all(rows$stage_codebook_hash == private$config$stage_fingerprint)) stop("Conteúdo do codebook de etapas incompatível")
      private$coverage(rows, template, consensus)
      for (i in seq_len(nrow(rows))) private$validate_row(rows[i, , drop = FALSE])
      if (consensus) private$consensus_ready(rows, independent)
      private$metadata(rows, template)
    },
    codebook = function() {
      columns <- c("id", "label", "definition", "inclusion", "exclusion", "llm_adaptation")
      rows <- as.data.frame(setNames(lapply(columns, function(column)
        vapply(private$config$stages$stages, function(x) x[[column]], "")), columns))
      rows$version <- private$config$stages$version
      rows$source_doi <- private$config$stages$source_doi
      rows
    },
    examples = function(rows) {
      output <- list()
      for (i in which(rows$stage_status %in% c("identified", "indeterminate"))) {
        evidence <- jsonlite::fromJSON(rows$stage_evidence[i], simplifyVector = FALSE)
        for (quote in evidence) {
          source <- private$sources[match(quote$artifact_key, private$sources$artifact_key), , drop = FALSE]
          output[[length(output) + 1L]] <- data.frame(unit_key = rows$unit_key[i], artifact_key = quote$artifact_key,
            platform = source$platform, repo_key = source$repo_key, url = source$url, source_role = source$source_role,
            reviewer = rows$reviewer[i], stage_codebook_version = rows$stage_codebook_version[i],
            stage_id = quote$stage_id, excerpt = quote$excerpt, notes = rows$notes[i])
        }
      }
      if (length(output)) return(do.call(rbind, output))
      as.data.frame(setNames(rep(list(character()), 11L), c("unit_key", "artifact_key", "platform", "repo_key",
        "url", "source_role", "reviewer", "stage_codebook_version", "stage_id", "excerpt", "notes")))
    }
  ),
  private = list(
    config = NULL, sources = NULL, stages = NULL,
    metadata = function(rows, template) {
      fields <- intersect(c("repo_key", "platform", "repo_type", "url", "text", "initial_text", "comment_context", "rq1_context_status"), names(template))
      for (field in setdiff(fields, names(rows))) rows[[field]] <- template[[field]][match(rows$unit_key, template$unit_key)]
      rows
    },
    coverage = function(rows, template, consensus) {
      key <- function(x) if (consensus) x$unit_key else paste(x$unit_key, x$reviewer, sep = "\034")
      if (anyDuplicated(key(rows))) stop("Anotação de etapas duplicada")
      if (!consensus && !all(rows$reviewer %in% private$config$settings$sampling$reviewers)) stop("Nome de avaliador não configurado")
      if (!setequal(key(rows), key(template))) stop("Os dois avaliadores devem cobrir toda a amostra; preserve linhas pendentes")
      columns <- intersect(c("repo_key", "platform", "repo_type", "url"), names(rows))
      expected <- template[match(rows$unit_key, template$unit_key), columns, drop = FALSE]
      if (!identical(unname(as.matrix(rows[columns])), unname(as.matrix(expected)))) stop("Metadados da unidade incompatíveis")
    },
    ids = function(value) {
      if (!nzchar(trimws(value))) return(character())
      if (endsWith(trimws(value), ";")) stop("Etapa vazia")
      trimws(strsplit(value, ";", fixed = TRUE)[[1L]])
    },
    validate_row = function(row) {
      status <- row$stage_status
      if (!status %in% c("pending", "identified", "indeterminate", "not_applicable")) stop("Estado de etapa inválido")
      if (status == "pending") {
        private$empty(row, "Anotação pendente não pode ter etapas ou evidências")
        return(invisible(TRUE))
      }
      if (status == "not_applicable") {
        if (row$relevance != "0") stop("Etapa não aplicável exige relevância zero")
        private$empty(row, "Etapa não aplicável exige campos vazios")
        return(invisible(TRUE))
      }
      if (row$relevance != "1") stop("Etapa avaliada exige discussão relevante")
      ids <- private$identified(row)
      private$evidence(row$stage_evidence, row$unit_key, ids)
    },
    empty = function(row, message) {
      if (nzchar(row$stages) || nzchar(row$stage_evidence)) stop(message)
    },
    identified = function(row) {
      if (row$stage_status == "indeterminate") {
        if (nzchar(row$stages)) stop("Etapa indeterminada não pode coexistir com etapas identificadas")
        if (!nzchar(trimws(row$notes))) stop("Justificativa de etapa indeterminada ausente")
        return("indeterminate")
      }
      ids <- private$ids(row$stages)
      if (!length(ids) || !all(ids %in% private$stages)) stop("Etapa fora do instrumento")
      if (anyDuplicated(ids)) stop("Etapa repetida")
      ids
    },
    evidence = function(value, unit, ids) {
      quotes <- tryCatch(jsonlite::fromJSON(value, simplifyVector = FALSE), error = function(e) NULL)
      if (!startsWith(trimws(value), "[") || !is.list(quotes) || !length(quotes)) stop("Evidência deve ser uma lista JSON não vazia")
      quoted <- vapply(quotes, function(quote) private$quote(quote, unit, ids), "")
      if (!setequal(quoted, ids)) stop("Evidência ausente para uma das etapas")
    },
    quote = function(quote, unit, ids) {
      fields <- c("stage_id", "artifact_key", "excerpt")
      if (!is.list(quote) || !all(fields %in% names(quote))) stop("Evidência sem etapa, artefato ou trecho")
      if (!all(vapply(quote[fields], function(x) is.character(x) && length(x) == 1L && nzchar(trimws(x)), logical(1)))) stop("Evidência com campo inválido")
      if (!quote$stage_id %in% ids) stop("Evidência para etapa não selecionada")
      source <- private$sources[private$sources$artifact_key == quote$artifact_key & private$sources$unit_key == unit, , drop = FALSE]
      if (nrow(source) != 1L) stop("Evidência pertence a outra unidade ou artefato desconhecido")
      if (!grepl(quote$excerpt, source$text, fixed = TRUE)) stop("O trecho de evidência não consta no artefato")
      quote$stage_id
    },
    consensus_ready = function(rows, independent) {
      complete <- rows$stage_status != "pending"
      if (is.null(independent) && any(complete)) stop("Consenso exige avaliações independentes")
      if (any(complete & (!nzchar(trimws(rows$reviewer)) | !nzchar(trimws(rows$notes))))) stop("Consenso exige avaliador e justificativa")
      for (unit in rows$unit_key[complete]) {
        decisions <- independent[independent$unit_key == unit & independent$stage_status != "pending", , drop = FALSE]
        if (!setequal(decisions$reviewer, private$config$settings$sampling$reviewers) || nrow(decisions) != 2L) {
          stop("Consenso exige duas avaliações independentes concluídas")
        }
      }
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
