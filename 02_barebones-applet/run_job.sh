#!/bin/bash

# Default inputs
OUTPUT_PREFIX="$(date +'%Y%m%d_%H%M%S')"
CHR_RANGE=22
CPU=4

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--prefix) OUTPUT_PREFIX="$2"; shift ;;
        --phenotype) BASE="$2"; shift ;;
        --kinship) KING="$2"; shift ;;
        --genotype) BED="$2"; shift ;;
        --chr_range) CHR_RANGE="$2"; shift ;;
        --cpu) CPU="$2"; shift ;;
        --upload) UPLOAD="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

read -p "Run with imputation? (y/N): " imp_answer
case $imp_answer in
    [Yy]*) MAKE_IMPUTATION=true ;;
    *) MAKE_IMPUTATION=false ;;
esac

read -p "Upload results to DNAnexus (${DXOUTPUT})? (y/N): " imp_answer
case $imp_answer in
    [Yy]*) UPLOAD=true ;;
    *) UPLOAD=false ;;
esac

# Make the directory
if $UPLOAD; then 
    DXOUTPUT="/Users/Roberto/results/fgwas/${OUTPUT_PREFIX}/"
    dx mkdir -p "${DXOUTPUT}"
fi

# Whole output with prefix
OUTPUT="${OUTPUT_DIR%/}/${OUTPUT_PREFIX}"

# Output directories
OUTPUT_DIR="/tmp/job_output/"; mkdir -p $OUTPUT_DIR
SEGMENT_DIR="${OUTPUT_DIR%/}/chr_segments"; mkdir -p "$SEGMENT_DIR"
SUMSTATS_DIR="${OUTPUT_DIR%/}/sumstats"; mkdir -p "$SUMSTATS_DIR"

PATTERN="${OUTPUT_PREFIX}_chr_@"
BED_PATTERN="${SEGMENT_DIR}/${PATTERN}"
SUMSTATS_PATTERN="${SUMSTATS_DIR}/${PATTERN}"

if $MAKE_IMPUTATION; then
    IBD_DIR="${OUTPUT_DIR%/}/ibd_segments"; mkdir -p "$IBD_DIR"
    IMP_DIR="${OUTPUT_DIR%/}/imputed_genotypes"; mkdir -p "$IMP_DIR"

    IBD_PATTERN="${IBD_DIR}/${PATTERN}"
    IMP_PATTERN="${IMP_DIR}/${PATTERN}"
fi

# Declare SNIPAR functions
function snipar_ibd {
    ibd.py \
        --bed "$1" \
        --pedigree "$2" \
        --chr_range "$3" \
        --batches 1 --threads 12 \
        --ld_out \
        --out "$IBD_PATTERN"
}
function snipar_impute {
    impute.py \
        --bed "$1" \
        --pedigree "$2" \
        --chr_range "$3" \
        --ibd "$4" \
        --processes 4 --chunks 8 --threads 12 \
        --out "$IMP_PATTERN"
}


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
    echo "Phenotype and pedigree files generated in ${OUTPUT_DIR}"
else
    echo "Phenotype and pedigree files already exist in ${OUTPUT_DIR}"
fi

# PLINK: Segment QC chromosomes
if ! find "${SEGMENT_DIR%/}" -type f | grep -q .; then
    echo "Segmenting ${BED}..."
    for arg in $CHR_RANGE; do
        if [[ $arg == *-* ]]; then
            # If the argument contains a dash, it's a range
            chr_start="${arg%-*}"
            chr_end="${arg#*-}"
            for chrom in $(seq "$chr_start" "$chr_end"); do
                echo "Segmenting ${BED}..."
                plink --bfile "$BED" --chr "${chrom}" --make-bed --out "${SEGMENT_DIR}/${OUTPUT_PREFIX}_chr_${chrom}"
            done
        else 
            # If it doesn't contain a dash, it's a single chromosome
            plink --bfile "$BED" --chr "${arg}" --make-bed --out "${SEGMENT_DIR}/${OUTPUT_PREFIX}_chr_${arg}"
        fi
    done
else
    echo "Segmented files already exist in ${SEGMENT_DIR}"
fi

if $MAKE_IMPUTATION; then
    # Make IBD inference based on sibship
    if ! find "$IBD_DIR" -type f | grep -q .; then # Check if files exists
        snipar_ibd "$BED_PATTERN" "$PED" "$CHR_RANGE" 2>&1 | tee "${OUTPUT}_ibd.log" || {
            echo "IBD inference failed. Please check the logs."
            exit 1
        }
    fi
    # Impute parental genotypes based on IBD
    if ! find "$IMP_DIR" -type f | grep -q .; then # Check if files exists
        snipar_impute "$BED_PATTERN" "$PED" "$CHR_RANGE" "$IBD_PATTERN" 2>&1 | tee "${OUTPUT}_imputation.log" || {
            echo "Imputation failed. Please check the logs."
            exit 1
        }
    else
        echo "Imputed genotypes already exist in ${IMP_DIR}"
    fi
fi

# Base command for FGWAS
fgwas=(
    gwas.py "$PHEN"
    --bed "$BED_PATTERN"
    --pedigree "$PED"
    --chr_range "$CHR_RANGE"
    --cpu "$CPU" --threads 12
    --out "$SUMSTATS_PATTERN"
)

# Conditionally add the imputation flags based on the user input
if $MAKE_IMPUTATION; then
    fgwas+=(--impute "$IMP_PATTERN" --robust)
fi

# Run the FGWAS
echo "Running FGWAS..."
"${fgwas[@]}" 2>&1 | tee "${OUTPUT}_fgwas.log" || echo "FGWAS failed. Please check the logs." && exit 1

# Upload results to DNAnexus
if $UPLOAD; then
    echo "Uploading results to ${DXOUTPUT}..."
    for file in "${OUTPUT_DIR%/}"/*.{csv,txt,log,gz}; do
        if [ -f "$file" ]; then
            dx upload "$file" --brief --path "${DXOUTPUT}"
        fi
    done
    exit 0
else
    echo "Results are available in ${OUTPUT_DIR}"
    exit 0
fi