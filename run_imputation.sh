#!/bin/bash

set -e

mkdir -p "${out_dir%/}/chr_imputed/"

{
    impute.py \
        --ibd "${out_dir%/}/ibd_segments/chr_@.ibd" \
        --bed "${out_dir%/}/chr_segments/chr_@" \
        --pedigree "${out_dir%/}/pedigree.txt" \
        --chr_range "${chr_range}" \
        --threads 10 \
        --out "${out_dir%/}/chr_imputed/chr_@.imputed"
} 2>&1 | tee "${out_dir%/}/mendelian_imputation.log"