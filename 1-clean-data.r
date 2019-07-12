### Merge and clean the National Material Capabilities and Militarized
### Interstate Disputes datasets

library("tidyverse")
library("assertr")

sessionInfo()


raw_nmc <- read_csv("data/NMC_5_0.csv", na = "-9")
raw_mida <- read_csv("data/gml-mida-2.1.csv",
                     col_types = cols(link1 = col_character(),
                                      link2 = col_character(),
                                      link3 = col_character(),
                                      dispnum4 = col_integer()),
                     na = "-9")
raw_midb <- read_csv("data/gml-midb-2.1.csv",
                     col_types = cols(dispnum4 = col_integer()),
                     na = c("-9", "NA"))


## Sanity checks on input data
##
## Removing one weird case where sidea is missing (MID #4455; this is a
## multilateral MID so it won't matter anyway for the analysis)
nmc_components <- c("milex", "milper", "irst", "pec", "tpop", "upop")
data_nmc <- raw_nmc %>%
    select(-stateabb, -version) %>%
    assert(not_na, ccode, year) %>%
    assert(within_bounds(0, Inf), one_of(nmc_components)) %>%
    assert(within_bounds(0, 1), cinc)
data_mida <- raw_mida %>%
    filter(dispnum3 != 4455) %>%
    assert(not_na, dispnum3, styear)
data_midb <- raw_midb %>%
    rename(dispnum3 = dispnum) %>%
    filter(dispnum3 != 4455) %>%
    assert(not_na, dispnum3, ccode, sidea)

## Display missingness in each NMC component variable
cat("\nProportion missing for each NMC component in full NMC data:\n")
data_nmc %>%
    summarise_at(vars(one_of(nmc_components, "cinc")),
                 ~ mean(is.na(.))) %>%
    print()

## Add the proportion of the yearly total for each non-missing CINC component
data_nmc <- data_nmc %>%
    gather(key = component, value = raw, -ccode, -year) %>%
    group_by(year, component) %>%
    mutate(yearly_total = sum(raw, na.rm = TRUE),
           prop = raw / yearly_total) %>%
    ungroup() %>%
    assert(within_bounds(0, 1), prop) %>%
    select(-yearly_total) %>%
    gather(key = type, value = value, raw, prop) %>%
    mutate(variable = paste0(component, "_", type)) %>%
    filter(!(component == "cinc" & type == "prop")) %>%
    select(-component, -type) %>%
    spread(key = variable, value = value) %>%
    rename(cinc = cinc_raw)

## Check on the correlation between the generated yearly components and the
## provided CINC score (ideally should be 1)
cat("\nCorrelation of generated yearly components and provided CINC:\n")
data_nmc %>%
    filter(complete.cases(.)) %>%
    mutate(nmc_sum = irst_prop + milex_prop + milper_prop + pec_prop +
               tpop_prop + upop_prop) %>%
    with(., cor(cinc, nmc_sum)) %>%
    sprintf("%.8f", .) %>%
    print()

## Reduce to MIDs where (a) there is just one state on each side and (b) the
## dispute ends in victory, yield by one side, or stalemate
##
## Using the participant-level data to make the list of cases, since there is
## some incommensuracy between the mida and midb data here
bilateral_cases <- data_midb %>%
    group_by(dispnum3) %>%
    summarise(num_a = sum(sidea),
              num_b = n() - num_a) %>%
    filter(num_a == 1, num_b == 1) %>%
    pull(dispnum3)
data_mida <- data_mida %>%
    filter(dispnum3 %in% !! bilateral_cases,
           outcome %in% 1:5)
cat("\nNumber of disputes in training data:\n")
print(nrow(data_mida))

## Code one side yielding as victory by the other
data_mida <- data_mida %>%
    mutate(outcome = case_when(
               outcome %in% c(1, 4) ~ "VictoryA",
               outcome %in% c(2, 3) ~ "VictoryB",
               outcome == 5 ~ "Stalemate"
           )) %>%
    assert(not_na, outcome)
cat("\nDistribution of outcomes in training data:\n")
print(tab_out <- table(data_mida$outcome))
print(prop.table(tab_out))

## Extract appropriate country codes for side a and side b from
## participant-level data
data_midb <- data_midb %>%
    filter(dispnum3 %in% !! data_mida$dispnum3) %>%
    verify(nrow(.) == 2 * nrow(data_mida)) %>%
    group_by(dispnum3) %>%
    summarise(ccode_a = ccode[sidea == 1],
              ccode_b = ccode[sidea == 0]) %>%
    verify(nrow(.) == nrow(data_mida)) %>%
    assert(not_na, everything())

## Merge side-specific country codes into MID data
data_train <- data_mida %>%
    select(dispnum3, year = styear, outcome) %>%
    left_join(data_midb, by = "dispnum3") %>%
    assert(not_na, everything())

## Merge each side's material capabilities into training data
data_nmc_a <- data_nmc_b <- data_nmc
names(data_nmc_a) <- if_else(names(data_nmc_a) == "year",
                             names(data_nmc_a),
                             paste0(names(data_nmc_a), "_a"))
names(data_nmc_b) <- if_else(names(data_nmc_b) == "year",
                             names(data_nmc_b),
                             paste0(names(data_nmc_b), "_b"))
data_train <- data_train %>%
    left_join(data_nmc_a, by = c("ccode_a", "year")) %>%
    left_join(data_nmc_b, by = c("ccode_b", "year")) %>%
    assert(not_na, dispnum3, year, outcome, ccode_a, ccode_b)

## Display missingness in each variable for training data
cat("\nProportion missing in each variable in training data:\n")
data_train %>%
    summarise_each(~ mean(is.na(.))) %>%
    gather(key = variable, value = prop_missing) %>%
    print(n = Inf)
cat("\nProportion of complete cases in training data:\n")
print(mean(complete.cases(data_train)))


if (!dir.exists("results")) {
    dir.create("results")
    cat("\nCreated subdirectory 'results'\n")
}
write_csv(data_train, path = "results/clean-data.csv")
