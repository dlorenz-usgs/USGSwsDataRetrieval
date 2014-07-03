#' Data Import from Water Quality Portal
#'
#' Imports data from Water Quality Portal web service. This function gets the data from here: \url{http://www.waterqualitydata.us}. This function is more general than getQWData
#' because it allows for other agencies rather than the USGS.  Therefore, the 5-digit parameter code cannot be used.
#' Instead, this function uses characteristicName.  A complete list can be found here \url{http://www.waterqualitydata.us/Codes/Characteristicname}
#'
#' @param siteNumber string site number.  If USGS, it should be in the form :'USGS-XXXXXXXXX...'
#' @param characteristicName string
#' @param StartDate string starting date for data retrieval in the form YYYY-MM-DD.
#' @param EndDate string ending date for data retrieval in the form YYYY-MM-DD.
#' @keywords data import WQP web service
#' @return retval dataframe with first column dateTime, and at least one qualifier and value columns
#' (subsequent qualifier/value columns could follow depending on requested parameter codes)
#' @export
#' @import RCurl
#' @examples
#' # These examples require an internet connection to run
#' getWQPData('USGS-01594440','Chloride', '', '')
#' getWQPData('WIDNR_WQX-10032762','Specific conductance', '', '')
getWQPData <- function(siteNumber,characteristicName,StartDate,EndDate){

  
  if (nzchar(StartDate)){
    StartDate <- format(as.Date(StartDate), format="%m-%d-%Y")
  }
  if (nzchar(EndDate)){
    EndDate <- format(as.Date(EndDate), format="%m-%d-%Y")
  }
  
  characteristicName <- URLencode(characteristicName)
  
  baseURL <- "http://www.waterqualitydata.us/Result/search?siteid="
  url <- paste(baseURL,
               siteNumber,
               "&characteristicName=",
               characteristicName,   # to get multi-parameters, use a semicolen 
               "&startDateLo=",
               StartDate,
               "&startDateHi=",
               EndDate,
               "&countrycode=US&mimeType=tsv",sep = "")
  h <- basicHeaderGatherer()
  doc <- getURI(url, headerfunction = h$update)
  numToBeReturned <- as.numeric(h$value()["Total-Result-Count"])
  
  suppressWarnings(retval <- read.delim(url, header = TRUE, quote="\"", dec=".", sep='\t', colClasses=c('character'), fill = TRUE))
  
  qualifier <- ifelse((retval$ResultDetectionConditionText == "Not Detected" | 
                         retval$ResultDetectionConditionText == "Detected Not Quantified" |
                         retval$ResultMeasureValue < retval$DetectionQuantitationLimitMeasure.MeasureValue),"<","")
  
  correctedData<-ifelse((nchar(qualifier)==0),retval$ResultMeasureValue,retval$DetectionQuantitationLimitMeasure.MeasureValue)
  test <- data.frame(retval$CharacteristicName)
  
  #   test$dateTime <- as.POSIXct(strptime(paste(retval$ActivityStartDate,retval$ActivityStartTime.Time,sep=" "), "%Y-%m-%d %H:%M:%S"))
  test$dateTime <- as.Date(retval$ActivityStartDate, "%Y-%m-%d")
  
  originalLength <- nrow(test)
  
  if (!is.na(numToBeReturned)){
    if(originalLength != numToBeReturned) warning(numToBeReturned, " sample results were expected, ", originalLength, " were returned")
    
    test$qualifier <- qualifier
    test$value <- as.numeric(correctedData)
    
    test <- test[!is.na(test$dateTime),]
    newLength <- nrow(test)
    if (originalLength != newLength){
      numberRemoved <- originalLength - newLength
      warningMessage <- paste(numberRemoved, " rows removed because no date was specified", sep="")
      warning(warningMessage)
    }
    
    colnames(test)<- c("CharacteristicName","dateTime","qualifier","value")
    data <- reshape(test, idvar="dateTime", timevar = "CharacteristicName", direction="wide")    
    data$dateTime <- format(data$dateTime, "%Y-%m-%d")
    data$dateTime <- as.Date(data$dateTime)
    return(data)
  } else {
    warning("No data retrieved")
  }
  
}
