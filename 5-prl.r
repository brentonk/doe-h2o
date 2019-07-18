### Calculate the proportional reduction in loss in the current model, as well
### as from an ordered logit on just the capability ratio

library("tidyverse")
library("caret")
library("h2o")

sessionInfo()


h2o.init(nthreads = -1, max_mem_size = "16G")
fit_ensemble <- h2o.loadModel("results/h2o/doe_ensemble")

data_train <- read_csv("results/data-train.csv")
data_train$outcome <- factor(data_train$outcome,
                             levels = c("VictoryB", "Stalemate", "VictoryA"))


set.seed(99122)

## Null model
fit_null <- train(outcome ~ capratio_a,
                  data = data_train,
                  method = "null",
                  metric = "logLoss",
                  maximize = FALSE,
                  trControl = trainControl(
                      method = "cv",
                      number = 10,
                      classProbs = TRUE,
                      summaryFunction = mnLogLoss
                  ))
loss_null <- fit_null$results$logLoss
cat("\nLog loss of null model:",
    sprintf("%.3f", loss_null), "\n")

## Ordered logit on capability ratio
fit_polr <- train(outcome ~ capratio_a,
                  data = data_train,
                  method = "polr",
                  tuneGrid = data.frame(method = "logistic"),
                  metric = "logLoss",
                  maximize = FALSE,
                  trControl = trainControl(
                      method = "cv",
                      number = 10,
                      classProbs = TRUE,
                      summaryFunction = mnLogLoss
                  ))
loss_polr <- fit_polr$results$logLoss
cat("\nLog loss of capability ratio model:",
    sprintf("%.3f", loss_polr),
    "\nPRL of capability ratio model:",
    sprintf("%.3f", (loss_null - loss_polr) / loss_null),
    "\n")

## Super learner
loss_ensemble <- h2o.logloss(fit_ensemble, xval = TRUE)
cat("\nLog loss of ensemble:",
    sprintf("%.3f", loss_ensemble),
    "\nPRL of ensemble:",
    sprintf("%.3f", (loss_null - loss_ensemble) / loss_null),
    "\n")
