# Pedigree reconstruction

To run the whole workflow, grant the permissions to execute the `.sh` and run:

```shell
chmod +x run_workflow.sh
./run_workflow.sh
```

This will essentially create a pedigree file in `/tmp/pedigree.txt` using the [snipar]() algorithm to create a pedigree using kinship relationships (parent-offspring pairs) and age-sex information for each individual:

```python
from snipar.pedigree import create_pedigree
pedigree = create_pedigree(
    king_address = "/tmp/kinship.csv",
    agesex_address = "/tmp/agesex.csv",
)
```

The `/tmp/pedigree.txt` file is a tab separated table that only contains parent-offspring relationships and its composed of the columns:

   - `FID` (int): Family ID. Assigned by the function, overrides the one from user (file).
   - `IID` (chr): Individual ID. Provided by the user (file).
   - `FATHER_ID` (chr): Father ID. Coalesed as`0___P` if *missing* (`0` is `FID`). 
   - `MOTHER_ID` (chr): Mother ID. Coalesed as`0___M` if *missing* (`0` is `FID`). 

## Tip for further development 

You can further remove the "*missing parent code*", using the next regex: `^\d+___(M/P)$`. It is left for the user choose when to use it.

If writing a BASH script is more efficient, a recommended line to remove them is:

```shell
cut -d"t" -f1-4 /tmp/pedigree.txt | sed -E 's/\t[0-9]+___(M|P)/\t/g'
```
