#!/bin/bash

mkdir -p "${OUTDIR%/}/chr_segments/"

for i in {1..22}; do
    plink --bfile "${BED}" --chr $i --make-bed --out "${OUTDIR%/}/chr_segments/chr_$i"
done