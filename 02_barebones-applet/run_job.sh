#!/bin/bash
set -euo pipefail

# Define inputs
# Output directory
OUTPUT_DIR="/tmp/job_output/"
mkdir -p $OUTPUT_DIR

## Default inputs
OUTPUT_PREFIX="$(date +'%Y%m%d_%H%M%S')"
UPLOAD="no"
MAF=0.05
MISSING=0.02
CHR_RANGE=22
CPU=4

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--prefix) OUTPUT_PREFIX="$2"; shift ;;
        # File inputs
        --phenotype) BASE="$2"; shift ;;
        --kinship) KING="$2"; shift ;;
        --genotype) BED="$2"; shift ;;
        # Filters
        --maf) MAF="$2"; shift ;;
        --missing) MISSING="$2"; shift ;;
        --chr_range) CHR_RANGE="$2"; shift ;;
        --cpu) CPU="$2"; shift ;;
        --upload) UPLOAD="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Make the directory
DXOUTPUT="/Users/Roberto/results/fgwas/${OUTPUT_PREFIX}/"
dx mkdir -p "${DXOUTPUT}"

# Whole output with prefix
OUTPUT="${OUTPUT_DIR%/}/${OUTPUT_PREFIX}"

# Initialize Conda environment
CONDA_ENV="snipar_env"
eval "$(conda shell.bash hook)"

if ! conda info --envs | grep -q $CONDA_ENV; then
    conda create -n "$CONDA_ENV" python=3.9 --yes
    pip install --upgrade pip
    pip install -r resources/requirements.txt
fi

conda activate "$CONDA_ENV";

# Filter the Baseline Survey for BMI
QCBASE="${OUTPUT_DIR%/}/FILTER_BASELINE.csv"
if ! [ -f "$QCBASE" ]; then
    echo "Filtering baseline..."
    Rscript resources/filter_baseline.r "$BASE" "$QCBASE"
fi
echo "Baseline filtered..."

# Run the phenotype reconstruction
PHEN="${OUTPUT_DIR%/}/phenotype.txt"
PED="${OUTPUT_DIR%/}/pedigree.txt"
if ! [ -f "$PHEN" ] || ! [ -f "$PED" ]; then
    {
        python resources/generate_inputs.py \
            --kinship "$KING" --baseline "$QCBASE" \
            --out "$OUTPUT_DIR"
    } 2>&1 | tee -a "${OUTPUT}_inputs.log"
fi
echo "Phenotype and pedigree files created."
echo "Check ${OUTPUT_DIR}"

# PLINK: Segment QC chromosomes
SEGMENT_DIR="${OUTPUT_DIR%/}/segments"
if ! [ -d "$SEGMENT_DIR" ] > /dev/null; then
    mkdir -p "$SEGMENT_DIR"
    # echo "Segmenting ${QCBED}..."
    echo "Segmenting ${BED}..."
    {
        for chrom in $(seq "${CHR_RANGE}"); do
            plink --bfile "$BED" --chr "${chrom}" --make-bed --out "${SEGMENT_DIR}/${OUTPUT_PREFIX}_chr_${chrom}"
        done 
    } 2>&1 | tee -a "${OUTPUT}_segment_plink.log"
fi

# SNIPAR: Run the FGWAS
BED_PATTERN="${SEGMENT_DIR}/${OUTPUT_PREFIX}_chr_@"
echo "Running FGWAS..."
{
    gwas.py "$PHEN" --bed "$BED_PATTERN" --pedigree "$PED" \
        --chr_range "$CHR_RANGE" --cpus "$CPU" \
        --no_hdf5_out --out "$OUTPUT"
} 2>&1 | tee -a "${OUTPUT}_fgwas.log"

conda deactivate

# Copy and upload results
if [ "$UPLOAD" == "yes" ]; then
    echo "Uploading results to ${DXOUTPUT}..."
    dx upload "${OUTPUT_DIR%/}/*.{csv,txt,log,gz}" --brief --path "${DXOUTPUT}"
else
    echo "Results are available in ${OUTPUT_DIR}"
fi