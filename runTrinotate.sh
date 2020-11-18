#!/bin/bash

# Created by Alastair Ludington (alastair.j.lud@gmail.com)
# - editied by Jimmy Breen (jimmymbreen@gmail.com)

SLURM_CPUS_PER_TASK=16

################################################################################
## Directories
BASE=`pwd`
TRINITY=${BASE}/trinity_out_dir
DATABASES_DIR=${BASE}/blastdb

################################################################################
## Listing files
FASTA=${TRINITY}/Trinity-GG.fasta

## Basename of file
BASENAME="lizard"

TRANSDECODER=${BASE}/transdecoder_out
TRINOTATE_DIR=${BASE}/trinotate_out
TRINOTATE_SEARCH=${TRINOTATE_DIR}/functional
LOG_OUT=${TRINOTATE_DIR}/logs

################################################################################
## Setting up for trinotate

## Create trinotate directories
mkdir -p ${TRINOTATE_DIR}
mkdir -p ${TRINOTATE_SEARCH}
mkdir -p ${LOG_OUT}

## Copy Trinotate SQL databases to respective sample directory & rename accordingly
cp ${DATABASES_DIR}/Trinotate.sqlite ${TRINOTATE_DIR}/${BASENAME}.sqlite

################################################################################
## Running homology searches 
## BLASTing transdecoder predicted peptides
blastp \
    -db ${DATABASES_DIR}/uniprot_sprot.fasta \
    -query ${TRANSDECODER}/longest_orfs.pep \
    -max_target_seqs 1 \
    -outfmt 6 \
    -evalue 1e-5 \
    -num_threads ${SLURM_CPUS_PER_TASK} \
    > ${TRINOTATE_SEARCH}/blastp.outfmt6

## BLASTing transcripts 
blastx \
    -db ${DATABASES_DIR}/uniprot_sprot.fasta \
    -query ${FASTA} \
    -max_target_seqs 1 \
    -outfmt 6 \
    -evalue 1e-5 \
    -num_threads ${SLURM_CPUS_PER_TASK} \
    > ${TRINOTATE_SEARCH}/blastx.outfmt6

## Searching using protein profile (HMMER)
hmmscan \
    --cpu ${SLURM_CPUS_PER_TASK} \
    --domtblout ${TRINOTATE_SEARCH}/pfam.out \
    ${DATABASES_DIR}/Pfam-A.hmm \
    ${TRANSDECODER}/longest_orfs.pep > \
    ${LOG_OUT}/pfam.log

## Sequence feature prediction - signal peptides
/localscratch/Programs/signalp-5.0b/bin/signalp \
    -f short \
    -v \
    -l ${LOG_OUT}/signalp.log \
    -n ${TRINOTATE_SEARCH}/signalP.out \
    ${TRANSDECODER}/longest_orfs.pep

## Predicting transmembrane domains - IMPORTANT! The '<' pointing to --short is needed!
/localscratch/Programs/tmhmm-2.0c/bin/tmhmm \
    --short < ${TRANSDECODER}/longest_orfs.pep > \
    ${TRINOTATE_SEARCH}/tmhmm.out

################################################################################
## Trinotate report

## Initialising sqlite database - ingesting data
Trinotate ${TRINOTATE_DIR}/${BASENAME}.sqlite init \
    --gene_trans_map ${TRINITY}/Trinity-GG.fasta.gene_trans_map \
    --transcript_fasta ${FASTA} \
    --transdecoder_pep ${TRANSDECODER}/longest_orfs.pep

## Loading BLAST homology sequences
Trinotate ${TRINOTATE_DIR}/${BASENAME}.sqlite \
    LOAD_swissprot_blastp ${TRINOTATE_SEARCH}/blastp.outfmt6

Trinotate ${TRINOTATE_DIR}/${BASENAME}.sqlite LOAD_swissprot_blastx ${TRINOTATE_SEARCH}/blastx.outfmt6

## Loading HMMER search
Trinotate ${TRINOTATE_DIR}/${BASENAME}.sqlite LOAD_pfam ${TRINOTATE_SEARCH}/pfam.out

## Loading signal peptide predictions
Trinotate ${TRINOTATE_DIR}/${BASENAME}.sqlite LOAD_signalp ${TRINOTATE_SEARCH}/signalP.out

## Loading transmembrane domains 
Trinotate ${TRINOTATE_DIR}/${BASENAME}.sqlite LOAD_tmhmm ${TRINOTATE_SEARCH}/tmhmm.out

## Generating annotation report 
Trinotate ${TRINOTATE_DIR}/${BASENAME}.sqlite report > ${TRINOTATE_DIR}/${BASENAME}.annotationReport.xls

################################################################################
## Build a key-value table of Trinity id to gene annotation
Trinotate_get_feature_name_encoding_attributes.pl \
    ${TRINOTATE_DIR}/${BASENAME}.annotationReport.xls > \
    ${TRINOTATE_DIR}/${BASENAME}.annotationMap.txt
