#!/bin/bash
set -euo pipefail

# Define inputs
## Files to run the FGWAS
KING="/mnt/project/Data/KING-IBD/king_ibdseg_4th.seg"
BASE="/mnt/project/Data/Baseline/MCPS BASELINE.csv"
BED="/mnt/project/Data/GSAv2-Chip/data/pVCF/MCPS_Freeze_150.GT_hg38.pVCF"

## User inputs
OUTPUT_PREFIX="$(date +'%Y%m%d_%H%M%S')"
DXOUTPUT="/Users/Roberto/results/${OUTPUT_PREFIX}_FGWAS/"
MAF=0.05
MISSING=0.1
CHRANGE="22"
CPU=4

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--prefix) OUTPUT_PREFIX="$2"; shift ;;
        --maf) MAF="$2"; shift ;;
        --missing) MISSING="$2"; shift ;;
        --chr_range) CHRRANGE="$2"; shift ;;
        --cpu) CPU="$2"; shift ;;
        --dx-output) DXOUTPUT="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Output directory
OUTPUT_DIR="/tmp/job_output/"
mkdir -p $OUTPUT_DIR

# Initialize Conda environment
CONDA_ENV="snipar_env"
conda create -n "$CONDA_ENV" python=3.9 --yes
eval "$(conda shell.bash hook)"
conda activate "$CONDA_ENV" # activate

# Install packages
pip install --upgrade pip
pip install -r resources/requirements.txt

# Filter the Baseline Survey for BMI
Rscript resources/filter_baseline.r

# Run the phenotype reconstruction
{
    python resources/generate_inputs.py \
        --kinship $KING --baseline $BASE \
        --output-prefix $OUTPUT_PREFIX
} 2>&1 | tee -a "${OUTPUT_DIR}/${OUTPUT_PREFIX}_inputs.log"

# PLINK: Create the chromosomes
{
    for chrom in {1..22}; do
        plink --bfile $BED --chr ${chrom} \
        --maf $MAF --geno $MISSING \
        --snps-only \
        --make-bed --out "/tmp/chr_${chrom}" 
    done 
} 2>&1 | tee -a "${OUTPUT_DIR}/${OUTPUT_PREFIX}_plink.log"

# SNIPAR: Run the FGWAS
PHEN="/tmp/${OUTPUT_PREFIX}_phenotype.txt"
PED="/tmp/${OUTPUT_PREFIX}_pedigree.txt"
BED_PATTERN="/tmp/chr_@"
GWAS_RESULTS="${OUTPUT_DIR}/${OUTPUT_PREFIX}_chr@"

{
    gwas.py $PHEN --bed $BED_PATTERN --pedigree $PED \
        --chr_range 22 \
        --cpus $CPU --min_maf $MAF --max_missing $MISSING \
        --no_hdf5_out \
        --out $GWAS_RESULTS
} 2>&1 | tee -a "${OUTPUT_DIR}/${OUTPUT_PREFIX}_fgwas.log"

# Copy and upload results
cp $PHEN $PED $OUTPUT
dx mkdir -p $DXOUTPUT
dx upload --recursive $OUTPUT --brief --path $DXOUTPUT