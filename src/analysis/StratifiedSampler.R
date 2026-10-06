StratifiedSampler <- R6::R6Class("StratifiedSampler",
  public = list(
    initialize = function(config) private$settings <- config$settings$sampling,
    size = function(population) {
      if (population <= 0L) return(0L)
      s <- private$settings
      z <- stats::qnorm((1 + s$confidence) / 2)
      n0 <- z ^ 2 * s$proportion * (1 - s$proportion) / s$margin ^ 2
      min(population, ceiling(n0 / (1 + (n0 - 1) / population)))
    },
    draw = function(population) {
      old <- if (exists(".Random.seed", globalenv(), inherits = FALSE)) get(".Random.seed", globalenv()) else NULL
      on.exit(private$restore_seed(old), add = TRUE)
      population <- unique(population)
      keys <- paste(population$platform, population$repo_type, population$law, sep = "|")
      strata <- sort(unique(keys), method = "radix")
      draws <- population[FALSE, , drop = FALSE]
      draws$stratum <- character()
      draws$seed <- integer()
      sizes <- data.frame(stratum = character(), population = integer(), sample = integer(), seed = integer())
      for (index in seq_along(strata)) {
        members <- population[keys == strata[[index]], , drop = FALSE]
        members <- members[order(members$unit_key, method = "radix"), , drop = FALSE]
        n <- self$size(nrow(members))
        seed <- private$settings$seed + index
        set.seed(seed)
        selected <- members[sample.int(nrow(members), n), , drop = FALSE]
        selected$stratum <- strata[[index]]
        selected$seed <- seed
        draws <- rbind(draws, selected)
        sizes <- rbind(sizes, data.frame(stratum = strata[[index]], population = nrow(members), sample = n, seed = seed))
      }
      list(sample = draws, strata = sizes)
    }
  ),
  private = list(
    settings = NULL,
    restore_seed = function(seed) {
      if (is.null(seed)) {
        if (exists(".Random.seed", globalenv(), inherits = FALSE)) rm(".Random.seed", envir = globalenv())
      } else assign(".Random.seed", seed, globalenv())
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
