#!/bin/bash

set -e

{
    ibd.py \
    --bed "${OUTDIR%/}/chr_segments/chr_@" \
    --pedigree "${OUTDIR%/}/input_files/pedigree.txt" \
    --chr_range "${CHR_RANGE}" \
    --threads 10 --batches 1 \
    --ld_out \
    --out "${OUTDIR%/}/ibd_segments/chr_@"
} 2>&1 | tee "${OUTDIR%/}/ibd_inference.log"