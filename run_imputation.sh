#!/usr/bin/env bash

set -e

mkdir -p "${OUTDIR%/}/chr_imputed/"

{
    impute.py \
    --ibd "${OUTDIR%/}/ibd_segments/chr_@.ibd" \
    --bed "${OUTDIR%/}/chr_segments/chr_@" \
    --pedigree "${OUTDIR%/}/input_files/pedigree.txt" \
    --chr_range "${CHR_RANGE}" \
    --threads 10 \
    --out "${OUTDIR%/}/chr_imputed/chr_@.imputed" \
} 2>&1 | tee "${OUTDIR%/}/mendelian_imputation.log"