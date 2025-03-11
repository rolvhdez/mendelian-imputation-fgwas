#!/bin/bash
# Install Rust
if ! [ -f "$HOME/.rustup/settings.toml" ]; then
    echo "Installing Rust..."
    curl -sSf https://sh.rustup.rs | sh -s -- -y
    . "$HOME/.cargo/env"
fi

# Create Conda environment
CONDA_ENV="myenv"

if ! conda env list | grep -q "$CONDA_ENV"; then
    echo "Creating Conda environment '$CONDA_ENV'..."
    conda create -n "$CONDA_ENV" python=3.9 --yes
fi

# Activate Conda environment
eval "$(conda shell.bash hook)"
conda activate "$CONDA_ENV"

# Install Python packages
if ! pip freeze | grep -q "^snipar"; then
    echo "Installing required Python packages..."
    pip install --upgrade pip
    pip install -r requirements.txt
fi

clear

# Run the pedigree reconstruction
if [ -f /tmp/pedigree.txt ]; then
    echo "Pedigree already exists. Check /tmp/pedigree.txt"
else
    echo "Running pedigree reconstruction..."
    python pedigree_reconstruct.py
    echo "Pedigree created. Check /tmp/pedigree.txt"
fi
