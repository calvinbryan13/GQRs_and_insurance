# ==============================================================================
# 001_01_extract_weather_cropland_5yr_march.R
#
# Purpose:
#   Create a county-year AGRICULTURAL-LAND weather panel for 2000-2020:
#     1. Mean annual maximum temperature
#     2. Mean annual PDSI
#     3. Total annual precipitation
#     4. Trailing 5-year means of each of the three annual measures
#     5. PDSI from the final observation dated in March of each year
#        (also records the actual March observation date)
#
# Added panel columns: maxtemp_5yr_avg, pdsi_5yr_avg, precip_5yr_avg,
#                      pdsi_march_final, pdsi_march_date.
#
# A 5-year mean for year Y uses Y-4, ..., Y (inclusive). It is NA if
# any of those five annual values are missing. Thus 2000-2003 have
# NA 5-year averages with the current 2000-2020 input period.
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
# Spatial extraction uses each county's intersection with cropland_area.shp,
# not the full county. The intersection is calculated once and reused for all
# years and weather variables. exact_extract(..., "mean") weights cells by the
# fraction of each weather-grid cell covered by the county's cropland mask,
# consistent with the original script.
#
# Counties with no mapped cropland remain in the panel with NA weather values.
# This static cropland mask is applied to every year (2000-2020).
# The last-March PDSI is taken from the latest PDSI layer whose timestamp
# falls in March, NOT from a calendar-month mean or March 31 interpolation.
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

county_file   <- "data/map data/Counties/cb_2017_us_county_500k.shp"
cropland_file <- "data/map data/cropland_area_usgs.shp"

# Use distinct outputs so the original full-county weather panel is preserved.
output_file   <- "data/processed data/paneled_weather_cropland_2000_2020.csv"
coverage_file <- "data/processed data/county_cropland_coverage.csv"

years <- 2000:2020


# ------------------------------------------------------------------------------
# 3. Create county-specific cropland extraction polygons
# ------------------------------------------------------------------------------

# The cropland shapefile is assumed to contain polygons representing ag-land.
# If it includes non-agricultural classes, filter those out BEFORE intersecting.
if (!file.exists(county_file)) {
  stop("County shapefile not found: ", county_file)
}
if (!file.exists(cropland_file)) {
  stop("Cropland shapefile not found: ", cropland_file)
}

message("Reading county and cropland boundaries...")

counties <- st_read(county_file, quiet = TRUE) %>%
  select(GEOID)

# Preserve leading zeroes in county FIPS codes.
counties$GEOID <- as.character(counties$GEOID)

if (anyNA(counties$GEOID) || anyDuplicated(counties$GEOID)) {
  stop("County GEOID values must be nonmissing and unique.")
}

# Only the geometries are needed from the cropland layer.
cropland_source <- st_read(cropland_file, quiet = TRUE)

if (nrow(cropland_source) == 0L) {
  stop("The cropland shapefile contains no features.")
}
if (is.na(st_crs(counties)) || is.na(st_crs(cropland_source))) {
  stop("Both shapefiles need a defined CRS. Do not assign an unverified CRS.")
}

# Use a projected equal-area CRS for the intersection and coverage diagnostics.
# EPSG:6933 is global, avoiding a CONUS-only projection for US counties.
overlay_crs <- 6933

counties_overlay <- counties %>%
  st_transform(overlay_crs) %>%
  st_make_valid() %>%
  st_collection_extract("POLYGON", warn = FALSE)

cropland_overlay <- st_sf(geometry = st_geometry(cropland_source)) %>%
  st_transform(overlay_crs) %>%
  st_make_valid() %>%
  st_collection_extract("POLYGON", warn = FALSE)

rm(cropland_source)

counties_overlay <- counties_overlay[
  !st_is_empty(counties_overlay), , drop = FALSE
]
cropland_overlay <- cropland_overlay[
  !st_is_empty(cropland_overlay), , drop = FALSE
]

if (nrow(cropland_overlay) == 0L) {
  stop("No polygon geometries remain in the cropland shapefile.")
}

message("Intersecting counties with cropland (this is done once)...")

# This may be slow for a very detailed cropland shapefile. Every cropland
# polygon is clipped to its county, and overlapping/adjacent pieces are
# dissolved by GEOID to prevent duplicate coverage in raster extraction.
county_cropland_parts <- suppressWarnings(
  st_intersection(counties_overlay, cropland_overlay)
)
county_cropland_parts <- st_collection_extract(
  county_cropland_parts, "POLYGON", warn = FALSE
)
county_cropland_parts <- county_cropland_parts[
  !st_is_empty(county_cropland_parts), , drop = FALSE
]

if (nrow(county_cropland_parts) == 0L) {
  stop("The county and cropland shapefiles have no polygonal overlap. Check their locations and CRSs.")
}

county_cropland <- county_cropland_parts %>%
  group_by(GEOID) %>%
  summarise(.groups = "drop") %>%
  st_make_valid() %>%
  st_collection_extract("POLYGON", warn = FALSE)

county_cropland <- county_cropland[
  !st_is_empty(county_cropland), , drop = FALSE
]

rm(county_cropland_parts, cropland_overlay)

if (anyDuplicated(county_cropland$GEOID)) {
  stop("The cropland mask must contain no more than one geometry per county.")
}

# Diagnostic: cropland-covered area and share for every original county.
# Counties with no intersecting cropland have zero covered area.
county_coverage <- data.frame(
  GEOID = counties_overlay$GEOID,
  county_area_km2 = as.numeric(st_area(counties_overlay)) / 1e6
) %>%
  left_join(
    data.frame(
      GEOID = county_cropland$GEOID,
      cropland_area_km2 = as.numeric(st_area(county_cropland)) / 1e6
    ),
    by = "GEOID"
  ) %>%
  mutate(
    cropland_area_km2 = replace_na(cropland_area_km2, 0),
    cropland_share = if_else(
      county_area_km2 > 0,
      cropland_area_km2 / county_area_km2,
      NA_real_
    )
  ) %>%
  rename(fips = GEOID)

message("Counties in original boundaries: ", nrow(counties))
message("Counties with intersecting cropland: ", nrow(county_cropland))
message("Counties without mapped cropland: ",
        nrow(counties) - nrow(county_cropland))

# ------------------------------------------------------------------------------
# 4. Helper functions
# ------------------------------------------------------------------------------

# Extract a coverage-fraction-weighted cropland mean for every raster layer.
# The original county list defines the row order. Counties without cropland
# are explicitly filled with NA, so the output keeps the same panel universe.
#
# Output: one row per original county and one column per raster layer.
extract_county_timeseries <- function(r, cropland_counties_sf, all_counties_sf) {

  # The intersection polygons were built in EPSG:6933; transform to the
  # native CRS of the weather raster before exact extraction.
  crop_in_raster_crs <- st_transform(cropland_counties_sf, crs(r))

  # As in the original script, "mean" weights each raster cell by its
  # fraction of overlap with the agricultural-land portion of the county.
  extracted <- exact_extract(
    r,
    crop_in_raster_crs,
    fun = "mean",
    progress = FALSE
  )

  # Works for either a single raster layer (vector) or many (data frame).
  extracted_matrix <- as.matrix(extracted)
  if (nrow(extracted_matrix) != nrow(crop_in_raster_crs) ||
      ncol(extracted_matrix) != nlyr(r)) {
    stop("Unexpected extraction dimensions; check the raster and mask.")
  }

  # Explicitly retain counties lacking cropland, with missing values.
  county_values <- matrix(
    NA_real_, nrow = nrow(all_counties_sf), ncol = nlyr(r)
  )
  county_index <- match(
    crop_in_raster_crs$GEOID, all_counties_sf$GEOID
  )
  if (anyNA(county_index)) {
    stop("Cropland mask contains a GEOID not found in original counties.")
  }

  county_values[county_index, ] <- extracted_matrix
  colnames(county_values) <- paste0("layer_", seq_len(nlyr(r)))

  data.frame(
    GEOID = as.character(all_counties_sf$GEOID),
    county_values,
    check.names = FALSE
  )
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
    cropland_counties_sf = county_cropland,
    all_counties_sf = counties
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
    cropland_counties_sf = county_cropland,
    all_counties_sf = counties
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


# Extract cropland-only county means for every PDSI time step.
pdsi_county_wide <- extract_county_timeseries(
  r = pdsi_r,
  cropland_counties_sf = county_cropland,
  all_counties_sf = counties
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
# Every PDSI observation receives equal temporal weight, as in the original.
pdsi_annual <- pdsi_long %>%
  filter(year %in% years) %>%
  group_by(GEOID, year) %>%
  summarise(
    pdsi = if (all(is.na(PDSI))) NA_real_ else mean(PDSI, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  rename(fips = GEOID)


# Final March PDSI:
# For each year, choose the LAST PDSI raster observation with a timestamp
# in March. This works whether PDSI is daily, 5-day, or monthly; for a 5-day
# series the chosen date will usually be earlier than March 31.
# If the NetCDF has no March observation in a year, the panel gets NA.
pdsi_layer_lookup <- tibble(
  layer_id = seq_along(pdsi_dates),
  date = pdsi_dates,
  year = year(pdsi_dates)
)

pdsi_march_last_layers <- pdsi_layer_lookup %>%
  filter(month(date) == 3) %>%
  arrange(year, date, layer_id) %>%
  group_by(year) %>%
  slice_tail(n = 1) %>%
  ungroup()

missing_march_years <- setdiff(years, pdsi_march_last_layers$year)
if (length(missing_march_years) > 0L) {
  warning(
    "No PDSI observation dated in March for year(s): ",
    paste(missing_march_years, collapse = ", "),
    ". pdsi_march_final will be NA for those years."
  )
}

message("Final March PDSI observations (date used each year):")
print(pdsi_march_last_layers %>% select(year, date))

pdsi_march_annual <- pdsi_long %>%
  inner_join(
    pdsi_march_last_layers %>% select(year, layer_id, date),
    by = c("year", "layer_id", "date")
  ) %>%
  transmute(
    fips = as.character(GEOID),
    year,
    pdsi_march_final = PDSI,
    pdsi_march_date = date
  )


# ------------------------------------------------------------------------------
# 8. Merge cropland weather variables into one county-year panel
# ------------------------------------------------------------------------------

message("Merging county-year weather data...")

weather_panel <- maxtemp_annual %>%
  full_join(pdsi_annual, by = c("fips", "year")) %>%
  full_join(precip_annual, by = c("fips", "year")) %>%
  left_join(pdsi_march_annual, by = c("fips", "year")) %>%
  arrange(fips, year)


# ------------------------------------------------------------------------------
# 9. Trailing 5-year means of the annual cropland weather measures
# ------------------------------------------------------------------------------

# Uses the current year and preceding four calendar years (e.g., the
# 2010 value averages 2006-2010). No partial windows are calculated.
# stats::filter propagates NA when even one year in the window is missing.
# These are averages of ANNUAL values: the precipitation version is the
# average annual precipitation total across five years, not a five-year sum.
rolling_five_year_mean <- function(x) {
  as.numeric(stats::filter(x, filter = rep(1 / 5, 5), sides = 1))
}

message("Calculating trailing 5-year weather averages...")

weather_panel <- weather_panel %>%
  group_by(fips) %>%
  arrange(year, .by_group = TRUE) %>%
  mutate(
    maxtemp_5yr_avg = rolling_five_year_mean(maxtemp),
    pdsi_5yr_avg    = rolling_five_year_mean(pdsi),
    precip_5yr_avg  = rolling_five_year_mean(precip)
  ) %>%
  ungroup() %>%
  select(
    fips, year, maxtemp, pdsi, precip,
    maxtemp_5yr_avg, pdsi_5yr_avg, precip_5yr_avg,
    pdsi_march_final, pdsi_march_date
  ) %>%
  arrange(fips, year)


# ------------------------------------------------------------------------------
# 10. Basic checks
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

# Same one-row-per-county-per-year structure as the original script.
stopifnot(
  nrow(weather_panel) == nrow(counties) * length(years),
  !anyDuplicated(weather_panel[c("fips", "year")]),
  all(names(weather_panel) == c(
    "fips", "year", "maxtemp", "pdsi", "precip",
    "maxtemp_5yr_avg", "pdsi_5yr_avg", "precip_5yr_avg",
    "pdsi_march_final", "pdsi_march_date"
  )),
  all(weather_panel$year %in% years),
  all(is.na(weather_panel$maxtemp_5yr_avg[weather_panel$year < min(years) + 4L])),
  all(is.na(weather_panel$pdsi_5yr_avg[weather_panel$year < min(years) + 4L])),
  all(is.na(weather_panel$precip_5yr_avg[weather_panel$year < min(years) + 4L])),
  all(is.na(weather_panel$pdsi_march_date) |
      month(weather_panel$pdsi_march_date) == 3L)
)

message("Missing values:")
print(
  weather_panel %>%
    summarise(
      across(
        c(maxtemp, pdsi, precip,
          maxtemp_5yr_avg, pdsi_5yr_avg, precip_5yr_avg,
          pdsi_march_final),
        ~ sum(is.na(.x)),
        .names = "missing_{.col}"
      )
    )
)


# ------------------------------------------------------------------------------
# 11. Export CSV
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

write.csv(
  county_coverage,
  coverage_file,
  row.names = FALSE
)

message("Done.")
message("Weather panel saved to: ", output_file)
message("County cropland coverage saved to: ", coverage_file)
