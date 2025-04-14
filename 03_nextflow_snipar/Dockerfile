FROM continuumio/miniconda3

USER root

# Install system dependencies
RUN apt-get update -y && \
	apt-get -y install build-essential zlib1g zlib1g-dev bzip2 libbz2-dev liblzma-dev wget unzip

# Install Rust
RUN curl -sSf https://sh.rustup.rs | sh -s -- -y
RUN echo 'source $HOME/.cargo/env' >> $HOME/.bashrc

# Install PLINK (equivalent to install-plink in Makefile)
ENV PLINK_DIR="/usr/local/bin/plink"
RUN mkdir -p ${PLINK_DIR} && \
    wget https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20241022.zip -O "${PLINK_DIR}/plink.zip" && \
    unzip "${PLINK_DIR}/plink.zip" -d "${PLINK_DIR}" && \
    rm "${PLINK_DIR}/plink.zip" && \
    chmod +x "${PLINK_DIR}/plink"

RUN echo "export PATH=${PLINK_DIR}:$PATH" >> $HOME/.bashrc
RUN . $HOME/.bashrc

# Installing Python v3.9 dependencies
ADD environment.yml /tmp/environment.yml
RUN conda env create -f /tmp/environment.yml

# Pull the environment name out of the environment.yml
RUN echo "source activate $(head -1 /tmp/environment.yml | cut -d' ' -f2)" > ~/.bashrc
ENV PATH /opt/conda/envs/$(head -1 /tmp/environment.yml | cut -d' ' -f2)/bin:$PATH