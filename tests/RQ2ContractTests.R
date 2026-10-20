RQ2ContractTests <- R6::R6Class("RQ2ContractTests",
  public = list(
    initialize = function(config) private$config <- config,
    run = function() {
      private$taxonomy()
      private$categories()
    }
  ),
  private = list(
    config = NULL,
    taxonomy = function() testthat::test_that("RQ2 mantém as 24 categorias e seus metadados", {
      categories <- private$config$taxonomy$categories
      ids <- vapply(categories, `[[`, "", "id")
      testthat::expect_length(ids, 24L)
      testthat::expect_identical(sort(ids), sprintf("C%02d", 1:24))
      for (field in c("label", "cluster", "description", "example")) {
        values <- vapply(categories, `[[`, "", field)
        testthat::expect_true(all(nzchar(values)), info = field)
      }
    }),
    categories = function() testthat::test_that("RQ2 aceita múltiplas categorias válidas e rejeita códigos inválidos", {
      categories <- private$config$taxonomy$categories
      rows <- data.frame(unit_key = rep(letters[1:4], 2),
        reviewer = rep(c("r1", "r2"), each = 4),
        codebook_version = private$config$taxonomy$version,
        relevance = c("0", "0", "1", "1", "0", "1", "1", "1"), categories = "")
      validator <- CodingValidator$new(private$config, letters[1:4])
      rows$categories[c(3L, 7L)] <- "C01;C02"
      testthat::expect_silent(validator$validate(rows))
      testthat::expect_error(validator$validate(rbind(rows, rows[1L, ])), "duplicada")
      invalid <- rows; invalid$relevance[1] <- "2"
      testthat::expect_error(validator$validate(invalid), "Relevância")
      invalid <- rows; invalid$categories[1] <- "C01;C01"
      testthat::expect_error(validator$validate(invalid), "repetida")
      invalid$categories[1] <- "C99"
      testthat::expect_error(validator$validate(invalid), "taxonomia")
      invalid <- rows; invalid$codebook_version[1] <- "old"
      testthat::expect_error(validator$validate(invalid), "Versão")
      invalid <- rows; invalid$categories[1] <- paste(vapply(categories, `[[`, "", "id"), collapse = ";")
      testthat::expect_silent(validator$validate(invalid))
    })
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
