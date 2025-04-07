SHELL=/bin/bash -e -x -o pipefail
PLINK_DIR="/opt/notebooks/bin/plink"
VERSION=0.0.1

.PHONY: all install-plink clean
all: install-dependencies install-plink install-rustup

install-dependencies:
	apt-get update -y
	apt-get -y install build-essential git zlib1g zlib1g-dev bzip2 libbz2-dev liblzma-dev wget python python-dev

install-rustup:
	curl -sSf https://sh.rustup.rs | sh -s -- -y
	. "${HOME}/.cargo/env"
    
install-plink:
	mkdir -p ${PLINK_DIR}
	wget https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20241022.zip -O "${PLINK_DIR}/plink.zip"
	unzip "${PLINK_DIR}/plink.zip" -d "${PLINK_DIR}"
	rm "${PLINK_DIR}/plink.zip"
	chmod +x "${PLINK_DIR}/plink"
	@echo "PLINK installed to $(PLINK_EXE)"
	@echo "Add this to your shell configuration (.bashrc, .zshrc, etc.):"
	@echo 'export PATH=$$PATH:$(PLINK_DIR)'