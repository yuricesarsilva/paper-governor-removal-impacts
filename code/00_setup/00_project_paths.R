# Central project paths used across scripts.

root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)

path_data_raw <- file.path(root_dir, "data", "raw")
path_data_raw_ibge <- file.path(path_data_raw, "ibge")
path_data_raw_bcb <- file.path(path_data_raw, "bcb")
path_data_raw_mte <- file.path(path_data_raw, "mte")
path_data_raw_siconfi <- file.path(path_data_raw, "siconfi")
path_data_external <- file.path(root_dir, "data", "external")
path_data_processed <- file.path(root_dir, "data", "processed")
path_code <- file.path(root_dir, "code")
path_output <- file.path(root_dir, "output")
path_notes <- file.path(root_dir, "notes")
