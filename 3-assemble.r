### Assemble directed dyad predictions into a single data frame, then calculate
### the undirected scores

library("tidyverse")
library("assertr")
library("foreach")

sessionInfo()


## Load up the results from each individual year scoring, validate, and extract
doe_dir_dyad <- foreach (yr = 1816:2012, .combine = "rbind") %do% {
    dat_in <- suppressMessages(read_csv(paste0("results/predict/", yr, "-in.csv")))
    dat_out <- suppressMessages(read_csv(paste0("results/predict/", yr, "-out.csv")))
    if (nrow(dat_in) != nrow(dat_out)) {
        stop("Unequal row numbers in year ", yr)
    }
    cbind(dat_in, dat_out) %>%
        as_tibble() %>%
        select(year, ccode_a, ccode_b, VictoryA, Stalemate, VictoryB)
}

## Clean up typing to ensure the written CSVs look how we'd want
doe_dir_dyad <- doe_dir_dyad %>%
    mutate_at(vars(one_of("year", "ccode_a", "ccode_b")), ~ as.integer(.)) %>%
    assert(not_na, everything()) %>%
    verify(all.equal(Stalemate + VictoryA + VictoryB, rep(1.0, nrow(.)))) %>%
    arrange(year, ccode_a, ccode_b)

## Create undirected data by averaging the directed scores
doe_dyad <- doe_dir_dyad %>%
    mutate(ccode_min = pmin(ccode_a, ccode_b),
           ccode_max = pmax(ccode_a, ccode_b)) %>%
    verify(ccode_min < ccode_max) %>%
    select(-ccode_a, -ccode_b) %>%
    group_by(ccode_min, ccode_max, year) %>%
    mutate(count = n()) %>%
    verify(count == 2) %>%
    summarise_at(vars(one_of("VictoryA", "Stalemate", "VictoryB")),
                 ~ mean(.))
doe_dyad_a <- rename(doe_dyad, ccode_a = ccode_min, ccode_b = ccode_max)
doe_dyad_b <- rename(doe_dyad, ccode_a = ccode_max, ccode_b = ccode_min)
doe_dyad <- rbind(doe_dyad_a, doe_dyad_b) %>%
    verify(all.equal(Stalemate + VictoryA + VictoryB, rep(1.0, nrow(.)))) %>%
    verify(!duplicated(paste(year, ccode_a, ccode_b))) %>%
    arrange(year, ccode_a, ccode_b)

## Double check that the directed and undirected datasets have the same
## structure and organization
stopifnot(nrow(doe_dir_dyad) == nrow(doe_dyad))
stopifnot(all(doe_dir_dyad$year == doe_dyad$year))
stopifnot(all(doe_dir_dyad$ccode_a == doe_dyad$ccode_a))
stopifnot(all(doe_dir_dyad$ccode_b == doe_dyad$ccode_b))

## Look at correlations between the directed and undirected versions
cat("\nCorrelation between directed and undirected, VictoryA:",
    sprintf("%.3f", cor(doe_dir_dyad$VictoryA, doe_dyad$VictoryA)),
    "\nCorrelation between directed and undirected, Stalemate:",
    sprintf("%.3f", cor(doe_dir_dyad$Stalemate, doe_dyad$Stalemate)),
    "\nCorrelation between directed and undirected, VictoryB:",
    sprintf("%.3f", cor(doe_dir_dyad$VictoryB, doe_dyad$VictoryB)),
    "\n")


write_csv(doe_dir_dyad, path = "results/doe-dir-dyad-2.0.csv")
write_csv(doe_dyad, path = "results/doe-dyad-2.0.csv")
