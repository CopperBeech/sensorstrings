
# all compile foos --------------------------------------------------------

#' Set up parameters, Errors, and Warnings for the \code{compile_**} functions
#'
#' @inheritParams ss_compile_hobo_data
#' @param path File path to the folder with the aquameasure, hobo, or vemco
#'   folder.
#'
#' @param sensor_make Make of the sensor to be compiled. Should match the name
#'   of the folder where the raw data files are saved and be found in the
#'   \code{sensor} column in \code{sn_table}. Most common entries will be
#'   "aquameasure", "hobo", or "vemco".
#'
#' @return Returns a list of parameters used in the \code{compile_**} functions.
#'   Returns Errors and Warnings if the expected files are not found in
#'   \code{folder}.
#'
#' @importFrom dplyr %>% mutate select
#' @importFrom glue glue
#' @importFrom lubridate parse_date_time
#' @importFrom stringr str_detect

set_up_compile <- function(path,
                           sn_table,
                           deployment_dates,
                           sensor_make) {

  # make sure columns of serial.table are named correctly
  names(sn_table) <- c("sensor", "serial", "depth")
  sn_table <- sn_table %>%
    filter(str_detect(sensor, regex(sensor_make, ignore_case = TRUE))) %>%
    mutate(sensor_serial = glue("{sensor}-{serial}"))

  # extract the deployment start and end dates from deployment_dates
  dates <- extract_deployment_dates(deployment_dates)

  # name of folder (case-insensitive)
  if(sensor_make == "VR2AR") sensor_make <- "vemco"

  folder <- list.files(path) %>%
    str_extract(regex(sensor_make, ignore_case = TRUE)) %>%
    na.omit()

  if(length(folder) == 0) {
    stop("There is no folder named << ", sensor_make, " >> in path << ", path, " >>" )
  }

  # path to hobo files
  path <- glue("{path}/{folder}")

  # list files in the Hobo folder
  dat_files <- list.files(path, all.files = FALSE, pattern = "*csv")

  # check for excel files
  excel_files <- list.files(path, all.files = FALSE, pattern = "*xlsx|xls")

  # check for surprises in dat_files

  if (length(dat_files) == 0) {
    stop(glue("Can't find csv files in {path}"))
  }

  if (sensor_make == "vemco" && length(dat_files) > 1) {
    stop(glue("There are {length(dat_files)} csv files in {path};
                 expected 1 file"))
  }

  if (length(dat_files) != nrow(sn_table)) {
    warning(glue("There are {length(dat_files)} csv files in {path}.
              Expected {nrow(sn_table)} files"))
  }

  if (length(excel_files) > 0) {
    warning(glue("Can't compile excel files.
    {length(excel_files)} excel files found in hobo folder.
    \nHINT: Please re-export in csv format."))
  }

# return info
  list(
    path = path,
    dates = dates,
    dat_files = dat_files,
    sn_table = sn_table
  )
}


#' Check number of rows of data file
#'
#' @param dat Data frame
#'
#' @param file_name Name of file to check.
#'
#' @param trimmed Logical value indicating if \code{dat} has been trimmed.
#'
#' @return Returns a Warning if there no rows in \code{dat}.

check_n_rows <- function(dat, file_name, trimmed = TRUE) {

  if(nrow(dat) == 0) {
    if(isFALSE(trimmed)) {
      stop("Before trimming, there are 0 rows of data in file ", file_name)
    }

    if(isTRUE(trimmed)) {
      stop("After trimming, there are 0 rows of data in file ", file_name)
    }
  }
}


#' convert_timestamp_to_datetime()
#'
#' @param dat Data.frame with column \code{timestamp_} that has timestamps as
#'   character values.
#'
#' @details Convert the timestamp_ column to a POSIXct object.
#'
#' @importFrom lubridate parse_date_time

convert_timestamp_to_datetime <- function(dat) {
  date_format <- dat$timestamp_[1] # first datetime value; use to check the format

  parse_orders <- c(
    "ymd IMS p", "Ymd IMS p",
    "Ymd HM", "Ymd HMS",
    "dmY HM", "dmY HMS",
    "dmY IM p", "dmY IMS p"
  )

  check_date <- suppressWarnings(
    parse_date_time(date_format, orders = parse_orders)
  )

  if (!is.na(check_date)) {
    dat <- dat %>%
      mutate(
        timestamp_ = lubridate::parse_date_time(timestamp_, orders = parse_orders)
      )
  } else {

    # Error message if the date format is incorrect
    stop(paste0("Can't parse date in format ", date_format))
  }

  dat
}


#' Extract deployment dates
#' @param deployment_dates Data.frame with start and end dates of the deployment
#'   in the form yyyy-mm-dd. Two columns: \code{START} and \code{END}.
#'
#' @importFrom tidyr separate
#' @importFrom lubridate as_datetime

extract_deployment_dates <- function(deployment_dates) {

  # name deployment.dates
  names(deployment_dates) <- c("start_date", "end_date")

  # paste date and time and convert to a datetime object
  start_date <- as_datetime(paste(deployment_dates$start_date, "00:00:00"))
  end_date <- as_datetime(paste(deployment_dates$end_date, "23:59:59"))

  # return start and end datetimes
  data.frame(start = start_date, end = end_date)
}


#' Trim data to specified start and end dates.
#'
#' 4 hours adde to end_date to account for AST (e.g., in case the sensor was
#' retrieved after 20:00 AST, which is 00:00 UTC **The next day**)
#'
#' @param dat Data.frame with column including the string "timestamp"
#' @param start_date POSIXct/POSIXt value of the first good timestamp.
#' @param end_date POSIXct/POSIXt value of the last good timestamp.
#'
#' @importFrom checkmate assert_posixct
#' @importFrom lubridate hours
#' @importFrom stringr str_detect
#'
#' @return Returns dat trimmed.

trim_data <- function(dat, start_date, end_date) {
  assert_posixct(start_date)
  assert_posixct(end_date)

  ind <- colnames(dat)[which(str_detect(colnames(dat), "timestamp"))]

  dat %>%
    filter(
      .data[[ind[[1]]]] >= start_date,
      .data[[ind[[1]]]] <= (end_date + hours(4))
    )
}


# aqumeasure --------------------------------------------------------------

#' Extract the timezone of aquameasure timestamps
#'
#' @inheritParams extract_aquameasure_vars
#'
#' @return Returns a character string of the timezone indicated in the Timestamp
#'   column.
#'
#' @importFrom stringr str_detect str_split

extract_aquameasure_tz <- function(am_colnames) {
  tz_name <- am_colnames[which(str_detect(am_colnames, "stamp"))]

  x <- str_split(tz_name, pattern = "\\(")

  y <- str_split(x[[1]][2], "\\)")

  tolower(y[[1]][1])
}


#' Extract the variables included in aquameasure file from the column names
#'
#' @param am_colnames Column names of aquameasure data file.
#'
#' @return Returns a vector of the variables included in the file.

extract_aquameasure_vars <- function(am_colnames) {

  ## check colnames of dat.i for "Temperature", "Dissolved Oxygen", and "Salinity"
  temp <- ifelse("Temperature" %in% am_colnames, "Temperature", NA)
  DO <- ifelse("Dissolved Oxygen" %in% am_colnames, "Dissolved Oxygen", NA)
  sal <- ifelse("Salinity" %in% am_colnames, "Salinity", NA)
  sensor_depth <- ifelse("Device Depth" %in% am_colnames, "Device Depth", NA)


  # create vector of the variables in this file by removing NA
  vars <- c(temp, DO, sal, sensor_depth)
  vars[which(!is.na(vars))]
}


# HOBO --------------------------------------------------------------------

#' Extract HOBO serial number from the data file
#'
#' @param hobo_colnames Column names of the HOBO file, as imported by
#'   \code{ss_read_hobo_data()}.
#'
#' @return Returns the HOBO serial number.
#'
#' @importFrom glue glue
#' @importFrom stringr str_detect str_remove str_split

extract_hobo_sn <- function(hobo_colnames) {
  SN <- hobo_colnames[str_detect(hobo_colnames, pattern = "Temp")]
  SN <- str_split(SN, pattern = ", ")

  LOGGER_SN <- str_split(SN[[1]][2], pattern = ": ")
  LOGGER_SN <- LOGGER_SN[[1]][2]

  SENSOR_SN <- str_split(SN[[1]][3], pattern = ": ")
  SENSOR_SN <- str_remove(SENSOR_SN[[1]][2], pattern = "\\)")

  if (LOGGER_SN == SENSOR_SN) {
    as.numeric(SENSOR_SN)
  } else {
    stop(
      glue("HOBO file LOGR S/N ({LOGGER_SN}) does not match SEN S/N ({SENSOR_SN})")
    )
  }
}


#' Extract units from column names of hobo data
#'
#' @param hobo_dat Data as read in by \code{ss_read_hobo_data()}.
#'
#' @return Returns a tibble of \code{variable} and \code{units} found in
#'   \code{hobo_dat}. Units are mg_per_L for dissolved oxygen and degree_C for
#'   temperature.
#' @importFrom dplyr %>% contains mutate select
#' @importFrom stringr str_replace str_remove
#' @importFrom tidyr separate

extract_hobo_units <- function(hobo_dat) {
  hobo_dat %>%
    select(contains("Date"), contains("Temp"), contains("DO")) %>%
    colnames() %>%
    data.frame() %>%
    separate(col = ".", into = c("variable", "units"), sep = ", ", extra = "drop") %>%
    separate(col = "units", into = c("units", NA), sep = " \\(", fill = "right") %>%
    mutate(
      units = str_replace(units, pattern = "GMT", replacement = "utc"),
      units = str_remove(units, pattern = "\\+00:00"),
      units = str_replace(units, pattern = "mg/L", replacement = "mg_per_L"),
      units = str_replace(units, pattern = "\u00B0C", replacement = "degree_C")
    )
}

#' Glue variable name and units to create column names
#'
#' @param unit_table Data.frame including columns \code{variable} and
#'   \code{units}, as returned from \code{extract_hobo_units()}.
#'
#' @return Data.frame with column names in the form \code{variable_units}.
#'
#' @importFrom dplyr %>% arrange mutate
#' @importFrom stringr str_detect str_replace
#' @importFrom glue glue

make_column_names <- function(unit_table) {
  new_names <- unit_table %>%
    mutate(
      variable = str_replace(
        variable,
        pattern = "Date Time", replacement = "timestamp_"
      ),
      variable = str_replace(
        variable,
        pattern = "DO conc", replacement = "dissolved_oxygen_"
      ),
      variable = str_replace(
        variable,
        pattern = "Temp", replacement = "temperature_"
      ),
      col_name = glue("{variable}{units}")
    )

  # make ordered factor so rows will always be in this order
  ## timestamp, dissolved oxygen, temperature
  ## this is important because the columns will be named in this order
  f_levels <- c(
    new_names[str_detect(new_names$col_name, "timestamp"), ]$col_name,
    new_names[str_detect(new_names$col_name, "dissolved_oxygen"), ]$col_name,
    new_names[str_detect(new_names$col_name, "temperature"), ]$col_name
  )

  new_names %>%
    mutate(col_name = ordered(col_name, levels = f_levels)) %>%
    arrange(col_name) %>%
    mutate(col_name = as.character(col_name))
}


# vemco -------------------------------------------------------------------

#' Extract the timezone of vemco timestamps
#'
#' @param dat_colnames Column names of the Vemco file.
#'
#' @return Returns a character string of the timezone indicated in the Timestamp
#'   column.
#'
#' @importFrom stringr str_detect str_split

extract_vemco_tz <- function(dat_colnames) {
  tz_name <- dat_colnames[which(str_detect(dat_colnames, "Time"))]

  x <- str_split(tz_name, pattern = " ")

  tolower(gsub("[()]", "", x[[1]][4]))
}




