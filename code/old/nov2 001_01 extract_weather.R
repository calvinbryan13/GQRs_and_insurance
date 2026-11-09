# ==============================================================================
# 001_01 extract_weather_revised.R
#
# Purpose:
#   Create a county-year weather panel for 2000-2020 containing:
#     1. Mean annual maximum temperature
#     2. Mean annual PDSI
#     3. Total annual precipitation
#
# Raw weather data are stored in:
#   data/raw_data/maxtemp/
#   data/raw_data/pdsi/
#   data/raw_data/precip/
#
# Expected files:
#   maxtemp/tmmx_YYYY.nc
#   precip/pr_YYYY.nc
#   pdsi/           one NetCDF file containing the full PDSI time series
#
# County averages are area-weighted using exactextractr::exact_extract().
# ==============================================================================


# ------------------------------------------------------------------------------
# 1. Clear environment and load packages
# ------------------------------------------------------------------------------

rm(list = ls())

library(sf)
library(terra)
library(exactextractr)
library(dplyr)
library(tidyr)
library(purrr)
library(lubridate)
library(ncdf4)


# ------------------------------------------------------------------------------
# 2. File paths and settings
# ------------------------------------------------------------------------------

# Assumes the script is run from the project root.
# If needed, uncomment and update:
setwd("C:/Users/cbryan/Box/Cal's Personal Laptop Files/git_projects/GQRs_and_insurance/")

cde_path <- "C:/Users/cbryan/Box/Cal's Personal Laptop Files/git_projects/causal_drop_effectiveness/data/raw_data"

maxtemp_path <- file.path(cde_path, "maxtemp")
pdsi_path    <- file.path(cde_path, "pdsi")
precip_path  <- file.path(cde_path, "precip")

county_file <- "data/map data/Counties/cb_2017_us_county_500k.shp"

output_file <- "data/processed data/paneled_weather_2000_2020.csv"

years <- 2000:2020


# ------------------------------------------------------------------------------
# 3. Read county boundaries
# ------------------------------------------------------------------------------

counties <- st_read(county_file, quiet = TRUE) %>%
  select(GEOID, geometry)

# Preserve leading zeroes in county FIPS codes
counties$GEOID <- as.character(counties$GEOID)


# ------------------------------------------------------------------------------
# 4. Helper functions
# ------------------------------------------------------------------------------

# This function extracts an area-weighted county mean from every raster layer.
#
# Output:
#   One row per county
#   One column per raster layer/time step
#
extract_county_timeseries <- function(r, counties_sf) {

  # Transform counties to raster CRS
  counties_temp <- st_transform(counties_sf, crs(r))

  # exact_extract(..., "mean") uses cell coverage fractions, so cells that
  # only partially overlap a county receive proportionally less weight.
  extracted <- exact_extract(
    r,
    counties_temp,
    fun = "mean",
    progress = FALSE
  )

  extracted <- as.data.frame(extracted)

  # exact_extract may return a vector when the raster has only one layer.
  if (ncol(extracted) == 0) {
    extracted <- data.frame(value = extracted)
  }

  extracted <- cbind(
    GEOID = counties_temp$GEOID,
    extracted
  )

  return(extracted)
}


# Convert wide exact_extract output to one value per county and year.
#
# statistic = "mean":
#   mean across all time steps during the year
#
# statistic = "sum":
#   sum across all time steps during the year
#
collapse_one_year <- function(extracted_df, year, statistic = c("mean", "sum")) {

  statistic <- match.arg(statistic)

  value_matrix <- as.matrix(extracted_df[, -1, drop = FALSE])
  storage.mode(value_matrix) <- "numeric"

  if (statistic == "mean") {
    annual_value <- rowMeans(value_matrix, na.rm = TRUE)
  }

  if (statistic == "sum") {
    annual_value <- rowSums(value_matrix, na.rm = TRUE)
  }

  # Avoid turning rows containing only missing values into NaN or 0
  all_missing <- apply(value_matrix, 1, function(x) all(is.na(x)))
  annual_value[all_missing] <- NA_real_

  data.frame(
    fips = as.character(extracted_df$GEOID),
    year = year,
    value = annual_value
  )
}


# Get dates associated with a multi-layer NetCDF raster.
#
# First tries terra's native time metadata. If that is not available,
# it reads the NetCDF time coordinate directly with ncdf4.
get_netcdf_dates <- function(nc_file, r) {

  # ---- First choice: dates already recognized by terra ----
  raster_dates <- tryCatch(
    as.Date(time(r)),
    error = function(e) NULL
  )

  if (!is.null(raster_dates) &&
      length(raster_dates) == nlyr(r) &&
      !all(is.na(raster_dates))) {
    return(raster_dates)
  }


  # ---- Fallback: inspect NetCDF time coordinate ----
  nc <- nc_open(nc_file)
  on.exit(nc_close(nc), add = TRUE)

  candidate_time_vars <- c("time", "day", "days")

  time_var <- candidate_time_vars[
    candidate_time_vars %in% c(names(nc$dim), names(nc$var))
  ][1]

  if (is.na(time_var)) {
    stop(
      paste0(
        "Could not identify a time variable in: ",
        nc_file,
        ". Check the NetCDF metadata."
      )
    )
  }

  # Time can be represented as a dimension or variable
  if (time_var %in% names(nc$dim)) {
    time_vals <- nc$dim[[time_var]]$vals
    time_units <- nc$dim[[time_var]]$units
  } else {
    time_vals <- ncvar_get(nc, time_var)
    time_units <- ncatt_get(nc, time_var, "units")$value
  }

  if (is.null(time_units) || is.na(time_units)) {
    stop(
      paste0(
        "Time units were not found in: ",
        nc_file,
        ". Check the NetCDF metadata."
      )
    )
  }


  # Parse common NetCDF date formats such as:
  # "days since 1900-01-01"
  # "hours since 1900-01-01 00:00:00"

  origin_string <- sub(
    "^.*since[[:space:]]+",
    "",
    time_units,
    ignore.case = TRUE
  )

  origin_string <- substr(origin_string, 1, 10)
  origin_date <- as.Date(origin_string)

  if (is.na(origin_date)) {
    stop(
      paste0(
        "Could not parse the NetCDF time origin from units: ",
        time_units
      )
    )
  }

  if (grepl("^days", time_units, ignore.case = TRUE)) {
    dates <- origin_date + time_vals
  } else if (grepl("^hours", time_units, ignore.case = TRUE)) {
    dates <- origin_date + time_vals / 24
  } else {
    stop(
      paste0(
        "Unsupported NetCDF time units: ",
        time_units
      )
    )
  }

  dates <- as.Date(dates)

  if (length(dates) != nlyr(r)) {
    stop(
      paste0(
        "Number of NetCDF dates (", length(dates),
        ") does not match number of raster layers (", nlyr(r),
        ") in ", nc_file
      )
    )
  }

  return(dates)
}


# ------------------------------------------------------------------------------
# 5. Maximum temperature
# ------------------------------------------------------------------------------

message("Extracting maximum temperature...")

maxtemp_list <- map(years, function(yr) {

  nc_file <- file.path(
    maxtemp_path,
    paste0("tmmx_", yr, ".nc")
  )

  if (!file.exists(nc_file)) {
    stop(paste("Missing maximum-temperature file:", nc_file))
  }

  message("  Maximum temperature: ", yr)

  r <- rast(nc_file)

  county_values <- extract_county_timeseries(
    r = r,
    counties_sf = counties
  )

  annual <- collapse_one_year(
    extracted_df = county_values,
    year = yr,
    statistic = "mean"
  )

  names(annual)[names(annual) == "value"] <- "maxtemp"

  return(annual)
})

maxtemp_annual <- bind_rows(maxtemp_list)


# ------------------------------------------------------------------------------
# 6. Precipitation
# ------------------------------------------------------------------------------

message("Extracting precipitation...")

precip_list <- map(years, function(yr) {

  nc_file <- file.path(
    precip_path,
    paste0("pr_", yr, ".nc")
  )

  if (!file.exists(nc_file)) {
    stop(paste("Missing precipitation file:", nc_file))
  }

  message("  Precipitation: ", yr)

  r <- rast(nc_file)

  county_values <- extract_county_timeseries(
    r = r,
    counties_sf = counties
  )

  annual <- collapse_one_year(
    extracted_df = county_values,
    year = yr,
    statistic = "sum"
  )

  names(annual)[names(annual) == "value"] <- "precip"

  return(annual)
})

precip_annual <- bind_rows(precip_list)


# ------------------------------------------------------------------------------
# 7. PDSI
# ------------------------------------------------------------------------------

message("Extracting PDSI...")

# Find NetCDF files in the PDSI directory.
pdsi_files <- list.files(
  pdsi_path,
  pattern = "\\.nc$",
  full.names = TRUE
)

if (length(pdsi_files) != 1) {
  stop(
    paste0(
      "Expected exactly one PDSI NetCDF file in ",
      pdsi_path,
      ", but found ",
      length(pdsi_files),
      "."
    )
  )
}

pdsi_file <- pdsi_files[1]

pdsi_r <- rast(pdsi_file)

# Retrieve the date represented by each PDSI raster layer.
pdsi_dates <- get_netcdf_dates(
  nc_file = pdsi_file,
  r = pdsi_r
)

# Keep only 2000-2020.
keep_layers <- which(year(pdsi_dates) %in% years)

if (length(keep_layers) == 0) {
  stop("No PDSI raster layers were found for 2000-2020.")
}

pdsi_r <- pdsi_r[[keep_layers]]
pdsi_dates <- pdsi_dates[keep_layers]


# Extract county mean for every PDSI time step.
pdsi_county_wide <- extract_county_timeseries(
  r = pdsi_r,
  counties_sf = counties
)


# Convert to long format so dates can be attached to individual layers.
pdsi_value_cols <- names(pdsi_county_wide)[-1]

pdsi_long <- pdsi_county_wide %>%
  pivot_longer(
    cols = all_of(pdsi_value_cols),
    names_to = "layer",
    values_to = "PDSI"
  ) %>%
  mutate(
    layer_id = match(layer, pdsi_value_cols),
    date = pdsi_dates[layer_id],
    year = year(date)
  )


# Annual mean PDSI:
# Every 5-day PDSI observation receives equal temporal weight.
pdsi_annual <- pdsi_long %>%
  filter(year %in% years) %>%
  group_by(GEOID, year) %>%
  summarise(
    pdsi = if (all(is.na(PDSI))) NA_real_ else mean(PDSI, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  rename(fips = GEOID)


# ------------------------------------------------------------------------------
# 8. Merge weather variables into one county-year panel
# ------------------------------------------------------------------------------

message("Merging county-year weather data...")

weather_panel <- maxtemp_annual %>%
  full_join(pdsi_annual, by = c("fips", "year")) %>%
  full_join(precip_annual, by = c("fips", "year")) %>%
  arrange(fips, year)


# ------------------------------------------------------------------------------
# 9. Basic checks
# ------------------------------------------------------------------------------

message("Running basic checks...")

print(head(weather_panel))
print(tail(weather_panel))

message("Years in output: ",
        min(weather_panel$year, na.rm = TRUE),
        " - ",
        max(weather_panel$year, na.rm = TRUE))

message("Number of counties: ",
        n_distinct(weather_panel$fips))

message("Number of county-year observations: ",
        nrow(weather_panel))

message("Missing values:")
print(
  weather_panel %>%
    summarise(
      missing_maxtemp = sum(is.na(maxtemp)),
      missing_pdsi    = sum(is.na(pdsi)),
      missing_precip  = sum(is.na(precip))
    )
)


# ------------------------------------------------------------------------------
# 10. Export CSV
# ------------------------------------------------------------------------------

dir.create(
  dirname(output_file),
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  weather_panel,
  output_file,
  row.names = FALSE
)

message("Done.")
message("Output saved to: ", output_file)
