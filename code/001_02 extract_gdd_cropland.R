# ==============================================================================
# 001_01B_extract_gdd_cropland.R
#
# Purpose:
#   Create county-year growing degree days (GDD) over agricultural land,
#   2000-2020, with a trailing 5-year average.
#
# Definition (the SAME for corn, soybean, and sorghum):
#   daily GDD in degrees Fahrenheit =
#       max(0, (daily Tmax_F + daily Tmin_F) / 2 - 50)
#   annual GDD = sum of daily GDD over January 1 - December 31.
#
# IMPORTANT: GDD is calculated at each WEATHER GRID CELL before spatial
# averaging. Daily values are first summed to an annual GDD raster, then the
# annual raster is area-weighted over each county's CROPLAND footprint with
# exactextractr. This avoids the error from clipping GDD at zero only after
# averaging county temperatures. No crop-specific upper temperature cap or
# growing-season restriction is applied.
#
# 5-year variable:
#   gdd_5yr_avg for year Y = average of annual gdd for Y-4,...,Y.
#   Missing if any of the 5 annual values are missing. With years 2000-2020,
#   gdd_5yr_avg is missing for 2000-2003.
#
# Input locations:
#   Tmax: external causal_drop_effectiveness/data/raw_data/maxtemp/tmmx_YYYY.nc
#   Tmin: THIS project's data/raw data/min_temp/tmmn_YYYY.nc
#   County boundaries: data/map data/Counties/cb_2017_us_county_500k.shp
#   Cropland:          data/map data/cropland_area_usgs.shp
#
# Output:
#   data/processed data/paneled_gdd_cropland_2000_2020.csv
#   Columns: fips, year, gdd, gdd_5yr_avg
#
# Input temperature unit metadata must be Kelvin, Celsius, or Fahrenheit.
# Values are converted to Fahrenheit before computing GDD. NetCDF dates are
# read directly from the time coordinate (not terra's sometimes ambiguous
# layer-time interpretation), checked and realigned where possible.
# A narrowly controlled sequential-layer fallback is available for files
# with full-length but slightly shifted calendar metadata; it warns loudly.
# ============================================================================

# ------------------------------------------------------------------------------
# 1. Packages
# ------------------------------------------------------------------------------

rm(list = ls())

library(sf)
library(terra)
library(exactextractr)
library(dplyr)
library(tidyr)
library(ncdf4)

# ------------------------------------------------------------------------------
# 2. File paths and settings
# ------------------------------------------------------------------------------

# Run from project root. Update this path if the project moves.
setwd("C:/Users/cbryan/Box/Cal's Personal Laptop Files/git_projects/GQRs_and_insurance/")

# Tmax is in the causal_drop_effectiveness project, as in 001_01.
cde_path <- "C:/Users/cbryan/Box/Cal's Personal Laptop Files/git_projects/causal_drop_effectiveness/data/raw_data"
maxtemp_path <- file.path(cde_path, "maxtemp")

# Tmin is stored in THIS project (note the space in 'raw data').
mintemp_path <- "data/raw data/min_temp"

county_file   <- "data/map data/Counties/cb_2017_us_county_500k.shp"
cropland_file <- "data/map data/cropland_area_usgs.shp"

output_file   <- "data/processed data/paneled_gdd_cropland_2000_2020.csv"
coverage_file <- "data/processed data/county_cropland_coverage_usgs.csv"

years <- 2000:2020
base_temp_f <- 50

# Date handling: true means that a file containing exactly 365/366 consecutive
# daily layers may be interpreted in Jan 1 ... Dec 31 order when its time
# metadata is missing or shifted by at most two days. A warning identifies
# every such use. Set FALSE if you prefer the script to stop instead.
allow_sequential_date_fallback <- TRUE
max_allowed_metadata_shift_days <- 2L

# Memory management: create one small temporary raster per month, rather than
# keeping a full year's daily derived GDD raster in memory. Temporary GeoTIFFs
# are deleted after extraction for each year.

# ------------------------------------------------------------------------------
# 3. Construct county-specific agricultural-land extraction polygons
# ------------------------------------------------------------------------------

for (p in c(county_file, cropland_file)) {
  if (!file.exists(p)) stop("Missing shapefile: ", p)
}

message("Reading county and USGS cropland shapefiles...")

counties <- st_read(county_file, quiet = TRUE) %>%
  select(GEOID)
counties$GEOID <- as.character(counties$GEOID)

if (anyNA(counties$GEOID) || anyDuplicated(counties$GEOID)) {
  stop("County GEOID codes must be nonmissing and unique.")
}

cropland_source <- st_read(cropland_file, quiet = TRUE)
if (nrow(cropland_source) == 0L) {
  stop("The cropland shapefile contains no features.")
}
if (is.na(st_crs(counties)) || is.na(st_crs(cropland_source))) {
  stop("Both shapefiles must have a defined coordinate reference system.")
}

# Equal-area projection for intersection and cropland-share diagnostics.
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
  stop("No usable polygons remain in the cropland shapefile.")
}

message("Intersecting counties with agricultural land (one-time operation)...")
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
  stop("No overlap between counties and cropland. Check CRS/geometry/data.")
}

# Dissolve all intersected cropland pieces by GEOID. Overlaps within the USGS
# cropland shapefile therefore do not receive duplicate extraction weight.
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
  stop("County cropland mask must have at most one geometry per GEOID.")
}

# Export useful area coverage diagnostics. Keep counties with zero crop area.
county_coverage <- data.frame(
  fips = counties_overlay$GEOID,
  county_area_km2 = as.numeric(st_area(counties_overlay)) / 1e6
) %>%
  left_join(
    data.frame(
      fips = county_cropland$GEOID,
      cropland_area_km2 = as.numeric(st_area(county_cropland)) / 1e6
    ),
    by = "fips"
  ) %>%
  mutate(
    cropland_area_km2 = replace_na(cropland_area_km2, 0),
    cropland_share = if_else(
      county_area_km2 > 0,
      cropland_area_km2 / county_area_km2,
      NA_real_
    )
  )

message("Counties in original shapefile: ", nrow(counties))
message("Counties with mapped cropland: ", nrow(county_cropland))
message("Counties with no mapped cropland: ",
        nrow(counties) - nrow(county_cropland))

# ------------------------------------------------------------------------------
# 4. Helper functions for NetCDF units and layer dates
# ------------------------------------------------------------------------------

# Identify units of the weather variable, rather than relying on the generic
# name of a NetCDF raster layer. GridMET tmmx/tmmn are typically Kelvin, but
# the script reads the actual metadata and refuses to silently assume units.
get_temperature_units <- function(nc_file) {
  nc <- nc_open(nc_file)
  on.exit(nc_close(nc), add = TRUE)

  var_names <- names(nc$var)
  grid_vars <- var_names[vapply(
    nc$var,
    function(v) length(v$dim) >= 3L,
    logical(1)
  )]
  if (length(grid_vars) != 1L) {
    stop("Expected one gridded temperature variable in: ", nc_file,
         "; found ", length(grid_vars), ".")
  }

  raw_units <- nc$var[[grid_vars]]$units
  if (is.null(raw_units) || length(raw_units) != 1L ||
      is.na(raw_units) || !nzchar(raw_units)) {
    stop("Missing temperature units in NetCDF metadata: ", nc_file)
  }

  unit_key <- tolower(gsub("[[:space:]_°]", "", raw_units))
  if (unit_key %in% c("k", "kelvin", "degreek", "degreeskelvin")) return("K")
  if (unit_key %in% c("c", "celsius", "degc", "degreec", "degreescelsius",
                      "degreecelsius", "degreescentigrade")) return("C")
  if (unit_key %in% c("f", "fahrenheit", "degf", "degreef",
                      "degreefahrenheit", "degreesfahrenheit")) return("F")

  stop("Unrecognized temperature units ('", raw_units, "') in: ", nc_file)
}

# Convert a SpatRaster from recognized NetCDF units to degrees Fahrenheit.
to_fahrenheit <- function(r, unit) {
  if (unit == "K") return((r - 273.15) * (9 / 5) + 32)
  if (unit == "C") return(r * (9 / 5) + 32)
  if (unit == "F") return(r)
  stop("Unsupported temperature units: ", unit)
}

# Read the *actual* NetCDF time coordinate first. terra::time() can report
# dates differently from the NetCDF coordinate in some files; using it first
# can cause a false failure even when every day is present.
read_dates_from_netcdf <- function(nc_file) {
  nc <- nc_open(nc_file)
  on.exit(nc_close(nc), add = TRUE)

  candidates <- c("day", "time", "days")
  time_var <- candidates[
    candidates %in% c(names(nc$dim), names(nc$var))
  ][1]
  if (is.na(time_var)) stop("No day/time coordinate in ", nc_file)

  if (time_var %in% names(nc$dim)) {
    time_vals <- nc$dim[[time_var]]$vals
    time_units <- nc$dim[[time_var]]$units
  } else {
    time_vals <- ncvar_get(nc, time_var)
    time_units <- ncatt_get(nc, time_var, "units")$value
  }
  if (length(time_units) != 1L || is.na(time_units) ||
      !grepl("since[[:space:]]+", time_units, ignore.case = TRUE)) {
    stop("Unrecognized NetCDF time units in ", nc_file, ": ",
         paste(time_units, collapse = ", "))
  }

  # A no-leap or 360-day calendar requires its own calendar mapping and must
  # NOT be silently interpreted as the standard Gregorian calendar.
  calendar_attr <- ncatt_get(nc, time_var, "calendar")
  calendar <- if (isTRUE(calendar_attr$hasatt)) {
    tolower(as.character(calendar_attr$value))
  } else "standard"
  if (calendar %in% c("365_day", "noleap", "360_day", "366_day", "all_leap")) {
    stop("NetCDF calendar '", calendar, "' in ", nc_file,
         " is not a standard Gregorian daily calendar. ",
         "Inspect the file before assigning calendar dates.")
  }

  origin_text <- sub("^.*since[[:space:]]+", "", time_units,
                     ignore.case = TRUE)
  origin_date <- suppressWarnings(as.Date(substr(origin_text, 1L, 10L)))
  if (is.na(origin_date)) {
    stop("Cannot parse NetCDF time origin ('", time_units, "') in ", nc_file)
  }

  if (grepl("^days?[[:space:]]+since", time_units, ignore.case = TRUE)) {
    offsets <- time_vals
  } else if (grepl("^hours?[[:space:]]+since", time_units,
                   ignore.case = TRUE)) {
    offsets <- time_vals / 24
  } else if (grepl("^minutes?[[:space:]]+since", time_units,
                   ignore.case = TRUE)) {
    offsets <- time_vals / 1440
  } else if (grepl("^seconds?[[:space:]]+since", time_units,
                   ignore.case = TRUE)) {
    offsets <- time_vals / 86400
  } else {
    stop("Unsupported NetCDF time units in ", nc_file, ": ", time_units)
  }

  as.Date(origin_date + offsets)
}

get_netcdf_dates <- function(nc_file, r) {
  from_nc <- tryCatch(
    read_dates_from_netcdf(nc_file),
    error = function(e) {
      # Do not bypass a known non-Gregorian calendar by trying terra dates.
      if (grepl("not a standard Gregorian daily calendar",
                conditionMessage(e), fixed = TRUE)) stop(e)
      message("    NetCDF date read: ", conditionMessage(e))
      NULL
    }
  )
  if (!is.null(from_nc) && length(from_nc) == nlyr(r) &&
      !all(is.na(from_nc))) {
    return(from_nc)
  }

  from_terra <- tryCatch(as.Date(terra::time(r)),
                         error = function(e) NULL)
  if (!is.null(from_terra) && length(from_terra) == nlyr(r) &&
      !all(is.na(from_terra))) {
    warning("Using terra layer-time metadata for ", basename(nc_file),
            " because the NetCDF time coordinate was unavailable.")
    return(from_terra)
  }

  warning("No usable time coordinate in ", basename(nc_file),
          "; layer-order fallback will require a full year of layers.")
  rep(as.Date(NA), nlyr(r))
}

# Helpful diagnostics if date metadata and calendar-year dates disagree.
date_summary <- function(dates, expected) {
  nonmissing <- dates[!is.na(dates)]
  if (length(nonmissing) == 0L) return("all date metadata missing")
  first_date <- as.character(nonmissing[1])
  last_date <- as.character(tail(nonmissing, 1))
  missing_days <- setdiff(expected, nonmissing)
  extra_days <- setdiff(nonmissing, expected)
  sprintf(paste0("layers=%s; first=%s; last=%s; ",
                 "duplicate_dates=%s; missing_calendar_dates=%s; ",
                 "unexpected_dates=%s"),
          length(dates), first_date, last_date,
          anyDuplicated(nonmissing), length(missing_days), length(extra_days))
}

# Return a layer index vector for one input. Real data dates are honored even
# when the layers are unordered. If the metadata is uniformly shifted, use
# January-December file order only when explicitly allowed and very close to
# the target year's boundaries; never conceal missing or duplicate days.
align_daily_layers <- function(dates, expected, yr, label) {
  n_expected <- length(expected)
  if (length(dates) != n_expected) {
    stop(label, " for ", yr, " has ", length(dates), " layers but ",
         n_expected, " daily layers are needed (", date_summary(dates, expected),
         "). Cannot calculate a full-year GDD sum from missing days.")
  }

  # Valid full daily set: reorder if the file is not already chronological.
  if (!anyNA(dates) && !anyDuplicated(dates) &&
      setequal(as.character(dates), as.character(expected))) {
    index <- match(expected, dates)
    if (!identical(index, seq_along(dates))) {
      message("    ", label, " ", yr,
              ": valid dates, but raster layers were out of order; reordering.")
    }
    return(index)
  }

  # Metadata absence or a small consistent date offset can occur with some
  # NetCDF exports; if we fall back, all daily layers must still be present.
  no_dates <- all(is.na(dates))
  consecutive <- !anyNA(dates) && !anyDuplicated(dates) &&
    all(diff(as.numeric(dates)) == 1)
  date_shift <- if (consecutive) {
    abs(as.numeric(dates[1] - expected[1]))
  } else Inf

  if (allow_sequential_date_fallback &&
      (no_dates || (consecutive &&
                    date_shift <= max_allowed_metadata_shift_days))) {
    warning(label, " ", yr, " time metadata does not match Jan 1-Dec 31 (",
            date_summary(dates, expected), "). ",
            "Assuming layers are sequential calendar days beginning Jan 1. ",
            "VERIFY this assumption against the source NetCDF file.")
    return(seq_along(expected))
  }

  stop(label, " for ", yr, " does not contain an identifiable complete ",
       "calendar-year daily sequence (", date_summary(dates, expected),
       "). Cannot safely align temperatures. Inspect the NetCDF day/time ",
       "variable with ncdf4::nc_open().")
}

validate_daily_pair <- function(max_dates, min_dates, yr) {
  expected <- seq.Date(
    as.Date(sprintf("%04d-01-01", yr)),
    as.Date(sprintf("%04d-12-31", yr)),
    by = "day"
  )
  max_index <- align_daily_layers(max_dates, expected, yr, "Tmax")
  min_index <- align_daily_layers(min_dates, expected, yr, "Tmin")
  list(dates = expected, max_index = max_index, min_index = min_index)
}

# ------------------------------------------------------------------------------
# 5. Process each year: daily cell GDD -> annual cell GDD -> county cropland mean
# ------------------------------------------------------------------------------

# For each year we SUM daily GDD at the grid-cell level, and only then take
# an area-weighted county cropland mean of those annual cell totals.
#
# Algebraically, for fully observed daily weather:
#  annual_gdd_county = sum_day weighted_mean_cropland(daily_gdd_cell)
# But doing the nonnegative daily GDD transformation before spatial averaging
# is essential because max(0, x) is nonlinear.

message("Extracting annual growing degree days for ", min(years), "-", max(years), "...")

county_mask_weather <- NULL
weather_ref_raster <- NULL

process_one_year <- function(yr) {
  max_file <- file.path(maxtemp_path, paste0("tmmx_", yr, ".nc"))
  min_file <- file.path(mintemp_path, paste0("tmmn_", yr, ".nc"))
  if (!file.exists(max_file)) stop("Missing maximum-temperature file: ", max_file)
  if (!file.exists(min_file)) stop("Missing minimum-temperature file: ", min_file)

  message("  Growing degree days: ", yr)
  max_r <- rast(max_file)
  min_r <- rast(min_file)

  # Geometry must match exactly: same coordinates, resolution and CRS.
  terra::compareGeom(max_r[[1]], min_r[[1]], stopOnError = TRUE)
  if (nlyr(max_r) != nlyr(min_r)) {
    stop("Different number of Tmax and Tmin layers for year ", yr)
  }

  # Establish one common projection of the county cropland polygons, and
  # require subsequent years to use the same raster CRS / grid geometry.
  if (is.null(county_mask_weather)) {
    county_mask_weather <<- st_transform(county_cropland, crs(max_r))
    weather_ref_raster <<- max_r[[1]]
  } else {
    terra::compareGeom(weather_ref_raster, max_r[[1]], stopOnError = TRUE)
  }

  max_dates <- get_netcdf_dates(max_file, max_r)
  min_dates <- get_netcdf_dates(min_file, min_r)
  date_alignment <- validate_daily_pair(max_dates, min_dates, yr)
  daily_dates <- date_alignment$dates

  # Respect NetCDF date labels (reordering layers when required) before
  # applying any day-by-day nonlinear GDD transformation.
  max_r <- max_r[[date_alignment$max_index]]
  min_r <- min_r[[date_alignment$min_index]]

  max_unit <- get_temperature_units(max_file)
  min_unit <- get_temperature_units(min_file)
  message("    Temperature units: Tmax=", max_unit, ", Tmin=", min_unit,
          "; base=", base_temp_f, " F")

  # Keep intermediate rasters for THIS year only. The on.exit handler also
  # removes them if extraction fails midway through this year.
  tmp_files <- character(0)
  on.exit(unlink(tmp_files), add = TRUE)

  for (month_num in 1:12) {
    layer_ids <- which(as.integer(format(daily_dates, "%m")) == month_num)
    if (length(layer_ids) == 0L) {
      stop("Year ", yr, " is missing days in month ", month_num)
    }

    max_f <- to_fahrenheit(max_r[[layer_ids]], max_unit)
    min_f <- to_fahrenheit(min_r[[layer_ids]], min_unit)
    tmean_f <- (max_f + min_f) / 2

    # A day contributes zero GDD if mean temperature is below 50 F.
    # Missing Tmax/Tmin propagate as NA, rather than being treated as zero.
    excess <- tmean_f - base_temp_f
    daily_gdd <- terra::ifel(excess > 0, excess, 0)

    month_file <- tempfile(
      pattern = sprintf("gdd_%04d_%02d_", yr, month_num),
      fileext = ".tif"
    )
    # Register the file BEFORE raster processing so cleanup catches failures.
    tmp_files <- c(tmp_files, month_file)
    terra::app(
      daily_gdd,
      fun = sum,
      na.rm = FALSE,
      filename = month_file,
      overwrite = TRUE
    )

    rm(max_f, min_f, tmean_f, excess, daily_gdd)
  }

  # Sum 12 monthly GDD rasters. If a cell is missing even one day, its annual
  # sum is NA; available cells in the county may still contribute to its mean.
  annual_file <- tempfile(pattern = sprintf("gdd_%04d_annual_", yr),
                          fileext = ".tif")
  tmp_files <- c(tmp_files, annual_file)
  terra::app(
    rast(tmp_files[seq_len(12L)]),
    fun = sum,
    na.rm = FALSE,
    filename = annual_file,
    overwrite = TRUE
  )
  annual_gdd_r <- rast(annual_file)

  # exact_extract uses sub-cell coverage fractions of agricultural land.
  # County parts without mapped cropland remain NA in the final output.
  crop_values <- exactextractr::exact_extract(
    annual_gdd_r,
    county_mask_weather,
    fun = "mean",
    progress = FALSE
  )
  crop_values <- as.matrix(crop_values)
  if (nrow(crop_values) != nrow(county_mask_weather) ||
      ncol(crop_values) != 1L) {
    stop("Unexpected GDD extraction dimensions in ", yr)
  }

  county_values <- rep(NA_real_, nrow(counties))
  county_ids <- match(county_mask_weather$GEOID, counties$GEOID)
  if (anyNA(county_ids)) stop("Cropland GEOID not found in county list.")
  county_values[county_ids] <- as.numeric(crop_values[, 1])

  data.frame(
    fips = as.character(counties$GEOID),
    year = as.integer(yr),
    gdd = county_values
  )
}

annual_list <- lapply(years, process_one_year)
gdd_panel <- bind_rows(annual_list) %>%
  arrange(fips, year)

# ------------------------------------------------------------------------------
# 6. Trailing 5-year mean, current year + preceding 4 years
# ------------------------------------------------------------------------------

# stats::filter propagates NA when any of the 5 annual measures are missing.
rolling_five_year_mean <- function(x) {
  as.numeric(stats::filter(x, filter = rep(1 / 5, 5), sides = 1))
}

gdd_panel <- gdd_panel %>%
  group_by(fips) %>%
  arrange(year, .by_group = TRUE) %>%
  mutate(gdd_5yr_avg = rolling_five_year_mean(gdd)) %>%
  ungroup() %>%
  select(fips, year, gdd, gdd_5yr_avg) %>%
  arrange(fips, year)

# ------------------------------------------------------------------------------
# 7. Quality checks and export
# ------------------------------------------------------------------------------

stopifnot(
  nrow(gdd_panel) == nrow(counties) * length(years),
  !anyDuplicated(gdd_panel[c("fips", "year")]),
  all(names(gdd_panel) == c("fips", "year", "gdd", "gdd_5yr_avg")),
  all(is.na(gdd_panel$gdd) | gdd_panel$gdd >= 0),
  all(is.na(gdd_panel$gdd_5yr_avg) | gdd_panel$gdd_5yr_avg >= 0),
  all(is.na(gdd_panel$gdd_5yr_avg[gdd_panel$year < min(years) + 4L]))
)

message("County-year rows: ", nrow(gdd_panel))
message("Unique counties: ", n_distinct(gdd_panel$fips))
message("Missing annual GDD values: ", sum(is.na(gdd_panel$gdd)))
message("Missing 5-year average GDD values: ", sum(is.na(gdd_panel$gdd_5yr_avg)))
print(head(gdd_panel))

dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
write.csv(gdd_panel, output_file, row.names = FALSE)
write.csv(county_coverage, coverage_file, row.names = FALSE)

message("Done. GDD panel saved to: ", output_file)
message("USGS cropland coverage diagnostics saved to: ", coverage_file)
