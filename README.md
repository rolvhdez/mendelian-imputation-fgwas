# Family-based GWAS workflow: SNIPAR

A protocol to run a FGWAS with imputations according to Young, *et al*. ([2022]()); Guan, *et al.* ([2025]()).

## Run the workflow

1. Define the next variables in your console:

    ```bash
    export out_dir="/path/to/your/output/"
    export bed="/path/to/your/bedfile"
    export baseline="/path/to/your/baseline.csv"
    export kinship="/path/to/your/kinship.seg"
    export pcs="/path/to/your/pcs.txt"
    export chr_range="1 5 8-10 22" # string autosomal chromosomes to run
    ```

    >**Important**
    >
    >Once you have defined the variables in your terminal, **do not switch terminal**. All the variables are defined within your terminal. Alternatively, you could define them in a `.bashrc` when creating your environment.

2. Create the input files for the FGWAS:

    ```shell
    python resources/build_inputs.py --baseline $baseline --kinship $kinship --pcs $pcs --outDir $out_dir
    ```

3. (Optional, and not recommended) Run the IBD segments inference. Just run it if you are doing tests, you are using special data or forgot to log it. It will take a while, so why not go for a coffee...

	```shell
	./run_ibd.sh
	```

4. (Optional, and not recommended) Run the Mendelian Imputation. Same as above.

	```shell
	./run_imputation.sh
	```

6. Run the FGWAS model you want to use. Provide a number for the phenotype you want to run the FGWAS on. For example, a FGWAS with the *robust estimator* (Guan *et al.*, 2025) on BMI (125) would be:

    ```shell
    ./fgwas/robust.sh 125
    ```

## Set up the environment
### Manually
> Useful for creating [DNAnexus]() snapshots.

1. Install both versions of PLINK

	```shell
	# PLINK 2.0
	wget https://s3.amazonaws.com/plink2-assets/alpha6/plink2_linux_avx2_20250420.zip && \
	unzip plink2_linux_avx2_20250420.zip -d plink2/ && \
	sudo mv plink2/plink* /usr/local/bin/ && \
	rm -rf plink2/ plink*.zip
	```
	```shell
	# PLINK 1.9
	wget https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20241022.zip && \
	unzip plink_linux_x86_64_20241022.zip -d plink/
	sudo mv plink/plink /usr/local/bin/ && \
	rm -rf plink/ plink*.zip
	```

2. Install Conda

	```shell
	# Download CONDA
	wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
	```
	```shell
	# Run the installation script, and follow the instructions
	sh Miniconda3-latest-Linux-x86_64.sh
	```
	```shell
	# Activate it, and unable automatic start
	source ~/.bashrc && conda config --set auto_activate_base false
	```

3. Install Rust
	```shell
	# Download
	curl -sSf https://sh.rustup.rs | sh -s -- -y
	```
	```shell
	# Activate it
	. "$HOME/.cargo/env"
	```

### Docker
A `Dockerfile` for the [rolvhdez/snipflow:v0.1](https://hub.docker.com/repository/docker/rolvhdez/snipflow/general) image is provided. To build locally:

```shell
docker build -t snipflow .
```

Or you could also download the latest version in development.

```shell
docker pull rolvhdez/snipflow:latest
```