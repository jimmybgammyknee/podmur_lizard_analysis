#!/usr/bin/env bash

# Created by Alastair Ludington (alastair.j.lud@gmail.com)
# - editied by Jimmy Breen (jimmymbreen@gmail.com)

################################################################################
## Directories
BASE=`pwd`
DB=${BASE}/blastdb
ASSEMBLY=${BASE}/trinity_out_dir
TD_OUT=${BASE}/transdecoder_out

################################################################################
## Pipeline

# Because we only have one assembly we can define this easily. 
# But this can also be run in a loop if you have more than one
f=${ASSEMBLY}/Trinity-GG.fasta

## Making output directory for each sample
BASENAME=$(basename ${f} .fasta)
mkdir -p ${TD_OUT}/

## Prediction putative long ORFs in 
TransDecoder.LongOrfs \
    -t ${f} \
    --gene_trans_map ${f}.gene_trans_map \
    --output_dir ${TD_OUT}/

## Searching uniprot for homology support of predicted ORFs
blastp \
    -query ${TD_OUT}/longest_orfs.pep  \
    -db ${DB}/uniprot_sprot.fasta  \
    -max_target_seqs 1 \
    -outfmt 6 \
    -evalue 1e-5 \
    -num_threads 16 > ${TD_OUT}/${BASENAME}.outfmt6

## Searching Pfam domain for homology support of predicted ORFs
hmmscan \
    --cpu 16 \
    --domtblout ${TD_OUT}/${BASENAME}.domtblout \
    ${DB}/Pfam-A.hmm \
    ${TD_OUT}/longest_orfs.pep

## Predicting likely coding regions
TransDecoder.Predict \
    -t ${f} \
    --retain_pfam_hits ${TD_OUT}/${BASENAME}.domtblout \
    --retain_blastp_hits ${TD_OUT}/${BASENAME}.outfmt6 \
    --output_dir ${TD_OUT}/

