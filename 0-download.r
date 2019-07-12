### Download relevant datasets

library("tidyverse")

sessionInfo()


if (!dir.exists("data")) {
    dir.create("data")
    cat("\nCreated subdirectory 'data'\n")
}

## National Material Capabilities, version 5.0
nmc_file <- "data/NMC_5_0.csv"
if (!file.exists(nmc_file)) {
    nmc_tmp <- tempfile()
    download.file(url = "http://www.correlatesofwar.org/data-sets/national-material-capabilities/nmc-v5-1/at_download/file",
                  destfile = nmc_tmp)
    unzip(zipfile = nmc_tmp,
          files = "NMC_5_0.csv",
          exdir = "data")
    cat("\nWrote file", nmc_file, "\n")
} else {
    cat("\n", nmc_file, "already exists; skipping\n")
}

## Gibler-Miller-Little Militarized Interstate Disputes, version 2.1
mida_file <- "data/gml-mida-2.1.csv"
midb_file <- "data/gml-midb-2.1.csv"
if (!all(file.exists(mida_file, midb_file))) {
    mid_tmp <- tempfile()
    download.file(url = "http://bit.ly/gml_mid_21",
                  destfile = mid_tmp)
    unzip(zipfile = mid_tmp,
          files = c("gml-mida-2.1.csv", "gml-midb-2.1.csv"),
          exdir = "data")
    cat("\nWrote file", mida_file, "\n")
    cat("Wrote file", midb_file, "\n")
} else {
    cat("\n", mida_file, "already exists; skipping\n")
    cat(midb_file, "already exists; skipping\n")
}

## DOE 1.0
doe_file <- "data/doe-dir-dyad.csv"
if (!file.exists(doe_file)) {
    download.file(url = "https://dataverse.harvard.edu/api/access/datafile/:persistentId?persistentId=doi:10.7910/DVN/FPYKTP/QBDDN6&format=original",
                  destfile = doe_file)
    cat("\nWrote file", doe_file, "\n")
} else {
    cat("\n", doe_file, "already exists; skipping\n")
}
