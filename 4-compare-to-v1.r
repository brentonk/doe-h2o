### Compare the current version of DOE to the original one

library("tidyverse")
library("assertr")

sessionInfo()


doe_v1 <- read_csv("data/doe-dir-dyad-1.0.csv") %>%
    rename(VictoryA_v1 = VictoryA,
           Stalemate_v1 = Stalemate,
           VictoryB_v1 = VictoryB) %>%
    assert(not_na, everything())
doe_v2 <- read_csv("results/doe-dir-dyad-2.0.csv") %>%
    rename(VictoryA_v2 = pr_win_a,
           Stalemate_v2 = pr_stalemate,
           VictoryB_v2 = pr_win_b) %>%
    assert(not_na, everything())


## Identify and assemble all directed dyads available in both versions of the
## DOE score data
doe_both <- inner_join(doe_v1, doe_v2, by = c("year", "ccode_a", "ccode_b"))
cat("\nNumber of observations common to DOE v1.0 and v2.0:",
    nrow(doe_both), "\n")

## Extract matrices to calculate canonical correlations
mat_v1 <- doe_both %>% select(VictoryA_v1, VictoryB_v1) %>% data.matrix()
mat_v2 <- doe_both %>% select(VictoryA_v2, VictoryB_v2) %>% data.matrix()
stopifnot(all(dim(mat_v1) == dim(mat_v2)))
cc_v1_v2 <- cancor(mat_v1, mat_v2)
cat("\nCanonical correlation between DOE v1.0 and v2.0:",
    sprintf("%.3f", cc_v1_v2[["cor"]][1]),
    "\n")
