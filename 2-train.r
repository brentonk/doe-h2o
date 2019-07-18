### Train ensemble

library("tidyverse")
library("caret")
library("h2o")

sessionInfo()


data_train <- read_csv("results/data-train.csv")


## Create cross-validation folds
##
## Doing this in advance (1) to ensure same folds across models, as needed for
## the super learner; and (2) to use caret's functionality which ensures class
## balance as much as possible
set.seed(9248)
folds <- createFolds(y = data_train$outcome,
                     k = 10,
                     list = FALSE)
data_train <- data_train %>%
    add_column(fold = !! folds) %>%
    select(-outcome, everything(), outcome)
cat("\nObservations per fold:\n")
print(with(data_train, table(fold)))
print(with(data_train, table(fold, outcome)))

## Set up h2o cluster
h2o.init(nthreads = -1, max_mem_size = "16G")
h2o.no_progress()
data_train$outcome <- factor(data_train$outcome,
                             levels = c("VictoryB", "Stalemate", "VictoryA"))
stopifnot(all(!is.na(data_train$outcome)))
h2o_data_train <- as.h2o(data_train, destination_frame = "data_train")
x_names <- setdiff(names(h2o_data_train), c("outcome", "fold"))
cat("\nTraining variables:\n")
print(x_names)


## -----------------------------------------------------------------------------
## Candidate model training
## -----------------------------------------------------------------------------

## To display memory usage
print_free_mem <- function() {
    cat("\nNo. objects in h2o:", length(h2o.ls()[["key"]]), "\n\n")
    print(dim(h2o.ls()))
    x <- h2o.clusterStatus()
    used <- as.numeric(x$mem_value_size)
    cat("Memory:",
        sprintf("%.2f GB used", used * 1024^-3),
        "\n")
    invisible(used)
}

print_free_mem()

cat("\nTraining random forests", date(), "\n")

fit_rf <- h2o.grid(algorithm = "drf",
                   grid_id = "rf_grid",
                   x = x_names,
                   y = "outcome",
                   training_frame = h2o_data_train,
                   fold_column = "fold",
                   keep_cross_validation_predictions = TRUE,
                   seed = 94257,
                   balance_classes = FALSE,
                   ntrees = 256,
                   hyper_params = list(
                       max_depth = 2:8,
                       mtries = 2:10,
                       sample_rate = (6:19) / 20
                   ),
                   search_criteria = list(
                       strategy = "RandomDiscrete",
                       max_models = 200,
                       seed = 81865
                   ))
print(fit_rf)
print_free_mem()

cat("\nTraining gradient boosting machines", date(), "\n")

fit_gbm <- h2o.grid(algorithm = "gbm",
                    grid_id = "gbm_grid",
                    x = x_names,
                    y = "outcome",
                    training_frame = h2o_data_train,
                    fold_column = "fold",
                    keep_cross_validation_predictions = TRUE,
                    seed = 34813,
                    balance_classes = FALSE,
                    stopping_rounds = 20,
                    hyper_params = list(
                        ntrees = c(64, 128, 256),
                        learn_rate = (2:7) / 100,
                        sample_rate = (15:20) / 20
                    ),
                    search_criteria = list(
                        strategy = "Cartesian"
                    ))
print(fit_gbm)
print_free_mem()

cat("\nTraining GLMs", date(), "\n")

fit_glm <- h2o.grid(algorithm = "glm",
                    grid_id = "glm_grid",
                    x = x_names,
                    y = "outcome",
                    training_frame = h2o_data_train,
                    fold_column = "fold",
                    keep_cross_validation_predictions = TRUE,
                    seed = 52175,
                    family = "multinomial",
                    standardize = TRUE,
                    lambda_search = TRUE,
                    max_iterations = 1000,
                    hyper_params = list(
                        alpha = seq(0, 1, by = 0.01)
                    ),
                    search_criteria = list(
                        strategy = "Cartesian"
                    ))
print(fit_glm)
print_free_mem()


## -----------------------------------------------------------------------------
## Ensemble training
## -----------------------------------------------------------------------------

fit_ensemble <- h2o.stackedEnsemble(x = x_names,
                                    y = "outcome",
                                    training_frame = h2o_data_train,
                                    model_id = "doe_ensemble",
                                    base_models = c(fit_rf@model_ids,
                                                    fit_gbm@model_ids,
                                                    fit_glm@model_ids),
                                    metalearner_nfolds = 10,
                                    metalearner_fold_assignment = "Stratified",
                                    seed = 92446)
print(fit_ensemble)

for (output_dir in c("results/h2o", "results/mojo")) {
    if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE)
        cat("\nCreated directory", output_dir, "\n")
    }
}

## Save MOJO for reproducible scoring outside of h2o environment
h2o.download_mojo(model = fit_ensemble,
                  path = "results/mojo/",
                  get_genmodel_jar = TRUE)

## Save ensemble for loading back into h2o later (mostly as a backup since
## preferably we'll use the MOJO for scoring)
h2o.saveModel(object = fit_ensemble,
              path = "results/h2o/",
              force = TRUE)
