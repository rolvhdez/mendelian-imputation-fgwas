"""
0. Preamble: Preparing execution environment.
"""

# Import libraries
import numpy as np
import pandas as pd
import os,sys
import gateway as gate

# Define inputs paths
input_paths = [
      '/mnt/project/Data/KING-IBD/king_ibdseg_4th.seg' # kinship
    , '/mnt/project/Data/Baseline/MCPS BASELINE.csv' # survey
]

"""
1. Read and prepare the data
"""

# Import data
df_kinship = gate.Data_Gateway(input_paths[0]).load_table()
df_baseline = gate.Data_Gateway(input_paths[1]).load_csv()

# Change participant id's so they match the baseline
for col in df_kinship[['ID1','ID2']]:
    new_col = df_kinship[col].str[5:18]
    df_kinship[col] = new_col

# Add FID to Baseline
dfk1 = df_kinship[["FID1","ID1"]].rename(columns={"FID1":"FID","ID1":"IID"})
dfk2 = df_kinship[["FID2","ID2"]].rename(columns={"FID2":"FID","ID2":"IID"})
long_kinship = pd.concat([dfk1,dfk2]).drop_duplicates()

df_baseline = df_baseline.merge(
    long_kinship,
    how="inner",
    left_on="PATID", right_on="IID"
).drop("IID",axis=1)

# Create agesex
agesex = df_baseline[["FID","PATID","AGE","MALE"]].replace(
    # replace boolean value for integer: M = Male, F = Female
    {'MALE': {0:'F', 1:'M'}}
).rename( 
    # change column names
    columns={"PATID":"IID", "MALE":"sex", "AGE":"age"}
)

# Export files
gate.Data_Gateway.export(
    {
        "kinship": df_kinship[["FID1","ID1","FID2","ID2","InfType"]],
        "agesex": agesex
    },
    extension = "csv",
    sep = "\t",
    temp = True
)

"""
2. Reconstruct pedigree
"""

from snipar.pedigree import create_pedigree

pedigree = create_pedigree(
    king_address = "/tmp/kinship.csv",
    agesex_address = "/tmp/agesex.csv",
)

gate.Data_Gateway.export(
    {"pedigree": pedigree},
    extension = "txt",
    sep = "\t",
    temp = True
)