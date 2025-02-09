# Need this so that package will play nice with dplyr package
# https://community.rstudio.com/t/how-to-solve-no-visible-binding-for-global-variable-note/28887
# more technical solution here: https://cran.r-project.org/web/packages/dplyr/vignettes/programming.html

# other technical solution here:
# https://dplyr.tidyverse.org/articles/programming.html


utils::globalVariables(
  c(
    # ss_compile_hobo_data
    "variable",
    "serial",
    "sensor",
    "depth",
    "timestamp_",
    "HOBO_dat",
    "deployment_range",
    ".data",

    # ss_compile_aquameasure_data
    "Sensor",
    "Temp(Water)",
    "Record Type",
    "do_percent_saturation",
    "dissolved_oxygen_percent_saturation",
    "temperature_degree_C",
    "sensor_depth_at_low_tide_m",
    "sensor_depth_measured_m",

    # ss_compile_vemco_date
    "Description",
    "Units",
    "Data",

    # ss_compile_deployment_data
    "county",
    "waterbody",
    "station",
    "lease",
    "latitude",
    "longitude",

    # ss_read_log
    "Logger_Model",
    "Serial#",
    "Sensor_Depth",
    "numeric_depth",
    "detect_hobo",
    "detect_am",
    "detect_vemco",

    # make_column_names
    "col_name",

    # ss_convert_depth_to_ordered_factor
    "depth",

    # ss_pivot
    "value",

    # ss_downloade_data
    "name"
  )
)
