"""
0. Preamble: Preparing execution environment.
"""

# Import libraries
import numpy as np
import pandas as pd
import os, sys
import gateway as gate

# Define inputs paths
input_paths = [
    "/mnt/project/Data/KING-IBD/king_ibdseg_4th.seg",  # kinship (file-GkVP8F004Qxf473bpkF4P0pK)
    "/mnt/project/Data/Baseline/MCPS BASELINE.csv",  # survey (file-GV4X4Vj0gy50pGb6KXK144FX)
]

"""
1. Read and prepare the data
"""

# Import data
kinship = gate.Data_Gateway(input_paths[0]).load_table()
baseline = gate.Data_Gateway(input_paths[1]).load_csv()

# Make KINSHIP catalogue for FID and IID
dfk1 = kinship[["FID1", "ID1"]].rename(columns={"FID1": "FID", "ID1": "IID"})
dfk2 = kinship[["FID2", "ID2"]].rename(columns={"FID2": "FID", "ID2": "IID"})
long_kinship = pd.concat([dfk1, dfk2]).drop_duplicates()

# Get the KINSHIP IIDs to the BASELINE FORMAT
long_kinship["PATID"] = long_kinship.iloc[:, 1].str.extract(r"^\w+\_(\w+\d+)\_\w+")[0]

# Make a join with BASELINE to get the IID and FID
baseline = baseline.merge(
    long_kinship[["FID", "IID", "PATID"]], left_on="PATID", right_on="PATID", how="left"
)
baseline = baseline.drop(["PATID"], axis=1)

"""
2. Pedigree
"""
# Create agesex
agesex = (
    baseline[["FID", "IID", "AGE", "MALE"]]
    .replace(
        # replace boolean value for integer: M = Male, F = Female
        {"MALE": {0: "F", 1: "M"}}
    )
    .rename(
        # change column names
        columns={"PATID": "IID", "MALE": "sex", "AGE": "age"}
    )
)

# Export temporary files
gate.Data_Gateway.export(
    {"kinship": kinship[["FID1", "ID1", "FID2", "ID2", "InfType"]], "agesex": agesex},
    extension="csv",
    sep="\t",
    temp=True,
)

# Reconstruct the pedigree
from snipar.pedigree import create_pedigree

pedigree = create_pedigree(
    king_address="/tmp/kinship.csv",
    agesex_address="/tmp/agesex.csv",
)

"""
3. Phenotype
"""
baseline = baseline.drop(["FID"], axis=1)
baseline = baseline.merge(pedigree[["FID", "IID"]], on="IID", how="left")

# Columns to move to the beginning
cols_to_move = ["FID", "IID"]

# Move columns to the beginning
for col in reversed(cols_to_move):  # Use reversed to maintain the order of cols_to_move
    column = baseline.pop(col)
    baseline.insert(0, col, column)

# Create the phenotype file
phenotype = baseline.drop(
    ["AGE", "MALE", "YEAR_RECRUITED", "MONTH_RECRUITED", "COYOACAN", "MARITAL_STATUS"],
    axis=1,
)

# JUST FOR TESTS!!!
phenotype["BMI"] = phenotype["WEIGHT"] / ( phenotype["HEIGHT"] )**2
phenotype = phenotype[["FID", "IID", "BMI"]]  # FID, IID, HEIGHT

# Normalize to Inverse Normal Transform (INT)
from normalization import int_normalization as intnorm

phenotype.iloc[:, 2:] = intnorm(phenotype.iloc[:, 2:])

# Fill NA's as described `here <http://zzz.bwh.harvard.edu/plink/data.shtml#pheno>`
# phenotype.iloc[:, 2:] = phenotype.iloc[:, 2:].fillna(-9) 

# Final adjusments
phenotype = phenotype[phenotype[["FID", "IID"]].notnull().all(axis=1)]  # filter nulls
phenotype = phenotype.sort_values(by=["FID", "IID"])  # sort by FID and IID

"""
4. Export files
"""

gate.Data_Gateway.export(
    {"pedigree": pedigree, "phenotype": phenotype}, extension="txt", sep=" ", temp=True
)
