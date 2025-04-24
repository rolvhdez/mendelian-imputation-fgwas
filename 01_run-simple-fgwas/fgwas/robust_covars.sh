#!/bin/bash

set -e

{
    gwas.py "${OUTDIR%/}/input_files/phenotype.txt" \
    --phen_index $1 \
    --bed "${OUTDIR%/}/chr_segments/chr_@" \
    --imp "${OUTDIR%/}/impute_files/chr_@.imputed" \
    --pedigree "${OUTDIR%/}/input_files/pedigree.txt" \
    --chr_range "${CHR_RANGE}" \
    --ibdrel_path "${KIN%.seg}" \
    --sparse_thresh 0.1 \
    --cpu 8 --threads 4 \
    --out "${OUTDIR%/}/chr_@"
} 2>&1 | tee "${OUTDIR%/}/fgwas.log"