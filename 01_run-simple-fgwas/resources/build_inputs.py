#!/usr/bin/env python3
import argparse
import numpy as np
import pandas as pd
import os, sys
from snipar.pedigree import create_pedigree

from utils.norm import int_normalization as intnorm
from utils import gtw

def main():
    parser = argparse.ArgumentParser(
        description='Process raw files from MCPS to create according input files for SNIPAR.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        '--baseline', 
        type=str,
        required=True,
        help='Baseline survey data file (.csv)'
    )
    parser.add_argument(
        '--kinship', 
        type=str,
        required=True,
        help='Kinship data file (.seg)'
    )
    parser.add_argument(
        '--outDir', 
        type=str,
        required=True,
        help='Output directory.'
    )
    args = parser.parse_args()
    input_paths = [args.kinship, args.baseline]

    # Import data
    kinship = gtw.Data_Gateway(input_paths[0]).load_table()
    baseline = gtw.Data_Gateway(input_paths[1]).load_csv()

    # Make KINSHIP catalogue for FID and IID
    dfk1 = kinship[["FID1", "ID1"]].rename(columns={"FID1": "FID", "ID1": "IID"})
    dfk2 = kinship[["FID2", "ID2"]].rename(columns={"FID2": "FID", "ID2": "IID"})
    long_kinship = pd.concat([dfk1, dfk2]).drop_duplicates()

    # Get the KINSHIP IIDs to the BASELINE FORMAT
    long_kinship["PATID"] = long_kinship.iloc[:, 1].str.extract(r"^\w+\_(\w+\d+)\_\w+")[0]

    # Make a join with BASELINE to get the IID and FID
    baseline = baseline.merge(
        long_kinship[["FID", "IID", "PATID"]],
        left_on="PATID",
        right_on="PATID",
        how="left"
    )
    baseline = baseline.drop(["PATID"], axis=1)

    # Create: Pedigree
    gtw.Data_Gateway.export(
        {
            "kinship" : kinship[["FID1", "ID1", "FID2", "ID2", "InfType"]], 
            "agesex" : baseline[["FID", "IID", "AGE", "MALE"]]
                            .replace({"MALE": {0: "F", 1: "M"}})
                            .rename(columns={"PATID":"IID", "MALE":"sex", "AGE":"age"})
        },
        output_dir=args.outDir,
        extension="csv",
        sep="\t",
        temp=False
    )
    pedigree = create_pedigree(
        king_address = f"{args.outDir}/kinship.csv",
        agesex_address = f"{args.outDir}/agesex.csv"
    )

    # Create: Covars
    covars = baseline[["FID", "IID", "AGE", "MALE"]]

    # Create: Phenotype
    baseline = baseline.drop(["FID"], axis=1)
    baseline = baseline.merge(pedigree[["FID", "IID"]], on="IID", how="left")
    cols_to_move = ["FID", "IID"] # columns to move to the beginning

    for col in reversed(cols_to_move): # Use reversed to maintain the order of cols_to_move
        column = baseline.pop(col)
        baseline.insert(0, col, column)

    phen_cols = ["AGE", "MALE", "YEAR_RECRUITED", "MONTH_RECRUITED", "COYOACAN", "MARITAL_STATUS"]
    phenotype = baseline.drop(phen_cols, axis=1)
    phenotype["BMI"] = phenotype["WEIGHT"] / (phenotype["HEIGHT"])**2 # calculate BMI
    phenotype.iloc[:, 2:] = intnorm(phenotype.iloc[:, 2:]) # normalize based on INT
    phenotype.iloc[:, 2:] = phenotype.iloc[:, 2:].fillna("NA") # fill NA's as described `here <https://github.com/AlexTISYoung/snipar/blob/553e7ac1b2d0cecdede013c8907843fd79b1dcf6/snipar/read/phenotype.py#L8>`
    phenotype = phenotype[phenotype[["FID", "IID"]].notnull().all(axis=1)]  # filter non-genotyped individuals
    phenotype = phenotype.sort_values(by=["FID", "IID"]) # sort by FID and IID

    # Export: see the specifications: <https://snipar.readthedocs.io/en/latest/input%20files.html>
    gtw.Data_Gateway.export(
        {
            "pedigree" : pedigree,
            "phenotype" : phenotype,
            "covariates" : covars
        },
        extension="txt",
        sep=" ",
        temp=False,
        output_dir=args.outDir
    )

if __name__ == "__main__":
    main()