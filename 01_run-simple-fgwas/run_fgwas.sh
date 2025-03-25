#!/bin/bash

### IMPORTANT ###
# This workflow is to run only GSAV2_chip (simple genotype file) data.
# Make sure tu have run the ./create_inputfiles.sh script before running this one.

NOTEBOOK_WD="/opt/notebooks"
PLINK_DIR="$NOTEBOOK_WD/bin/plink"

# Install PLINK
if ! command -v plink &> /dev/null; then
	echo "Installing PLINK..."
	if ! [ -d "$PLINK_DIR" ]; then
	mkdir -p "$PLINK_DIR"
fi
	if ! [ -f "$PLINK_DIR/plink" ];then
		# Download and install PLINK
		wget https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20241022.zip -O "$PLINK_DIR/plink.zip"
		unzip "$PLINK_DIR/plink.zip" -d "$PLINK_DIR" 
		rm "$PLINK_DIR/plink.zip"    
	fi

	# Add PLINK directory to PATH (temporally)
	export PATH="$PATH:$PLINK_DIR"

	if command -v plink &> /dev/null; then
		echo "PLINK installed succesfully."
	else 
		echo "error: PLINK could not be installed."
	fi
else
	echo "PLINK has been installed previously."
fi

# Make a subset of the chromosome 22 for GSAv2-Chip
BED="/mnt/project/Data/GSAv2-Chip/data/pVCF/MCPS_Freeze_150.GT_hg38.pVCF"

if ! [ -f "/tmp/chr_22.bed" ];then
	# SNIPAR uses separate files for each chromosome
    for chrom in {1..22}; do
        plink --bfile $BED --chr ${chrom} --make-bed --out /tmp/chr_${chrom}
    done
fi

echo "Genotype data has been succesfully subdivided by autosomal (22) chromosomes."

# Run SNIPAR
CONDA_ENV="myenv"

if ! conda env list | grep -q "$CONDA_ENV"; then
    echo "Creating Conda environment '$CONDA_ENV'..."
    conda create -n "$CONDA_ENV" python=3.9 --yes
fi

## Activate Conda environment
echo "Selecting Conda environment '$CONDA_ENV'..."
echo "Activating Conda environment '$CONDA_ENV'..."
eval "$(conda shell.bash hook)"
conda activate "$CONDA_ENV"

# Install Python packages
if ! pip freeze | grep -q "^snipar"; then
    echo "Installing required Python packages..."
    pip install --upgrade pip
#    pip install snipar==0.0.18 # Young et al. (2023)
    pip install snipar==0.0.20 # Guan et al. (2025)
    pip install scikit-learn
fi
echo "Requirements installed."

## Run the FGWAS
PHEN="/tmp/phenotype.txt"
BED="/tmp/chr_@"
PED="/tmp/pedigree.txt"

if ! [ -d ./fgwas_output/ ]; then
	mkdir fgwas_output
fi

# Run the FGWAs
gwas.py $PHEN \
	--bed $BED \
	--pedigree $PED \
	--threads 12 \
	--out ./fgwas_output/bmi