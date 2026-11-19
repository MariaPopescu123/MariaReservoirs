#Title: Script for aggregating and QAQCing FP txt files for publication to EDI
#Author: Mary Lofton
#Updated version: Austin Delany
#Date created: 16DEC19
#Last updated: 2024-06-16 ABP- add in start and end dates to subset L1 file
#Additional notes: This script is included with this EDI package to show which QAQC has already been applied to generate these data <and includes additional R scripts available with this package>. This script is only for internal use by the data creator team and is provided as a reference; it will not run as-is. 



library(tidyverse)
library(lubridate)
library(httr) 

#rm(list=ls())

# load packages
#install.packages('pacman')
#pacman::p_load(tidyverse, lubridate, googlesheets4)

##### Function to qaqc Fluoroprobe data
#'@param example_file_for_colnames filepath to an example raw file from the FluoroProbe to get column names for subsequent data wrangling
#'@param current_year_data_folder filepath to where txt files for current year are kept
#'@param historic_data_folder filepath to where txt files from previous years are kept
#'@param historic_data_2017 filepath to where txt file with recalibrated data from 2017 reside
#'@param maintenance_file filepath to the maintenance log
#'@param out_file filepath for output file
#'@param start_date first day of current year (day after last day of data pushed to EDI)
#'@param end_date last day of current year (last day before we publish a revision to EDI)

fluoroprobe_qaqc <- function(repo_link,
                             repo_filepath,
                             example_file_for_colnames,
                             current_year_data_folder,
                             historic_data_folder,
                             historic_data_2017,
                             maintenance_file,
                             out_file,
                             start_date = NULL, 
                             end_date = NULL){

# Load in column names for .txt files to get template
col_names <- names(read_tsv(example_file_for_colnames, n_max = 0))

# Load in all txt files from previous years
req <- GET(repo_link)
stop_for_status(req)
filelist <- unlist(lapply(content(req)$tree, "[", "path"), use.names = F)
historic_list0 <- grep(paste0(historic_data_folder,".*.txt"), filelist, value = TRUE)
historic_list1 <- historic_list0[-grep("recal", historic_list0, value = FALSE)]
historic_list2 <- paste0(repo_filepath,historic_list1)

historic_fp_casts <- historic_list2 %>%
  map_df(~ data_frame(x = .x), .id = "cast") %>%
  mutate(cast = as.numeric(cast))

historic_raw_fp <- historic_list2 %>% 
  map_df(~ read_tsv(., 
                    col_types = cols(.default = "c"), col_names = col_names, skip = 2), .id = "cast") %>%
  mutate(cast = as.numeric(cast))

num_historic_casts <- length(historic_fp_casts$cast)
num_pre_2017_casts <- length(historic_fp_casts %>%
  filter(grepl("2014", x) | grepl("2015", x) | grepl("2016", x)) %>%
  pull(x))
num_2017_casts <- 224 # you just have to hard code this to get the cast numbers right because we don't read in 2017 data in till later due to formatting differences

historic_fp_casts <- historic_fp_casts %>%
  mutate(CastID = c(1:num_pre_2017_casts,((num_pre_2017_casts+1) + num_2017_casts):(num_historic_casts + num_2017_casts)))

# Load in all txt files from current year
current_list1 <- grep(paste0(current_year_data_folder,".*.txt"), filelist, value = TRUE)
current_list2 <- paste0(repo_filepath,current_list1)

fp_casts <- current_list2 %>%
  map_df(~ data_frame(x = .x), .id = "cast") %>%
  mutate(cast = as.numeric(cast))
num_current_year_casts <- length(fp_casts$cast)

raw_fp <- current_list2 %>% 
  map_df(~ read_tsv(., 
                    col_types = cols(.default = "c"), col_names = col_names, skip = 2), .id = "cast") %>%
  mutate(cast = as.numeric(cast))

fp_casts <- fp_casts %>%
  mutate(CastID = c((last(historic_fp_casts$cast) + num_2017_casts + 1):((last(historic_fp_casts$cast) + num_2017_casts + 1) + (num_current_year_casts-1))))

historic <- left_join(historic_fp_casts, historic_raw_fp, by = c("cast"))
current <- left_join(fp_casts, raw_fp, by = c("cast"))

#split out column containing filename to get Reservoir and Site data
fp2 <- bind_rows(historic,current) %>%
  rowwise() %>% 
  mutate(Reservoir = unlist(strsplit(x, split='_', fixed=TRUE))[2],
         Site = unlist(strsplit(x, split='_', fixed=TRUE))[3],
         Site = unlist(strsplit(Site, split='.', fixed=TRUE))[1]) %>%
  ungroup() %>%
  mutate(Site = as.numeric(Site))

#check to make sure strsplit function worked for all casts
# check <- subset(fp2, is.na(fp2$Site))
# check <- subset(fp2, fp2$Reservoir == "")
# 
# unique(fp2$Reservoir)
# unique(fp2$Site)

# Rename and select useful columns; drop metrics we don't use or publish such as cell count;
# eliminate shallow depths because of quenching
fp3 <- fp2 %>%
  mutate(DateTime = `Date/Time`, GreenAlgae_ugL = as.numeric(`Green Algae...5`), Bluegreens_ugL = as.numeric(`Bluegreen...6`),
         BrownAlgae_ugL = as.numeric(`Diatoms...7`), MixedAlgae_ugL = as.numeric(`Cryptophyta...8`), YellowSubstances_ugL = as.numeric(`Yellow substances...12`),
         TotalConc_ugL = as.numeric(`Total conc.`), Transmission = as.numeric(`Transmission`), Depth_m = as.numeric(`Depth`), Temp_degC = as.numeric(`Temp. Sample`),
         RFU_525nm = as.numeric(`LED 3 [525 nm]`), RFU_570nm = as.numeric(`LED 4 [570 nm]`), RFU_610nm = as.numeric(`LED 5 [610 nm]`),
         RFU_370nm = as.numeric(`LED 6 [370 nm]`), RFU_590nm = as.numeric(`LED 7 [590 nm]`), RFU_470nm = as.numeric(`LED 8 [470 nm]`),
         Pressure_unit = as.numeric(`Pressure`)) %>%
  select(x,CastID, Reservoir, Site, DateTime, GreenAlgae_ugL, Bluegreens_ugL, BrownAlgae_ugL, MixedAlgae_ugL, YellowSubstances_ugL,
         TotalConc_ugL, Transmission, Depth_m, Temp_degC, RFU_525nm, RFU_570nm, RFU_610nm,
         RFU_370nm, RFU_590nm, RFU_470nm) %>%
  mutate(DateTime = as.POSIXct(as_datetime(DateTime, tz = "", format = "%m/%d/%Y %I:%M:%S %p"))) %>%
  filter(Depth_m >= 0.2) #|> 
  #dplyr::mutate(DateTime = lubridate::force_tz(DateTime, tzone = "EST"),
                #DateTime = lubridate::with_tz(DateTime, tzone = "UTC"))

# #eliminate upcasts 
fp_downcasts <- fp3[0,]
upcasts <- c("20160617_FCR_50.txt","20180903_BVR_50.txt")

for (i in 1:length(unique(fp3$CastID))){

  if(unique(fp3$x)[i] %in% upcasts){}else{
  profile = subset(fp3, CastID == unique(fp3$CastID)[i])

  bottom <- max(profile$Depth_m)

  idx <- which( profile$Depth_m == bottom )
  if( length( idx ) > 0L ) profile <- profile[ seq_len( idx ) , ]

  fp_downcasts <- bind_rows(fp_downcasts, profile)
  }

}

#need to pull in 2017 data here
# Add in 2017 data (different format)
fp2017 <- read_tsv(historic_data_2017) %>%
  mutate(DateTime = datetime, GreenAlgae_ugL = as.numeric(green_ugL), Bluegreens_ugL = as.numeric(cyano_ugL),
         Browns_ugL = as.numeric(diatom_ugL), Mixed_ugL = as.numeric(crypto_ugL), YellowSubstances_ugL = as.numeric(yellow_sub_ugL),
         TotalConc_ugL = as.numeric(total_conc_ugL), Transmission_perc = as.numeric(`transmission_%`), Depth_m = depth_m, Temp_C = as.numeric(temp_sample_C),
         RFU_525nm = as.numeric(LED3_525_nm), RFU_570nm = as.numeric(LED4_570_nm), RFU_610nm = as.numeric(LED5_610_nm),
         RFU_370nm = as.numeric(LED6_370_nm), RFU_590nm = as.numeric(LED7_590_nm), RFU_470nm = as.numeric(LED8_470_nm),
         Pressure_unit = as.numeric(pressure_bar),
         Site = ifelse(Reservoir == "BVR",50,Site)) %>%
  select(Reservoir, Site, DateTime, GreenAlgae_ugL, Bluegreens_ugL, Browns_ugL, Mixed_ugL, YellowSubstances_ugL,
         TotalConc_ugL, Transmission_perc, Depth_m, Temp_C, RFU_525nm, RFU_570nm, RFU_610nm,
         RFU_370nm, RFU_590nm, RFU_470nm, filename) %>%
  filter(Depth_m >= 0.2)  # cut-off for quenching

fp2017$DateTime <- force_tz(fp2017$DateTime, tzone = "America/New_York")

#isolate by cast
fp17v2 <- fp2017 %>%
  mutate(Date = date(DateTime),
         Hour = hour(DateTime)) 

casts <- fp17v2 %>%
  select(Reservoir, Site, Date, Hour) %>%
  distinct() %>%
  mutate(CastID = c((num_pre_2017_casts+1):(num_pre_2017_casts+num_2017_casts)))

fp17v3 <- left_join(fp17v2, casts, by = c("Reservoir","Site","Date","Hour"))

#eliminate upcasts 
fp2017_downcasts <- fp17v3[0,]

for (i in 1:length(unique(fp17v3$CastID))){
  profile = subset(fp17v3, CastID == unique(fp17v3$CastID)[i])
  
  bottom <- max(profile$Depth_m)
  
  idx <- which( profile$Depth_m == bottom ) 
  if( length( idx ) > 0L ) profile <- profile[ seq_len( idx ) , ]
  
  fp2017_downcasts <- bind_rows(fp2017_downcasts, profile)
  
}

#final 2017 dataset
fp2017_final <- fp2017_downcasts %>%
  rename(BrownAlgae_ugL = Browns_ugL,
         MixedAlgae_ugL = Mixed_ugL) %>%
  select(Reservoir, Site, DateTime, CastID, Depth_m, GreenAlgae_ugL, Bluegreens_ugL,
         BrownAlgae_ugL, MixedAlgae_ugL, TotalConc_ugL, YellowSubstances_ugL, 
         Temp_C, Transmission_perc, RFU_370nm, RFU_470nm, RFU_525nm, RFU_570nm,
         RFU_590nm, RFU_610nm)

#prep other data for merge
fp4 <- fp_downcasts %>%
  rename(Temp_C = Temp_degC,
         Transmission_perc = Transmission) %>%
  select(Reservoir, Site, DateTime, CastID, Depth_m, GreenAlgae_ugL, Bluegreens_ugL,
         BrownAlgae_ugL, MixedAlgae_ugL, TotalConc_ugL, YellowSubstances_ugL, 
         Temp_C, Transmission_perc, RFU_370nm, RFU_470nm, RFU_525nm, RFU_570nm,
         RFU_590nm, RFU_610nm)

fp5 <- bind_rows(fp4, fp2017_final) %>%
  arrange(DateTime, CastID, Reservoir, Site, Depth_m)


#trim casts to eliminate poor readings due to sediment interference at bottom of reservoir
#for our purposes, we consider the "max depth" of each reservoir to be:
#FCR = 9.5 m; BVR = 10.0 m; CCR = 21 m 

fp6 = fp5[FALSE,]

for (i in 1:length(unique(fp5$CastID))){
  profile = subset(fp5, CastID == unique(fp5$CastID)[i])
  if(profile$Reservoir[1] == "FCR"){
    if(profile$Site[1] == 50){
      profile_trim <- profile %>% filter(Depth_m <= 9.5)
    }
    if(profile$Site[1] == 45){
      profile_trim <- profile %>% filter(Depth_m <= 8.5)
    }
    if(profile$Site[1] == 40){
      profile_trim <- profile %>% filter(Depth_m <= 8.5)
    }
    if(profile$Site[1] == 30){
      profile_trim <- profile %>% filter(Depth_m <= 6.5)
    }
    if(profile$Site[1] == 20){
      profile_trim <- profile %>% filter(Depth_m <= 4.5)
    }
    if(profile$Site[1] == 10){
      profile_trim <- profile %>% filter(Depth_m <= 3.5)
    }
  } else if (profile$Reservoir[1] == "CCR"){
    profile_trim <- profile %>% filter(Depth_m <= 21)
  } else if (profile$Reservoir[1] == "BVR"){
    profile_trim <- profile %>% filter(Depth_m <= 10)
  } else if (profile$Reservoir[1] == "GWR"){
    profile_trim <- profile %>% filter(Depth_m <= 14)
  } else if (profile$Reservoir[1] == "SHR"){
    profile_trim <- profile %>% filter(Depth_m <= 60)
  }
  fp6 <- bind_rows(fp6, profile_trim)
} 

#ADD FLAGS

fp_final <- fp6 %>%
  mutate(Flag_GreenAlgae_ugL = 0,
         Flag_Bluegreens_ugL = 0,
         Flag_BrownAlgae_ugL = 0,
         Flag_MixedAlgae_ugL = 0,
         Flag_YellowSubstances_ugL = 0,
         Flag_TotalConc_ugL = 0,
         Flag_Temp_C = 0, # example: ifelse(date(DateTime) %in% bad_temp_days,2,0),
         Flag_Transmission_perc = ifelse(Transmission_perc < 0, 3, 0),
         Flag_RFU_525nm = ifelse(RFU_525nm < 0, 5, 0),
         Flag_RFU_570nm = ifelse(RFU_570nm < 0, 5, 0),
         Flag_RFU_610nm = ifelse(RFU_610nm < 0, 5, 0),
         Flag_RFU_370nm = ifelse(RFU_370nm < 0, 5, 0),
         Flag_RFU_590nm = ifelse(RFU_590nm < 0, 5, 0),
         Flag_RFU_470nm = ifelse(RFU_470nm < 0, 5, 0)) 


### 4. Take out values based on the Maintenance Log 

#maintenance_file <- 'Data/DataNotYetUploadedToEDI/FluoroProbe/Maintenance_Log_FluoroProbe.csv'

log_read <- read_csv(maintenance_file, col_types = cols(
  .default = col_character(),
  TIMESTAMP_start = col_datetime("%Y-%m-%d %H:%M:%S%*"),
  TIMESTAMP_end = col_datetime("%Y-%m-%d %H:%M:%S%*"),
  flag = col_integer()
))

log <- log_read

### identify the date subsetting for the data
if (!is.null(start_date)){
  fp_final <- fp_final %>% 
    filter(DateTime >= start_date)
  log <- log %>%
    filter(TIMESTAMP_start <= end_date)
}

if(!is.null(end_date)){
  fp_final <- fp_final %>% 
    filter(DateTime <= end_date)
  log <- log %>%
    filter(TIMESTAMP_end >= start_date)
}

if (nrow(log) > 0){
  
for(i in 1:nrow(log)){
  ### Assign variables based on lines in the maintenance log.

  ### get start and end time of one maintenance event
  start <- log$TIMESTAMP_start[i]
  end <- log$TIMESTAMP_end[i]

  ### Get the Reservoir Name

  Reservoir <- log$Reservoir[i]

  ### Get the Site Number

  Site <- as.numeric(log$Site[i])

  ### Get the depth if it is not NA

  if(!is.na(log$Depth[i])){
    Depth <- as.numeric(log$new_value[i]) 
  }

  ### Get the Maintenance Flag

  flag <- log$flag[i]

  ### Get the new value for a column or an offset. If it is not an NA

  if(!is.na(log$update_value[i])){

    update_value <- as.numeric(log$update_value[i])
  }


  ### Get the names of the columns affected by maintenance

  colname_start <- log$start_parameter[i]
  colname_end <- log$end_parameter[i]

  ### if it is only one parameter parameter then only one column will be selected

  if(is.na(colname_start)){

    maintenance_cols <- colnames(fp_final%>%select(colname_end))

  }else if(is.na(colname_end)){

    maintenance_cols <- colnames(fp_final%>%select(colname_start))

  }else{
    maintenance_cols <- colnames(fp_final%>%select(colname_start:colname_end))
  }
  
  # remove flag and notes cols in the maint_col vector
  maintenance_cols <- maintenance_cols[!grepl('Flag', maintenance_cols)]
  maintenance_cols <- maintenance_cols[!grepl('Note', maintenance_cols)]

  if(is.na(end)){
    # If there the maintenance is on going then the columns will be removed until
    # and end date is added
    Time <- fp_final$DateTime[fp_final$DateTime >= start] 

  }else if (is.na(start)){
    # If there is only an end date change columns from beginning of data frame until end date
    Time <- fp_final$DateTime[fp_final$DateTime <= end] 

  }else {

    Time <- fp_final$DateTime[(fp_final$DateTime >= start & fp_final$DateTime <= end)] 
  }

  ### This is where information in the maintenance log gets removed.
  # UPDATE THE IF STATEMENTS BASED ON THE NECESSARY CRITERIA FROM THE MAINTENANCE LOG

  # replace relevant data with NAs and set flags while maintenance was in effect
  if(flag %in% c(1)){
    # Data re-calibrated by bbe moldaenke post collection

    fp_final[c(which(fp_final$Reservoir == Reservoir & fp_final$Site == Site & fp_final$DateTime %in% Time)), paste0("Flag_",maintenance_cols)] <- flag
    
  }else if (flag %in% c(2)){ 
    ## Instrument error
    
    fp_final[c(which(fp_final$Reservoir == Reservoir & fp_final$Site == Site & fp_final$DateTime %in% Time)),maintenance_cols] <- NA
    fp_final[c(which(fp_final$Reservoir == Reservoir & fp_final$Site == Site & fp_final$DateTime %in% Time)), paste0("Flag_",maintenance_cols)] <- flag
    
  }else if (flag %in% c(4)){ 
    ## Data suspect due to poor calibration
    
    fp_final[c(which(fp_final$Reservoir == Reservoir & fp_final$Site == Site & fp_final$DateTime %in% Time)), paste0("Flag_",maintenance_cols)] <- flag
    
  }else
  {
    warning("Flag not coded in the L1 script. See Austin or Adrienne")
  }
} # end for loop
} # end conditional statement

### END MAINTENANCE LOG CODE ###

## Subset L1 file 

# subset to make the L1 file 

if (!is.null(start_date)){
  #force tz check
  start_date <- force_tz(as.POSIXct(start_date), tzone = "America/New_York")
  
  #final$DateTime <- as.character(format(final$DateTime)) # convert DateTime to character
  
  fp_final <- fp_final %>%
    filter(DateTime >= start_date)
  
}

if(!is.null(end_date)){
  #force tz check
  end_date <- force_tz(as.POSIXct(end_date), tzone = "America/New_York")
  
  #fp_final$DateTime <- as.character(format(fp_final$DateTime)) # convert DateTime to character
  
  fp_final <- fp_final %>%
    filter(DateTime <= end_date)
  
}


# save the file or if Null return the file

if(is.null(out_file)){

   return(fp_final)

}else{
  
    write.csv(fp_final, out_file, row.names = FALSE)
}



}

