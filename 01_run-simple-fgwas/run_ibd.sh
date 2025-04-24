#!/bin/bash

set -e

ibd.py \
    --bed ${BED_PATH} \
    --pedigree ${PEDIGREE} \
    --chr_range ${CHR_RANGE} \
    --threads 10 --batches 4 \
    --ld_out \
    --out ${OUTDIR}/chr_@