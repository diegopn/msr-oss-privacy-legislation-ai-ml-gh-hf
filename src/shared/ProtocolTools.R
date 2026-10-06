ProtocolTools <- R6::R6Class("ProtocolTools",
  public = list(
    scalar = function(x, fallback = "") {
      if (is.null(x) || !length(x) || is.na(x[[1L]])) return(fallback)
      x[[1L]]
    },
    text = function(x) paste(as.character(unlist(x, use.names = FALSE)), collapse = "\n"),
    key = function(platform, type, id) paste(platform, type, id, sep = ":"),
    json = function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null",
                                                  na = "null", digits = NA)),
    decode = function(x) jsonlite::fromJSON(x, simplifyVector = FALSE),
    escape = function(x) {
      chars <- strsplit(x, "", fixed = TRUE)[[1L]]
      meta <- c("\\", ".", "^", "$", "|", "(", ")", "[", "]", "{", "}", "*", "+", "?")
      paste(ifelse(chars %in% meta, paste0("\\", chars), chars), collapse = "")
    },
    pattern = function(term, literal = FALSE) {
      escaped <- self$escape(term)
      if (literal) return(escaped)
      paste0("(?<![[:alnum:]_])", escaped, "(?![[:alnum:]_])")
    },
    matches = function(text, terms, literal = FALSE) {
      terms[vapply(terms, function(term) grepl(self$pattern(term, literal), text,
                                             ignore.case = TRUE, perl = TRUE), logical(1))]
    },
    signals = function(text, terms, source, label, version) {
      lapply(self$matches(text, terms), function(term) {
        offset <- regexpr(self$pattern(term), text, ignore.case = TRUE, perl = TRUE)[[1L]]
        list(kind = "ai", label = label, term = term, source = source, offset = offset,
          excerpt = substr(text, max(1L, offset - 100L), offset + nchar(term) + 100L),
          vocabulary = "ai_protocol", rule_version = version)
      })
    },
    now = function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    hash = function(x) digest::digest(x, algo = "sha256", serialize = FALSE)
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
