# To run an R script and save logs appropriately
R = mkdir -p logs && Rscript --verbose --vanilla $(1) > logs/$(1:.r=.out) 2>&1

# Files split up by year used for prediction
years = $(shell seq 1816 2012)
year_files = $(addprefix results/predict/,$(years))
predict_in = $(addsuffix -in.csv,$(year_files))
predict_out = $(addsuffix -out.csv,$(year_files))

# Numbered R scripts
download_r = 0-download.r
clean_data_r = 1-clean-data.r
train_r = 2-train.r
assemble_r = 3-assemble.r
compare_to_v1_r = 4-compare-to-v1.r
prl_r = 5-prl.r


all : results/doe-dir-dyad-2.0.csv results/doe-dyad-2.0.csv

results/doe-dir-dyad-2.0.csv results/doe-dyad-2.0.csv : $(assemble_r) $(predict_in) $(predict_out)
	$(call R, $(assemble_r))

results/predict/%-out.csv : results/predict/%-in.csv results/mojo/h2o-genmodel.jar results/mojo/doe_ensemble.zip
	java -cp results/mojo/h2o-genmodel.jar hex.genmodel.tools.PredictCsv \
		--mojo results/mojo/doe_ensemble.zip \
		--input $< \
		--output $@ \
		--decimal

results/predict/%-in.csv : results/data-dir-dyad.csv
	mkdir -p results/predict && grep -P "^(?:year|$*)" results/data-dir-dyad.csv > $@

results/mojo/doe_ensemble.zip results/mojo/h2o-genmodel.jar results/h2o/doe_ensemble : $(train_r)  results/data-train.csv
	$(call R, $(train_r))

results/data-dir-dyad.csv results/data-train.csv : $(clean_data_r) data/NMC_5_0.csv data/gml-mida-2.1.csv data/gml-midb-2.1.csv
	$(call R, $(clean_data_r))

data/NMC_5_0.csv data/gml-mida-2.1.csv data/gml-midb-2.1.csv data/doe-dir-dyad-1.0.csv : | $(download_r)
	$(call R, $(download_r))

.PHONY : extras
extras :
	$(call R, $(compare_to_v1_r))
	$(call R, $(prl_r))

.PHONY : clean
clean :
	rm -rf results/*
	rm -rf logs/*
