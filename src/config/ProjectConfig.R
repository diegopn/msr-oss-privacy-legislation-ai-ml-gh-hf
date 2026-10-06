ProjectConfig <- R6::R6Class("ProjectConfig",
  public = list(
    root = NULL, settings = NULL, concepts = NULL, taxonomy = NULL, osi = NULL,
    fingerprint = NULL, stages = NULL, stage_fingerprint = NULL,
    initialize = function(root, file = "config/settings.yml") {
      self$root <- normalizePath(root, mustWork = TRUE)
      self$settings <- yaml::read_yaml(self$path(file))
      self$concepts <- yaml::read_yaml(self$path(self$settings$references$concepts))
      self$taxonomy <- yaml::read_yaml(self$path(self$settings$references$taxonomy))
      self$osi <- jsonlite::fromJSON(self$path(self$settings$eligibility$osi_file),
                                    simplifyVector = FALSE)
      self$stages <- yaml::read_yaml(self$path("config/development-stages.yml"))
      private$validate()
      private$validate_stages()
      self$stage_fingerprint <- digest::digest(self$stages, algo = "sha256")
      # O instrumento humano tem versão própria; não altera a identidade da coleta.
      self$fingerprint <- digest::digest(list(self$settings, self$concepts, self$taxonomy,
                                              self$osi), algo = "sha256")
    },
    path = function(relative) {
      if (grepl("^/", relative)) return(relative)
      file.path(self$root, relative)
    },
    reference_status = function() {
      c(concepts = isTRUE(self$concepts$reviewed) && length(self$concepts$concepts) == 20L,
        taxonomy = isTRUE(self$taxonomy$reviewed) && length(self$taxonomy$categories) == 24L)
    },
    require_references = function() {
      status <- self$reference_status()
      if (!all(status)) stop("Referências pendentes: ", paste(names(status)[!status], collapse = ", "),
                            ". Importe e revise as listas do artigo antes da análise científica.",
                            call. = FALSE)
      private$validate_references()
      invisible(TRUE)
    },
    limit = function(name, pilot = FALSE) {
      if (!pilot) return(Inf)
      self$settings$pilot[[name]]
    }
  ),
  private = list(
    validate_stages = function() {
      stopifnot(identical(vapply(self$stages$stages, function(x) x$id, ""), sprintf("S%02d", 1:9)),
        nzchar(self$stages$version), identical(self$stages$source_doi, "10.1109/ICSE-SEIP.2019.00042"))
      for (stage in self$stages$stages) {
        stopifnot(all(vapply(stage[c("label", "definition", "inclusion", "exclusion", "llm_adaptation")],
          function(value) is.character(value) && length(value) == 1L && nzchar(value), logical(1))))
      }
    },
    validate = function() {
      s <- self$settings
      stopifnot(length(s$protocol$laws) == 4L,
                identical(vapply(s$protocol$laws, `[[`, "", "id"),
                          c("GDPR", "CCPA", "CPRA", "Data Protection Act")),
                sum(lengths(lapply(s$protocol$laws, `[[`, "terms"))) == 7L,
                identical(s$protocol$cutoff, "2026-09-22"),
                length(unique(s$ai$topics)) == 24L, s$http$page_size == 100L,
                s$http$attempts == 5L, s$http$timeout == 30L,
                s$sampling$confidence == 0.99, s$sampling$margin == 0.05,
                s$sampling$proportion == 0.5, s$sampling$seed == 20260920,
                length(s$sampling$reviewers) == 2L, !anyDuplicated(s$sampling$reviewers),
                all(nzchar(s$sampling$reviewers)))
    },
    validate_references = function() {
      categories <- self$taxonomy$categories
      ids <- vapply(categories, `[[`, "", "id")
      stopifnot(!anyDuplicated(ids), all(nzchar(ids)), nzchar(self$taxonomy$source),
                nzchar(self$concepts$source), nzchar(self$taxonomy$version))
      concepts <- self$concepts$concepts
      stopifnot(!anyDuplicated(vapply(concepts, `[[`, "", "id")))
      for (concept in concepts) {
        for (variant in c("original", "revised")) {
          vocabulary <- concept[[variant]]
          if (variant == "revised" && !length(vocabulary$terms)) next
          stopifnot(!is.null(vocabulary$source), nzchar(vocabulary$source),
                    length(vocabulary$terms) > 0L, all(nzchar(vocabulary$terms)))
        }
      }
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
