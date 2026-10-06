StageAnalysis <- R6::R6Class("StageAnalysis",
  public = list(
    initialize = function(config, units) {
      private$config <- config
      private$units <- units[!duplicated(units$unit_key), , drop = FALSE]
    },
    run = function(independent, consensus) {
      independent$platform <- private$units$platform[match(independent$unit_key, private$units$unit_key)]
      consensus$platform <- private$units$platform[match(consensus$unit_key, private$units$unit_key)]
      coverage <- list(selected_units = nrow(private$units), independent_expected = 2L * nrow(private$units),
        independent_complete = sum(independent$stage_status != "pending"),
        consensus_complete = sum(consensus$stage_status != "pending"))
      status <- private$status(coverage)
      stages <- private$frequencies(consensus)
      list(status = status, codebook_version = private$config$stages$version,
        codebook_hash = private$config$stage_fingerprint, coverage = coverage,
        tables = list(stages = stages, agreement = private$agreement(independent),
          stage_categories = private$categories(consensus), contrasts = private$contrasts(stages, status)))
    }
  ),
  private = list(
    config = NULL, units = NULL,
    status = function(coverage) {
      if (coverage$selected_units > 0L && coverage$independent_complete == coverage$independent_expected &&
          coverage$consensus_complete == coverage$selected_units) return("human_evaluation_complete")
      if (coverage$independent_complete + coverage$consensus_complete > 0L) return("human_evaluation_partial")
      "human_evaluation_pending"
    },
    ids = function(value) {
      if (is.na(value) || !nzchar(value)) return(character())
      trimws(strsplit(value, ";", fixed = TRUE)[[1L]])
    },
    binary = function(rows, stage) {
      rows <- rows[rows$stage_status == "identified" & rows$relevance == "1", , drop = FALSE]
      rows$codebook_version <- rows$stage_codebook_version
      rows$relevance <- vapply(rows$stages, function(value) if (stage %in% private$ids(value)) "1" else "0", "")
      rows
    },
    agreement = function(rows) {
      output <- list()
      for (platform in c("all", "github", "huggingface")) {
        answers <- if (platform == "all") rows else rows[rows$platform == platform, , drop = FALSE]
        selected <- if (platform == "all") nrow(private$units) else sum(private$units$platform == platform)
        for (stage in private$config$stages$stages) {
          result <- KappaCalculator$new()$compute(private$binary(answers, stage$id), private$config$settings$sampling$reviewers)
          output[[length(output) + 1L]] <- data.frame(stage_id = stage$id, platform = platform,
            pairs = result$pairs, selected_units = selected,
            n_indeterminate_ratings = sum(answers$stage_status == "indeterminate"),
            n_pending_ratings = 2L * selected - sum(answers$stage_status != "pending"),
            observed = if (is.null(result$observed)) NA_real_ else result$observed,
            expected = if (is.null(result$expected)) NA_real_ else result$expected,
            kappa = result$kappa, reason = result$reason)
        }
      }
      do.call(rbind, output)
    },
    frequencies = function(rows) {
      output <- list()
      for (platform in c("github", "huggingface")) {
        answers <- rows[rows$platform == platform, , drop = FALSE]
        relevant <- answers$relevance == "1"
        annotated <- relevant & answers$stage_status %in% c("identified", "indeterminate")
        denominator <- sum(annotated)
        for (stage in private$config$stages$stages) {
          positive <- answers$stage_status == "identified" &
            vapply(answers$stages, function(value) stage$id %in% private$ids(value), logical(1))
          count <- sum(relevant & positive)
          output[[length(output) + 1L]] <- data.frame(stage_id = stage$id, label = stage$label, platform = platform,
            n_sample = sum(private$units$platform == platform), n_relevant = sum(relevant),
            n_relevant_annotated = denominator, n_stage = count,
            n_indeterminate = sum(annotated & answers$stage_status == "indeterminate"),
            n_stage_pending = sum(relevant & !annotated),
            n_relevance_pending = sum(private$units$platform == platform) - sum(answers$relevance %in% c("0", "1")),
            n_not_relevant = sum(answers$relevance == "0"), denominator = denominator,
            proportion = if (denominator) count / denominator else NA_real_,
            n_projects_selected = length(unique(private$units$repo_key[private$units$platform == platform])),
            n_projects_annotated = length(unique(answers$repo_key[annotated])))
        }
      }
      do.call(rbind, output)
    },
    categories = function(rows) {
      output <- list()
      for (i in which(rows$stage_status == "identified" & rows$relevance == "1")) {
        for (stage in private$ids(rows$stages[i])) {
          for (category in private$ids(rows$categories[i])) {
            output[[length(output) + 1L]] <- data.frame(unit_key = rows$unit_key[i], repo_key = rows$repo_key[i],
              platform = rows$platform[i], url = rows$url[i], stage_id = stage, category_id = category)
          }
        }
      }
      if (length(output)) return(do.call(rbind, output))
      as.data.frame(setNames(rep(list(character()), 6L), c("unit_key", "repo_key", "platform", "url", "stage_id", "category_id")))
    },
    contrasts = function(stages, status) {
      output <- list()
      for (stage in private$config$stages$stages) {
        gh <- stages[stages$stage_id == stage$id & stages$platform == "github", ]
        hf <- stages[stages$stage_id == stage$id & stages$platform == "huggingface", ]
        reason <- if (status != "human_evaluation_complete") "human_annotation_pending" else
          if (gh$denominator == 0L || hf$denominator == 0L) "no_relevant_discussions" else
            "project_comparability_and_cluster_design_pending"
        output[[length(output) + 1L]] <- data.frame(stage_id = stage$id,
          h0 = "A proporção de discussões relevantes associadas à etapa é igual nos dois hubs.",
          h1 = "A proporção de discussões relevantes associadas à etapa difere entre os hubs.",
          github_denominator = gh$denominator, huggingface_denominator = hf$denominator,
          descriptive_difference = gh$proportion - hf$proportion,
          confidence_low = NA_real_, confidence_high = NA_real_, p_value = NA_real_, p_holm = NA_real_,
          test_family_size = length(private$config$stages$stages), adjustment = "Holm",
          status = "not_testable", reason = reason)
      }
      do.call(rbind, output)
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
