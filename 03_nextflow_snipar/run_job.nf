#!/usr/bin/env nextflow

/* Pipeline parameters */
params.baseline=""
params.kinship=""
params.genotype=""
params.chr_range="1-22"

/* Pipeline processes */
include { segmentBEDfile } from './modules/processGenotype.nf'
include { filterBaseline } from './modules/inputPreps.nf'
include { createAgesexKinship } from './modules/inputPreps.nf'
include { createPedigree } from './modules/inputPreps.nf'
include { createPhenotype } from './modules/inputPreps.nf'

/* Pipeline functions */	
def expandRanges(String str) {
    def elements = str.split()
    def result = []
    elements.each { element ->
        if (element.contains('-')) {
            def (start, end) = element.split('-').collect { it as int }
            result.addAll(start..end)
        } else {
            result.add(element as int)
        }
    }
    return result
}

workflow {

    def rangeChrom = expandRanges(params.chr_range)
    chromosomes = Channel.of(rangeChrom)
                         .flatten()
    Channel
        .fromFilePairs("${params.genotype}.{bed,fam,bim}", size:3)
        .ifEmpty {error "No matching plink files"}
        .set {plink_data}

    // make a QC of the MCPS Baseline survey
    filterBaseline(params.baseline)

    // segment chromosomes
    segmentBEDfile(plink_data, chromosomes)

    // create pedigree and phenotype files
    createAgesexKinship(filterBaseline.output, params.kinship)
    createPedigree(createAgesexKinship.output.agesex, createAgesexKinship.output.kinship)
    createPhenotype(filterBaseline.output, params.kinship, createPedigree.output)
}