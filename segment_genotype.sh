#!/bin/bash

mkdir -p "${out_dir%/}/chr_segments/"

{
    for i in {1..22}; do
        plink --bfile "${bed}" --chr $i --make-bed --out "${out_dir%/}/chr_segments/chr_$i"
    done
} 2>&1 | tee "${out_dir%/}/segment_bedfiles.log"