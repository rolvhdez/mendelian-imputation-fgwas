#!/bin/bash

# Install Rust
if ! [ -f "$HOME/.rustup/settings.toml" ]; then
    echo "Installing Rustup..."
    curl -sSf https://sh.rustup.rs | sh -s -- -y
    . "$HOME/.cargo/env"
else 
    echo "Rustup is installed."
fi

# Create Conda environment
CONDA_ENV="myenv"

if ! conda env list | grep -q "$CONDA_ENV"; then
    echo "Creating Conda environment '$CONDA_ENV'..."
    conda create -n "$CONDA_ENV" python=3.9 --yes
fi

# Activate Conda environment
echo "Selecting Conda environment '$CONDA_ENV'..."
echo "Activating Conda environment '$CONDA_ENV'..."
eval "$(conda shell.bash hook)"
conda activate "$CONDA_ENV"

# Install Python packages
if ! pip freeze | grep -q "^snipar"; then
    echo "Installing required Python packages..."
    pip install --upgrade pip
    pip install snipar==0.0.20 # Guan et al. (2025)
    pip install scikit-learn
fi
echo "Requirements installed."

# Filter the Baseline Survey for BMI
if ! [ -f /tmp/FILTER_BASELINE.csv ]; then
    Rscript scripts/filter_baseline.r
fi

# Run the phenotype reconstruction
if ! [ -f /tmp/phenotype.txt ] || ! [ -f /tmp/pedigree.txt ]; then
    echo "Creating input files..."
    python scripts/generate_inputs.py
fi
    echo "Pedigree and phenotype files created. Check /tmp/"