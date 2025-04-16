#!/usr/bin/env nextflow

process segmentBEDfile {
    input:
    path(bed_file.bed)
    path(bed_file.bim)
    path(bed_file.fam)

    output:
    path "chr_${chr}"

    script:
    """
    #!/bin/bash
    plink --bfile $bed_file --chr ${chr} --make-bed --out chr_${chr}
    """
}