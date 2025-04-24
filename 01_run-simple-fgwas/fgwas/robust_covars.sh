#!/bin/bash

set -e

gwas.py "${OUTDIR%/}/input_files/phenotype.txt" \
    --phen_index $1 \
    --bed "${OUTDIR%/}/chr_segments/chr_@" \
    --imp "${OUTDIR%/}/impute_files/chr_@.imputations" \
    --pedigree "${OUTDIR%/}/input_files/pedigree.txt" \
    --chr_range "22" \
    --ibdrel_path "${KIN%.seg}" \
    --sparse_thresh 0.1 \
    --cpu 8 --threads 4 \
    --out "${OUTDIR%/}/chr_@"