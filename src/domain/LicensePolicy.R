LicensePolicy <- R6::R6Class("LicensePolicy",
  public = list(
    initialize = function(osi) {
      private$approved <- vapply(osi$licenses, `[[`, "", "id")
      private$exceptions <- unlist(osi$exceptions, use.names = FALSE)
    },
    accepts = function(expression) {
      if (is.null(expression) || !length(expression)) return(FALSE)
      expression <- paste(unlist(expression), collapse = " AND ")
      if (!nzchar(expression)) return(FALSE)
      tryCatch(private$check(expression), error = function(e) FALSE)
    },
    canonical = function(id) {
      spaced <- gsub("([()])", " \\1 ", id, perl = TRUE)
      tokens <- strsplit(trimws(spaced), "\\s+", perl = TRUE)[[1L]]
      index <- match(tolower(tokens), tolower(private$approved))
      tokens[!is.na(index)] <- private$approved[index[!is.na(index)]]
      paste(tokens, collapse = " ")
    }
  ),
  private = list(
    approved = NULL, exceptions = NULL, tokens = NULL, position = 1L,
    check = function(expression) {
      expression <- gsub("([()])", " \\1 ", expression, perl = TRUE)
      private$tokens <- strsplit(trimws(expression), "\\s+", perl = TRUE)[[1L]]
      private$position <- 1L
      approved <- private$expression()
      approved && private$position > length(private$tokens)
    },
    peek = function() {
      if (private$position > length(private$tokens)) return("")
      private$tokens[[private$position]]
    },
    take = function() {
      token <- private$peek()
      private$position <- private$position + 1L
      token
    },
    expression = function() {
      approved <- private$atom()
      while (private$peek() %in% c("AND", "OR")) {
        private$take()
        next_approved <- private$atom()
        approved <- approved && next_approved
      }
      approved
    },
    atom = function() {
      token <- private$take()
      if (token == "(") {
        approved <- private$expression()
        if (private$take() != ")") stop("Parênteses inválidos")
        return(approved)
      }
      approved <- token %in% private$approved
      if (private$peek() == "WITH") {
        private$take()
        approved <- private$take() %in% private$exceptions && approved
      }
      approved
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
