source(file.path("code", "00_setup", "00_project_paths.R"))

events_path <- file.path(path_data_raw, "governor_removal_events.csv")
panel_path <- file.path(path_data_processed, "state_year_panel_template.csv")
dictionary_path <- file.path(path_data_processed, "data_dictionary.csv")

events <- read.csv(events_path, stringsAsFactors = FALSE)
panel <- read.csv(panel_path, stringsAsFactors = FALSE)
dictionary <- read.csv(dictionary_path, stringsAsFactors = FALSE)

required_event_columns <- c(
  "event_id", "state_abbrev", "state_name", "governor_name",
  "legal_term_end_date", "removal_date", "event_type", "sample_class"
)

required_panel_columns <- c(
  "state_abbrev", "state_name", "year", "treated_case",
  "post_treatment", "treatment_year", "event_id"
)

missing_event_columns <- setdiff(required_event_columns, names(events))
missing_panel_columns <- setdiff(required_panel_columns, names(panel))

if (length(missing_event_columns) > 0) {
  stop(
    "Missing columns in governor_removal_events.csv: ",
    paste(missing_event_columns, collapse = ", ")
  )
}

if (length(missing_panel_columns) > 0) {
  stop(
    "Missing columns in state_year_panel_template.csv: ",
    paste(missing_panel_columns, collapse = ", ")
  )
}

if (anyDuplicated(events$event_id) > 0) {
  stop("Duplicated event_id values found in governor_removal_events.csv")
}

if (!all(c("variable_name", "level", "description") %in% names(dictionary))) {
  stop("The data dictionary is missing required metadata columns")
}

message("Input files found and basic structure validated.")
