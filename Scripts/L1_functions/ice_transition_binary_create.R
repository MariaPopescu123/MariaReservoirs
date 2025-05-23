### file for generating ice binary L1 file ## 
# taken from the catwalk data
#source('Data/DataNotYetUploadedToEDI/Ice_binary/ice_binary_targets_function.R')


### THIS IS ONE OF TWO FILES FOR ICE COVER ###
# THIS FILE IS MEANT TO SHOW JUST THE DAYS WHEN ICE COVER CHANGES (VISUAL OR CALCULATED)

## current and historic = catwalk

ice_transition_binary_create <- function(current_file, historic_wq_file, historic_file, ice_site, maint_log = NULL){
  
  ## read in current data file
  # Github, Googlesheet, etc.
  
  current_wq_df <- readr::read_csv(current_file, show_col_types = F)|>
    dplyr::filter(Site == 50) |>
    dplyr::select(Reservoir, DateTime,
                  dplyr::starts_with('ThermistorTemp')) |>
    tidyr::pivot_longer(cols = starts_with('ThermistorTemp'),
                        names_to = 'depth',
                        names_prefix = 'ThermistorTemp_C_',
                        values_to = 'observation') |>
    dplyr::mutate(datetime = lubridate::as_datetime(paste0(format(DateTime, "%Y-%m-%d %H"), ":00:00"))) |>
    dplyr::group_by(Reservoir, datetime, depth) |>
    dplyr::summarise(observation = mean(observation, na.rm = T),
                     .groups = 'drop') |>
    dplyr::mutate(site_id = ifelse(Reservoir == 'FCR',
                     'fcre',
                     ifelse(Reservoir == 'BVR',
                            'bvre', NA)))
    #dplyr::rename(site_id = Reservoir)
  
  # the depths used to assess will change depending on the current depth of FCR
  depths_use_current <- current_wq_df |>
    dplyr::mutate(depth = ifelse(depth == "surface", 0.1, depth)) |>
    na.omit() |>
    dplyr::group_by(datetime) |>
    dplyr::summarise(top = min(as.numeric(depth)),
                     bottom = max(as.numeric(depth))) |>
    tidyr::pivot_longer(cols = top:bottom,
                        values_to = 'depth')
  
  
  current_ice_df <- current_wq_df |>
    dplyr::mutate(depth = as.numeric(ifelse(depth == "surface", 0.1, depth))) |>
    dplyr::right_join(depths_use_current, by = c('datetime', 'depth')) |>
    dplyr::select(-depth) |>
    tidyr::pivot_wider(names_from = name,
                       values_from = observation) |>
    # Ice defined as when the top is cooler than the bottom, and temp below 4 oC
    dplyr::mutate(temp_diff = top - bottom,
                  variable = ifelse(temp_diff < -0.1 & top <= 4, 'IceOn', 'IceOff'), 
                  IceOn = ifelse(variable == "IceOn", 1, 0), 
                  IceOff = ifelse(variable == "IceOff", 1, 0)) |> #, 
                  #datetime = as.Date(datetime)) |>
    #dplyr::group_by(datetime) |> 
    # dplyr::mutate(IceOn = ifelse(1 %in% IceOn_hourly, 1, 0),
    #               IceOff = ifelse(1 %in% IceOn_hourly, 0, 1),
    #               IceOn_hour_count = sum(IceOn_hourly == 1),
    #               IceOn_hour_index = list(which(IceOn_hourly == 1))) |> 
    # ungroup() |> 
    distinct(site_id, datetime, .keep_all = TRUE) |> 
    select(Reservoir, site_id, datetime, IceOn, IceOff) |> 
    #dplyr::filter(IceOn != dplyr::lag(IceOn))  |> # only select rows where ice condition changes
    dplyr::mutate(Site = 50, 
                  Year = lubridate::year(datetime), 
                  DayOfYear = lubridate::yday(datetime),
                  Method = 'T', 
                  Flag_IceValue = 0,
                  datetime = lubridate::as_datetime(datetime)) |> #,
                  #DateTime = force_tz(datetime, tzone = 'America/New_York')) |> 
    select(Reservoir, Site, DateTime = datetime, Year, DayOfYear, IceOn, IceOff, Method, Flag_IceValue, site_id)
  
  
  message('Current file ready')
  
  
  
  ## historic wq data 
  historic_wq_df <- read_csv(historic_wq_file) |> 
    dplyr::filter(Site == 50) |>
    dplyr::select(Reservoir, DateTime,
                  dplyr::starts_with('ThermistorTemp')) |>
    tidyr::pivot_longer(cols = starts_with('ThermistorTemp'),
                        names_to = 'depth',
                        names_prefix = 'ThermistorTemp_C_',
                        values_to = 'observation') |>
    dplyr::mutate(datetime = lubridate::as_datetime(paste0(format(DateTime, "%Y-%m-%d %H"), ":00:00"))) |> 
    dplyr::filter(datetime > lubridate::as_datetime('2018-07-05')) |> 
    dplyr::mutate(site_id = ifelse(Reservoir == 'FCR',
                                   'fcre',
                                   ifelse(Reservoir == 'BVR',
                                          'bvre', NA)))
  
  depths_use_historic <- historic_wq_df |>
    dplyr::mutate(depth = ifelse(depth == "surface", 0.1, depth)) |>
    na.omit() |>
    dplyr::group_by(datetime) |>
    dplyr::summarise(top = min(as.numeric(depth)),
                     bottom = max(as.numeric(depth))) |>
    tidyr::pivot_longer(cols = top:bottom,
                        values_to = 'depth')
  
  historic_wq_ice_df <- historic_wq_df |>
    dplyr::mutate(depth = as.numeric(ifelse(depth == "surface", 0.1, depth))) |>
    dplyr::right_join(depths_use_historic, by = c('datetime', 'depth')) |>
    dplyr::select(-depth) |>
    tidyr::pivot_wider(names_from = name,
                       values_from = observation) |>
    # Ice defined as when the top is cooler than the bottom, and temp below 4 oC
    dplyr::mutate(temp_diff = top - bottom,
                  variable = ifelse(temp_diff < -0.1 & top <= 4, 'IceOn', 'IceOff'), 
                  IceOn = ifelse(variable == "IceOn", 1, 0), 
                  IceOff = ifelse(variable == "IceOff", 1, 0)) |> #, 
                  #datetime = as.Date(datetime)) |>
    # dplyr::group_by(datetime) |> 
    # dplyr::mutate(IceOn = ifelse(1 %in% IceOn_hourly, 1, 0),
    #               IceOff = ifelse(1 %in% IceOn_hourly, 0, 1),
    #               IceOn_hour_count = sum(IceOn_hourly == 1),
    #               IceOn_hour_index = list(which(IceOn_hourly == 1))) |> 
    # ungroup() |> 
    distinct(site_id, datetime, .keep_all = TRUE) |> 
    select(Reservoir, site_id, datetime, IceOn, IceOff) |> 
    #dplyr::filter(IceOn != dplyr::lag(IceOn))  |> # only select rows where ice condition changes
    dplyr::mutate(Site = 50, 
                  Year = lubridate::year(datetime), 
                  DayOfYear = lubridate::yday(datetime),
                  Method = 'T', 
                  Flag_IceValue = 0, 
                  #DateTime = force_tz(datetime, tzone = 'America/New_York'
                                      ) |> 
    select(Reservoir, Site, DateTime = datetime, Year, DayOfYear, IceOn, IceOff, Method, Flag_IceValue, site_id)
  
  
  # read in historical data file
  # EDI
  infile <- tempfile()
  try(download.file(historic_file, infile, method="curl"))
  if (is.na(file.size(infile))) download.file(historic_file,infile,method="auto")
  
  historic_ice_df <- readr::read_csv(infile, show_col_types = F) |>
    dplyr::mutate(site_id = ifelse(Reservoir == 'FCR', 'fcre',
                                   ifelse(Reservoir == 'BVR', 'bvre', NA))) |>
    dplyr::filter(site_id == current_wq_df$site_id[1], 
                  Date < '2018-07-05') |> 
    mutate(DateTime = as.POSIXct(paste(Date, '12:00'), format="%Y-%m-%d %H:%M"),
           DateTime = force_tz(DateTime, tzone = 'America/New_York')) |> 
    select(-Date)
  
  # combine available data and then join onto daily dataframe
  if (nrow(historic_ice_df) == 0){
    combined_df <- dplyr::bind_rows(historic_wq_ice_df, current_ice_df) |> 
      select(Reservoir, Site, DateTime, Year, DayOfYear, IceOn, IceOff, Method, Flag_IceValue, site_id)
  } else{
    combined_df <- dplyr::bind_rows(historic_ice_df, historic_wq_ice_df, current_ice_df) |> 
      select(Reservoir, Site, DateTime, Year, DayOfYear, IceOn, IceOff, Method, Flag_IceValue, site_id)
    
  }
  
  if(is.na(max(as.POSIXct(combined_df$DateTime)))){
    message('DATE CONVERSION ISSUE...QUITTING')
    stop()
  }
  
  ice_df_build <- data.frame(DateTime = seq.POSIXt(min(as.POSIXct(combined_df$DateTime)), 
                                                 max(as.POSIXct(combined_df$DateTime)), 
                                                 by = 'hour'))
  
  reservoir_name <- combined_df$Reservoir[1]
  site_identifier <- combined_df$site_id[1]
  
  ice_df_hourly <- ice_df_build |> 
    dplyr::full_join(combined_df, by = c('DateTime')) |> 
    dplyr::mutate(Reservoir = ifelse(is.na(Reservoir), reservoir_name, Reservoir), 
                  IceOn = ifelse(is.na(IceOn), zoo::na.locf(IceOn), IceOn), ## fill in gaps for ice-on using available data
                  Method = ifelse(is.na(Method), 'T', Method), 
                  site_id = ifelse(Reservoir == 'FCR', 'fcre',
                                                 ifelse(Reservoir == 'BVR', 'bvre', NA)),
                  Flag_IceValue= 0,
                  Site = 50, 
                  Year = lubridate::year(DateTime), 
                  DayOfYear = lubridate::yday(DateTime))
  
  
  #combined_df <- dplyr::bind_rows(historic_ice_df, historic_wq_ice_df, current_ice_df)
  
  
  if(!is.null(maint_log)){ # only run this file if the maint file argument is non-null
    
    # ## ADD MAINTENANCE LOG FLAGS (manual edits to the data for suspect samples or human error)
    
    log_read <- gsheet::gsheet2tbl(maint_log) |> 
      mutate(TIMESTAMP_start = force_tz(lubridate::as_datetime(TIMESTAMP_start), tzone = 'America/New_York'),
             TIMESTAMP_end = force_tz(lubridate::as_datetime(TIMESTAMP_end)), tzone = 'America/New_York') |> 
      filter(Reservoir == ice_site) |> 
      select(Reservoir, TIMESTAMP_start, TIMESTAMP_end, Ice_Presence, Site, Flag_Ice_Presence)
    
    log <- log_read
    
    for(i in 1:nrow(log)){
      ### get start and end time of one maintenance event
      start <- log$TIMESTAMP_start[i]
      end <- log$TIMESTAMP_end[i]
      
      
      ## GET THE ICE INDICATION
      ice_indication <- log$Ice_Presence[i]
      
      ## GET THE ICE INDICATION
      ice_method <- log$Flag_Ice_Presence[i]
      

      ### Getting the start and end time vector to fix. If the end time is NA then it will put NAs 
      # until the maintenance log is updated
      
      if(is.na(end)){
        # If there the maintenance is on going then the columns will be removed until
        # and end date is added
        Time <- ice_df_hourly$DateTime >= start
        
      }else if (is.na(start)){
        # If there is only an end date change columns from beginning of data frame until end date
        Time <- ice_df_hourly$DateTime <= end
        
      }else {
        
        Time <- ice_df_hourly$Date >= start & ice_df_hourly$Date <= end
        
      }
      
      # update dataset with ice value from maint log
      ice_df_hourly$ice_value_update <- NA
      ice_df_hourly[Time, "ice_value_update"] <- ice_indication
      
      # update with maint log values
      ice_df_hourly$IceOn <- ifelse(!is.na(ice_df_hourly$ice_value_update), ice_df_hourly$ice_value_update, ice_df_hourly$IceOn)
      
      # update data with ice method from maint log
      ice_df_hourly[Time, "Method"] <- ice_method
    }
      
    transition_ice_df <- ice_df_hourly |> 
      mutate(IceOff = ifelse(is.na(IceOff) & IceOn == 0, 1, IceOff),
             Flag_IceValue = ifelse(is.na(Flag_IceValue), 0, Flag_IceValue), 
             DateTime = lubridate::with_tz(DateTime, tzone = "America/Los_Angeles")) |>
      dplyr::filter(IceOn != dplyr::lag(IceOn))  |> # only select rows where ice condition changes
      select(-Flag_IceValue, -ice_value_update)
    
  } else {
    message('No maintenance log used....')
    transition_ice_df <- ice_df_hourly |> select(-Flag_IceValue)
  }
  
  message('EDI file ready')
  
  ## return dataframe formatted to match FLARE targets
  return(transition_ice_df)
}

## CODE TO RUN FUNCTION IF NEEDED ##

# current_files <- c("https://raw.githubusercontent.com/FLARE-forecast/BVRE-data/bvre-platform-data-qaqc/bvre-waterquality_L1.csv",
#                    "https://raw.githubusercontent.com/FLARE-forecast/FCRE-data/fcre-catwalk-data-qaqc/fcre-waterquality_L1.csv")
# 
# historic_wq_files <- c('https://pasta.lternet.edu/package/data/eml/edi/725/4/9adadd2a7c2319e54227ab31a161ea12',
#                        'https://pasta.lternet.edu/package/data/eml/edi/271/8/fbb8c7a0230f4587f1c6e11417fe9dce')
# 
# historic_ice_files <- c("https://pasta.lternet.edu/package/data/eml/edi/456/5/ebfaad16975326a7b874a21beb50c151")
# 
# ice_maintenance_log <- c('https://docs.google.com/spreadsheets/d/1viYhCGs3UgstzHEWdmP2Ig6uxyNM3ZC_uisG_R0QNpI/edit?gid=0#gid=0')
# 
# 
# bvr_ice_data <- ice_transition_binary_create(current_file = current_files[1],
#                                             historic_wq_file = historic_wq_files[1],
#                                             historic_file = historic_ice_files,
#                                             ice_site = 'BVR',
#                                             maint_log = NULL)
# 
# fcr_ice_data <- target_IceTransition_binary(current_file = current_files[2],
#                                             historic_wq_file = historic_wq_files[2],
#                                             historic_file = historic_ice_files,
#                                             ice_site = "FCR",
#                                             maint_log = ice_maintenance_log)
# 
# combined_ice_data <- dplyr::bind_rows(bvr_ice_data, fcr_ice_data) |> select(-site_id)

#write.csv(combined_ice_data, "C:/Users/13188/Desktop/Data_repository/DataNotYetUploadedToEDI/Ice_binary/ice_L1.csv", row.names = FALSE)


# fcr_ice_data |> 
#   ggplot(aes(x = Date, y = IceOn)) + 
#   geom_point() + 
#   geom_point(aes(y = IceOff, color = 'red'), alpha = 0.6) + 
#   labs(title="FCR Ice Transition Binary", x ="Date", y = "IceOn/IceOff Binary")
# 
# bvr_ice_data |> 
#   ggplot(aes(x = Date, y = IceOn)) + 
#   geom_point() + 
#   geom_point(aes(y = IceOff, color = 'red'), alpha = 0.6) + 
#   labs(title="BVR Ice Transition Binary", x ="Date", y = "IceOn/IceOff Binary")
# 
# 
# historic_transition_check <- historic_ice_df |> # DEFINED IN CODE ABOVE
#   mutate(IceOn_historic = IceOn, 
#          IceOff_historic = IceOff, 
#          Method_historic = Method) |> 
#   select(Date, IceOn_historic, IceOff_historic, Method_historic) |> 
#   right_join(fcr_ice_data, by = c('Date'))
# 
# historic_transition_check |> 
#   ggplot(aes(x = Date, y = IceOn)) +
#   geom_point() +
#   geom_point(aes(y = IceOn_historic, color = 'red'), alpha = 0.6)
#   #geom_point() #+
#   #geom_point(aes(y = IceOn_historic, color = 'red'), alpha = 0.3)
#   
# historic_transition_check |> 
#   ggplot(aes(x = Date, y = IceOff)) +
#   geom_point() +
#   geom_point(aes(y = IceOff_historic, color = 'red'), alpha = 0.6)
#   #geom_point()
