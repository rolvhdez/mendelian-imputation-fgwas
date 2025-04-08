#!/bin/bash
set -euo pipefail

# Define inputs
## Default inputs
OUTPUT_PREFIX="$(date +'%Y%m%d_%H%M%S')"
DXOUTPUT="/Users/Roberto/results/${OUTPUT_PREFIX}_FGWAS/"
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
eval "$(conda shell.bash hook)"

if ! conda info --envs | grep -q $CONDA_ENV; then
    conda create -n "$CONDA_ENV" python=3.9 --yes
    pip install --upgrade pip
    pip install -r resources/requirements.txt
fi

conda activate "$CONDA_ENV";

# Filter the Baseline Survey for BMI
QCBASE="/tmp/FILTER_BASELINE.csv"
if ! [ -f "$QCBASE" ]; then
    echo "Filtering baseline..."
    Rscript resources/filter_baseline.r "$BASE" "$QCBASE"
fi
echo "Baseline filtered..."

# Run the phenotype reconstruction
PHEN="/tmp/${OUTPUT_PREFIX}_phenotype.txt"
PED="/tmp/${OUTPUT_PREFIX}_pedigree.txt"
if ! [ -f "$PHEN" ] || ! [ -f "$PED" ]; then
    {
        python resources/generate_inputs.py \
            --kinship "$KING" --baseline "$QCBASE" \
            --output-prefix "$OUTPUT_PREFIX"
    } 2>&1 | tee -a "${OUTPUT_DIR}/${OUTPUT_PREFIX}_inputs.log"
fi
echo "Phenotype and pedigree files created."
echo "Check /tmp/"

# PLINK: QC genotype data (Ziyatdinov et al., 2023)
QCBED="/tmp/${OUTPUT_PREFIX}_genotype"

if compgen -G "${QCBED}.*" > /dev/null; then
    echo "QC genotype files already exist. Skipping QC step..."
else
    echo "Performing QC on genotype file..."
    {
        plink --bfile "$BED" \
            --set-hh-missing --set-me-missing \
            --mendel-duos \
            --autosome --mind 0.05 \
            --geno 0.02 --mac 1 \
            --hwe 1e-30 \
            --make-bed --out "$QCBED"
    } 2>&1 | tee -a "${OUTPUT_DIR}/${OUTPUT_PREFIX}_qc_plink.log"
fi

# PLINK: Segment QC chromosomes
if ! compgen -G "/tmp/chr_22.*" > /dev/null; then
    echo "Segmenting ${QCBED}..."
    {
        for chrom in $(seq "${CHR_RANGE}"); do
            plink --bfile "$QCBED" --chr "${chrom}" --make-bed --out "/tmp/chr_${chrom}"
        done 
    } 2>&1 | tee -a "${OUTPUT_DIR}/${OUTPUT_PREFIX}_segment_plink.log"
fi

# SNIPAR: Run the FGWAS
BED_PATTERN="/tmp/chr_@"
GWAS_RESULTS="${OUTPUT_DIR}/${OUTPUT_PREFIX}_chr@"

echo "Running FGWAS..."
{
    gwas.py "$PHEN" --bed "$BED_PATTERN" --pedigree "$PED" \
        --chr_range "$CHR_RANGE" \
        --cpus "$CPU" --min_maf "$MAF" --max_missing "$MISSING" \
        --no_hdf5_out --out "$GWAS_RESULTS"
} 2>&1 | tee -a "${OUTPUT_DIR}/${OUTPUT_PREFIX}_fgwas.log"

conda deactivate

# Copy and upload results
# cp "${PHEN}" "${PED}" "${OUTPUT_DIR}"
# dx mkdir -p "${DXOUTPUT}"
# dx upload --recursive "${OUTPUT_DIR}" --brief --path "${DXOUTPUT}"