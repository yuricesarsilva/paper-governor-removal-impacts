# Central project paths used across scripts.

root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)

path_data_raw <- file.path(root_dir, "data", "raw")
path_data_raw_ibge <- file.path(path_data_raw, "ibge")
path_data_raw_bcb <- file.path(path_data_raw, "bcb")
path_data_raw_mte <- file.path(path_data_raw, "mte")
path_data_raw_siconfi <- file.path(path_data_raw, "siconfi")
path_data_raw_confaz <- file.path(path_data_raw, "confaz")
path_data_raw_tesouro <- file.path(path_data_raw, "tesouro")
path_data_external <- file.path(root_dir, "data", "external")
path_data_processed <- file.path(root_dir, "data", "processed")
path_code <- file.path(root_dir, "code")
path_output <- file.path(root_dir, "output")
# Data-pipeline artifacts (validation tables, data-diagnostic figures) live under
# output/_data_pipeline/ so they do not mix with the per-event analysis results
# in output/<event_id>/.
path_output_data_pipeline <- file.path(path_output, "_data_pipeline")
path_output_validation <- file.path(path_output_data_pipeline, "validation")
path_output_figures <- file.path(path_output_data_pipeline, "figures")
path_notes <- file.path(root_dir, "notes")
