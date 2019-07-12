# To run an R script and save logs appropriately
R = mkdir -p logs && Rscript --verbose --vanilla $(1) > logs/$(1:.r=.out) 2>&1

# Numbered R scripts
download_r = 0-download.r
clean_data_r = 1-clean-data.r


all : results/clean-data.csv

results/clean-data.csv : $(clean_data_r) data/NMC_5_0.csv data/gml-mida-2.1.csv data/gml-midb-2.1.csv
	$(call R, $(clean_data_r))

data/NMC_5_0.csv data/gml-mida-2.1.csv data/gml-midb-2.1.csv data/doe-dir-dyad.csv : | $(download_r)
	$(call R, $(download_r))

.PHONY : clean
clean :
	rm -rf results/*
	rm -rf logs/*
