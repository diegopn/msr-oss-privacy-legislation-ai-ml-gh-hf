KappaCalculator <- R6::R6Class("KappaCalculator",
  public = list(
    compute = function(rows, reviewers) {
      if (length(reviewers) != 2L || anyDuplicated(reviewers) || any(!nzchar(reviewers))) {
        stop("Kappa exige dois avaliadores distintos")
      }
      left <- private$answers(rows, reviewers[[1L]])
      right <- private$answers(rows, reviewers[[2L]])
      pairs <- merge(left, right, by = c("unit_key", "codebook_version"), suffixes = c("_a", "_b"))
      if (!nrow(pairs)) return(list(kappa = NA_real_, pairs = 0L, reason = "no_complete_pairs"))
      a <- as.character(pairs$relevance_a)
      b <- as.character(pairs$relevance_b)
      observed <- mean(a == b)
      labels <- sort(unique(c(a, b)))
      expected <- sum(vapply(labels, function(label) mean(a == label) * mean(b == label), numeric(1)))
      value <- if (expected == 1) NA_real_ else (observed - expected) / (1 - expected)
      list(kappa = value, pairs = nrow(pairs), observed = observed, expected = expected,
           reason = if (expected == 1) "expected_agreement_one" else "defined")
    }
  ),
  private = list(
    answers = function(rows, reviewer) {
      complete <- !is.na(rows$relevance) & nzchar(as.character(rows$relevance))
      result <- rows[rows$reviewer == reviewer & complete, c("unit_key", "codebook_version", "relevance"), drop = FALSE]
      if (anyDuplicated(result[c("unit_key", "codebook_version")])) stop("Respostas duplicadas para kappa")
      if (!all(as.character(result$relevance) %in% c("0", "1"))) stop("Resposta inválida para kappa")
      result
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
