CodingValidator <- R6::R6Class("CodingValidator",
  public = list(
    initialize = function(config, units) {
      private$categories <- vapply(config$taxonomy$categories, `[[`, "", "id")
      private$version <- config$taxonomy$version
      private$units <- units
    },
    validate = function(rows) {
      required <- c("unit_key", "reviewer", "codebook_version", "relevance", "categories")
      if (!all(required %in% names(rows))) stop("Colunas de codificação ausentes")
      values <- as.character(rows$relevance)
      values[is.na(values)] <- ""
      if (!all(values %in% c("0", "1", ""))) stop("Relevância deve ser 0, 1 ou vazio")
      if (anyNA(rows[required[c(1L, 2L, 3L)]]) || any(!nzchar(rows$reviewer))) stop("Identidade de codificação ausente")
      if (!all(rows$unit_key %in% private$units)) stop("Unidade fora da amostra")
      if (!all(rows$codebook_version == private$version)) stop("Versão do codebook incompatível")
      key <- paste(rows$unit_key, rows$reviewer, rows$codebook_version, sep = "\034")
      if (anyDuplicated(key)) stop("Codificação duplicada por avaliador e versão")
      for (value in rows$categories) private$validate_categories(value)
      invisible(TRUE)
    }
  ),
  private = list(
    categories = NULL, version = NULL, units = NULL,
    validate_categories = function(value) {
      if (is.na(value) || !nzchar(trimws(value))) return(invisible(TRUE))
      ids <- trimws(strsplit(value, ";", fixed = TRUE)[[1L]])
      if (anyDuplicated(ids)) stop("Categoria repetida na mesma codificação")
      if (!all(ids %in% private$categories)) stop("Categoria fora da taxonomia")
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
