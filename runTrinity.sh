#!/bin/bash

# Created by Alastair Ludington (alastair.j.lud@gmail.com)
# - editied by Jimmy Breen (jimmymbreen@gmail.com)

# change this to whatever resources you would like
THREADS=24

# For this pipeline we created a TRINITY conda environment called "TRINITY_env"
conda create -n TRINITY_env -c bioconda trinity

# .....but we also need to define the utilities directory where some helper tools live
# 
TRINITY_UTIL=/home/a1645424/fastdir/virtualenvs/.conda/envs/TRINITY_env/opt/trinity-2.8.4/util

# base is current working directory
BASE=`pwd`

# FASTQs are raw sequences here but I would suggest you trim before 
# - these are the fq.gz files
FASTQ=${BASE}/data

# Outdirectories for results
OUT_DIR=${BASE}/trinity/trinity_nonTrimmed

# Create the outdir
mkdir -pv ${OUT_DIR}

###################################################################################################
## Trinity Command

# acivate the virtual env
source activate TRINITY_env

## Loading this here to prevent samtools-compatability issues from conda-install on our HPC
#module load SAMtools/1.8-foss-2016b

## Listing fastq files to run
FILES=$(find ${FASTQ} -type f -name "*.fq.gz" | paste -sd " ")

# Run trinity
Trinity \
    --seqType fq \
    --max_memory 50G \
    --single ${FILES} \
    --SS_lib_type F \
    --CPU ${THREADS} \
    --output ${OUT_DIR}

## Assembly statistics
${TRINITY_UTIL}/TrinityStats.pl ${OUT_DIR}/Trinity.fasta > ${OUT_DIR}/Trinity.stats

source deactivate
