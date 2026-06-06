required_packages <- c(
  "sidrar",
  "readr",
  "dplyr",
  "lubridate",
  "stringr",
  "janitor",
  "purrr",
  "tibble",
  "archive",
  "readxl"
)

missing_packages <- required_packages[!vapply(
  required_packages,
  requireNamespace,
  logical(1),
  quietly = TRUE
)]

if (length(missing_packages) > 0) {
  stop(
    "Missing required packages: ",
    paste(missing_packages, collapse = ", "),
    ". Install them before running the download scripts."
  )
}

invisible(lapply(required_packages, library, character.only = TRUE))
