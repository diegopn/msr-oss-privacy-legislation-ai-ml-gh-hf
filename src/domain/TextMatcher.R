TextMatcher <- R6::R6Class("TextMatcher",
  public = list(
    initialize = function(config) {
      private$config <- config
      private$tools <- ProtocolTools$new()
      private$time <- TimePolicy$new(config$settings$protocol$cutoff)
    },
    find = function(artifact, unit_created) {
      output <- list()
      if (!private$time$eligible(artifact$created)) return(output)
      for (law in private$config$settings$protocol$laws) {
        if (!private$time$eligible(unit_created, law$start)) next
        for (term in law$terms) {
          output <- c(output, private$occurrences(artifact, term,
            list(kind = "legal", label = law$id, vocabulary = "protocol", source = "protocol"), TRUE))
        }
      }
      c(output, private$concept_matches(artifact))
    }
  ),
  private = list(
    config = NULL, tools = NULL, time = NULL,
    concept_matches = function(artifact) {
      output <- list()
      for (concept in private$config$concepts$concepts) {
        for (variant in c("original", "revised")) {
          vocabulary <- concept[[variant]]
          for (term in vocabulary$terms) {
            output <- c(output, private$occurrences(artifact, term,
              list(kind = "concept", label = concept$id, vocabulary = variant,
                   source = vocabulary$source), FALSE))
          }
        }
      }
      output
    },
    occurrences = function(artifact, term, metadata, literal) {
      text <- artifact$text
      found <- gregexpr(private$tools$pattern(term, literal), text, ignore.case = TRUE,
                       perl = TRUE)[[1L]]
      if (found[[1L]] < 0L) return(list())
      lapply(seq_along(found), function(index) {
        position <- found[[index]]
        c(metadata, list(term = term, offset = position,
          excerpt = substr(text, max(1L, position - 100L), position + nchar(term) + 100L),
          artifact_key = artifact$key, unit_key = artifact$unit_key,
          rule_version = private$config$settings$protocol$version))
      })
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
