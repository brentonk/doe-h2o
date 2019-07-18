#!/bin/bash
#SBATCH --ntasks=1
#SBATCH --time=3:00:00
#SBATCH --mem=24G
#SBATCH --array=1816-2012
#SBATCH --output=logs/predict/%a.out

echo "SLURM_JOBID:" $SLURM_JOBID
echo "SLURM_ARRAY_TASK_ID:" $SLURM_ARRAY_TASK_ID
echo "SLURM_ARRAY_JOB_ID:" $SLURM_ARRAY_JOB_ID

mkdir -p results/predict

INFILE=results/predict/${SLURM_ARRAY_TASK_ID}-in.csv
OUTFILE=results/predict/${SLURM_ARRAY_TASK_ID}-out.csv

echo "Input file:" $INFILE
echo "Output file:" $OUTFILE

grep -P "^(?:year|${SLURM_ARRAY_TASK_ID})" results/data-dir-dyad.csv > $INFILE
wc $INFILE

java -cp results/mojo/h2o-genmodel.jar hex.genmodel.tools.PredictCsv \
        --mojo results/mojo/doe_ensemble.zip \
        --input $INFILE \
        --output $OUTFILE \
        --decimal
