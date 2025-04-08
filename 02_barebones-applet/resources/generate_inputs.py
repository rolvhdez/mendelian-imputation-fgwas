# Import libraries
import argparse
import numpy as np
import pandas as pd
import os, sys
from snipar.pedigree import create_pedigree
from normalization import int_normalization as intnorm

import gateway as gate

def main():
    parser = argparse.ArgumentParser(
        description='Process kinship and baseline data to create pedigree and phenotype files',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

    parser.add_argument(
        '--kinship', 
        type=str,
        required=True,
        help='Path to kinship data file (KING-IBD format)'
    )

    parser.add_argument(
        '--baseline', 
        type=str,
        required=True,
        help='Path to baseline survey data file'
    )

    parser.add_argument(
        '--out',
        type=str,
        default='output',
        help='Path to output directory'
    )

    args = parser.parse_args()
    input_paths = [args.kinship, args.baseline]

    """
    1. Read and prepare data
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
    kinship_path = f"{args.out}kinship"
    agesex_path = f"{args.out}agesex"
    gate.Data_Gateway.export(
        {
            kinship_path : kinship[["FID1", "ID1", "FID2", "ID2", "InfType"]], 
            agesex_path : agesex
        },
        extension="csv",
        sep="\t",
        temp=True,
    )

    print("Reconstructing pedigree...")
    pedigree = create_pedigree(
        king_address=f"{kinship_path}.csv",
        agesex_address=f"{agesex_path}.csv",
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

    phenotype = baseline.drop(
        ["AGE", "MALE", "YEAR_RECRUITED", "MONTH_RECRUITED", "COYOACAN", "MARITAL_STATUS"],
        axis=1,
    )

    phenotype["BMI"] = phenotype["WEIGHT"] / (phenotype["HEIGHT"])**2 # calculate BMI
    phenotype.iloc[:, 2:] = intnorm(phenotype.iloc[:, 2:]) # normalize based on INT
    phenotype.iloc[:, 2:] = phenotype.iloc[:, 2:].fillna("NA") # fill NA's as described `here <https://github.com/AlexTISYoung/snipar/blob/553e7ac1b2d0cecdede013c8907843fd79b1dcf6/snipar/read/phenotype.py#L8>`
    phenotype = phenotype[phenotype[["FID", "IID"]].notnull().all(axis=1)]  # filter non-genotyped individuals
    phenotype = phenotype.sort_values(by=["FID", "IID"]) # sort by FID and IID

    # TEMPORARY: SELECT UNTIL KNOWKING THE COLUMN NUMBER OF BMI
    phenotype = phenotype[["FID","IID","BMI"]]

    # Export
    ped_path = f"{args.out}pedigree"
    phe_path = f"{args.out}phenotype"
    gate.Data_Gateway.export(
        {
            ped_path : pedigree,
            phe_path : phenotype
        },
        # see the specifications: <https://snipar.readthedocs.io/en/latest/input%20files.html>
        extension="txt",
        sep=" ",
        temp=True
    )

if __name__ == "__main__":
    main()