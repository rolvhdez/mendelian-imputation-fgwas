#!/bin/bash

apt-get update
apt-get install -y git build-essential zlib1g-dev g++

$CURRWD="$PWD"

# Install Rust
if ! [ -f "$HOME/.rustup/settings.toml" ]; then
    echo "Installing Rustup..."
    curl -sSf https://sh.rustup.rs | sh -s -- -y
    . "$HOME/.cargo/env"
else 
    echo "Rustup is installed."
fi

# Install QCTools (from source)
QCTOOL_DIR="/opt/bin/qctool"
QCTOOL_VER="2.2.0"
if ! [ -d "$QCTOOL_DIR" ]; then
    echo "Installing QCTools"
    mkdir -p "$QCTOOL_DIR"
    wget https://github.com/gavinband/qctool/archive/refs/tags/v"$QCTOOL_VER".tar.gz -P "$QCTOOL_DIR"
    tar -xvzf "$QCTOOL_DIR"/v"$QCTOOL_VER".tar.gz -C "$QCTOOL_DIR"
    rm "$QCTOOL_DIR"/v"$QCTOOL_VER".tar.gz
    
    cd "$QCTOOL_DIR"/qctool-"$QCTOOL_VER"
    sudo ./waf configure
    sudo ./waf
    
    cd "$CURRWD"
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
    pip install -r requirements.txt
fi
echo "Requirements installed."

cd scripts/

# Run the phenotype reconstruction
if ! [ -f /tmp/phenotype.txt ]; then
    echo "Creating phenotype file..."
    python phenotype_reconstruct.py
fi
    echo "Phenotype created. Check /tmp/phenotype.txt"

# Run the pedigree reconstruction
if ! [ -f /tmp/pedigree.txt ]; then
    echo "Running pedigree reconstruction..."
    python pedigree_reconstruct.py
fi
    echo "Pedigree created. Check /tmp/pedigree.txt"