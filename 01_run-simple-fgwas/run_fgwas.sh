#!/bin/bash

### IMPORTANT ###
# This workflow is to run only GSAV2_chip (simple genotype file) data.
# Make sure to have run the ./create_inputfiles.sh script before running this one.

set -euo pipefail

NOTEBOOK_WD="/opt/notebooks"
PLINK_DIR="$NOTEBOOK_WD/bin/plink"
KIN="/tmp/kinship.csv"
PHEN="/tmp/phenotype.txt"
PED="/tmp/pedigree.txt"
OUTPUT="output_bmi/"
DXOUTPUT="/Users/Roberto/results/fgwas_bmi_$(date +'%Y%m%d_%H%M%S')/"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT"

# Install PLINK
if ! command -v plink &> /dev/null; then
    echo "Installing PLINK..."
    mkdir -p "$PLINK_DIR"
    
    if ! [ -f "$PLINK_DIR/plink" ]; then
        # Download and install PLINK
        wget https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20241022.zip -O "$PLINK_DIR/plink.zip"
        unzip "$PLINK_DIR/plink.zip" -d "$PLINK_DIR" 
        rm "$PLINK_DIR/plink.zip"
        chmod +x "$PLINK_DIR/plink"  # Ensure plink is executable
    fi

    # Add PLINK directory to PATH (temporarily)
    export PATH="$PATH:$PLINK_DIR"

    if command -v plink &> /dev/null; then
        echo "PLINK installed successfully."
    else 
        echo "Error: PLINK could not be installed." >&2
        exit 1
    fi
else
    echo "PLINK has been installed previously."
fi

# Make a subset of the chromosome 22 for GSAv2-Chip
BED="/mnt/project/Data/GSAv2-Chip/data/pVCF/MCPS_Freeze_150.GT_hg38.pVCF"

if ! [ -f "/tmp/chr_22.bed" ]; then
    # SNIPAR uses separate files for each chromosome
    {
        for chrom in {1..22}; do
            plink --bfile "$BED" --chr "${chrom}" \
            --maf 0.05 --geno 0.1 \
            --snps-only \
            --make-bed --out "/tmp/chr_${chrom}" 
        done 
    } 2>&1 | tee -a "${OUTPUT}/plink_$(date +'%Y%m%d_%H%M%S').log"
fi

# Run SNIPAR
CONDA_ENV="myenv"

if ! conda env list | grep -q "$CONDA_ENV"; then
    echo "Creating Conda environment '$CONDA_ENV'..."
    conda create -n "$CONDA_ENV" python=3.9 --yes
fi

# Activate Conda environment
echo "Activating Conda environment '$CONDA_ENV'..."
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "$CONDA_ENV" || { echo "Failed to activate conda environment"; exit 1; }

# Install Python packages
if ! python -c "import snipar" &> /dev/null; then
    echo "Installing required Python packages..."
    pip install --upgrade pip
    pip install snipar==0.0.20 # Guan et al. (2025)
    pip install scikit-learn
fi
echo "Requirements installed."

## Run the FGWAS
BED_PATTERN="/tmp/chr_@"
GWAS_RESULTS="${OUTPUT}/gwas_chr@"

{
    gwas.py "$PHEN" --bed "$BED_PATTERN" --pedigree "$PED" \
        --chr_range 22 \
        --cpus 12 --min_maf 0.01 --max_missing 5 \
        --no_hdf5_out \
        --out "$GWAS_RESULTS"
} 2>&1 | tee -a "${OUTPUT}/fgwas_$(date +'%Y%m%d_%H%M%S').log"

# Copy and upload results
cp "$PHEN" "$PED" "$OUTPUT"
dx mkdir -p "$DXOUTPUT"
dx upload --recursive "$OUTPUT" --brief --path "$DXOUTPUT"