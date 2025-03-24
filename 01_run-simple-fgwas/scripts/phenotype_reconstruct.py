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

# Make KINSHIP catalogue for FID and IID
dfk1 = df_kinship[["FID1","ID1"]].rename(columns={"FID1":"FID","ID1":"IID"})
dfk2 = df_kinship[["FID2","ID2"]].rename(columns={"FID2":"FID","ID2":"IID"})
long_kinship = pd.concat([dfk1,dfk2]).drop_duplicates()

# Get the KINSHIP IIDs to the BASELINE FORMAT 
long_kinship["PATID"] = long_kinship.iloc[:,1].str.extract(r'^\w+\_(\w+\d+)\_\w+')[0]

# Make a join with BASELINE to get the IID and FID
pre_phenotype = df_baseline.merge(
    long_kinship[["FID", "IID", "PATID"]], 
    left_on = "PATID", right_on = "PATID", how = "left"
)

# Eliminate PATID and get the right IDs order
pheno_cols = pre_phenotype.columns.tolist()
pheno_cols_move = {"FID" : 0, "IID" : 1}

for col in pheno_cols_move:
    pheno_cols.remove(col)
    
for col, pos in sorted(pheno_cols_move.items(), key=lambda x: x[1]):
    pheno_cols.insert(pos, col)
    
pre_phenotype = pre_phenotype[pheno_cols]
phenotype = pre_phenotype.drop(["PATID","AGE","MALE","YEAR_RECRUITED","MONTH_RECRUITED","COYOACAN","MARITAL_STATUS"],axis=1)
phenotype.iloc[:, 2:] = phenotype.iloc[:, 2:].fillna(-9)

# test: just for height (col : 112)
phenotype = phenotype.iloc[:, [0, 1, 112]]

gate.Data_Gateway.export(
    {"phenotype": phenotype[phenotype["IID"].notnull()]},
    extension = "txt",
    sep = " ",
    temp = True
)