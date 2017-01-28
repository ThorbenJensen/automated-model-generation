

setwd("/Users/thorbenje/phd/models/chapter4/behaviorSearch/")
#dir()

experiment <- "schwarz_flexible"

bestHistory               <- read.csv(paste(experiment, ".bestHistory.csv"             , sep=""))
finalBests                <- read.csv(paste(experiment, ".finalBests.csv"              , sep=""))
modelRunHistory           <- read.csv(paste(experiment, ".modelRunHistory.csv"         , sep=""))
objectiveFunctionHistory  <- read.csv(paste(experiment, ".objectiveFunctionHistory.csv", sep=""))


View(bestHistory)
View(finalBests)
View(modelRunHistory)
View(objectiveFunctionHistory)