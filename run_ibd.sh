#!/bin/bash

set -e

mkdir -p "${out_dir%/}/ibd_segments/"

{
    ibd.py \
    --bed "${out_dir%/}/chr_segments/chr_@" \
    --pedigree "${out_dir%/}/pedigree.txt" \
    --chr_range "${chr_range}" \
    --threads 10 --batches 1 \
    --ld_out \
    --out "${out_dir%/}/ibd_segments/chr_@"
} 2>&1 | tee "${out_dir%/}/ibd_inference.log"