# Pedigree reconstruction

To run the whole workflow, grant the permissions to execute the BASH scripts (`.sh`):

```shell
chmod +x create_inputfiles.sh
chmod +x run_fgwas.sh
```

And run them.

>**Important note!**
>
>The script `create_inputfiles.sh` by default installs snipar_v0.0.18 (Young et al., 2023), snipar_v0.0.20 (Guan et al., 2025) is in the script, but is commented. 

This will create two essential input files to run the FGWAS in [snipar](https://github.com/AlexTISYoung/snipar/tree/master) according to the specifications of its [documentation](https://snipar.readthedocs.io/en/latest/input%20files.html):

1. Pedigree (`/tmp/pedigree.txt`): Tab separated table with only parent-offspring (PO) relationships identified previously from [KING](https://www.kingrelatedness.com/) relationship IDB-based inference, and using snipar's pedigree reconstruction script.
2. Phenotype (`/tmp/phenotype.txt`): Phenotype table with IDs for individuals and families. By default, the file created only include phenotype 111 (height), but can be changed.

## Tip for further development 

You can further remove the "*missing parent code*", using the next regex: `^\d+___(M/P)$`. It is left for the user choose when to use it.

If writing a BASH script is more efficient, a recommended line to remove them is:

```shell
cut -d" " -f1-3 /tmp/pedigree.txt | sed -E 's/\t[0-9]+___(M|P)/\t/g'
```