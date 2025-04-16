#!/usr/bin/env nextflow

process filterBaseline {
//    publishDir 'test', mode: 'copy'

    input:
    path baseline_file

    output:
    path 'qc_baseline.csv'

    script:
    """
    #!/usr/bin/env python3

    import pandas as pd

    # This is a QC for BMI

    baseline = pd.read_csv("$baseline_file", low_memory=False)
    covariates = ["MALE", "COYOACAN", "EDUGP"]
    filter_baseline = baseline[
        (baseline['BASE_HBA1C'] < 7) &
        (baseline.filter(like='CANCER').eq(0).any(axis=1)) &
        (baseline['BASE_EMPHYSEMA'] == 0) &
        (baseline['BASE_HEARTATTACK'] == 0) &
        (baseline['BASE_STROKE'] == 0) &
        (baseline['BASE_CKD'] == 0) &  # kidney disease
        (baseline['BASE_CIRR'] == 0) &
        # missing covariates
        (baseline.filter(like='SMOK').notna().any(axis=1)) &
        (baseline.filter(like='_ALC').notna().any(axis=1)) &
        (baseline.filter(like='_PHYS').notna().any(axis=1)) &
        (baseline[covariates].notna().all(axis=1))
    ]
    filter_baseline.to_csv("qc_baseline.csv", index=False)
    """
}

process createAgesexKinship {
    input:
    path baseline_file
    path kinship_file

    output:
    path "agesex.csv", emit: "agesex"
    path "kinship.csv", emit: "kinship"

    script:
    """
    #!/usr/bin/env python3

    import pandas as pd

    # Import data
    baseline = pd.read_csv("$baseline_file")
    kinship = pd.read_table("$kinship_file")

    # Make KINSHIP catalogue for FID and IID
    dfk1 = kinship[["FID1", "ID1"]].rename(columns={"FID1": "FID", "ID1": "IID"})
    dfk2 = kinship[["FID2", "ID2"]].rename(columns={"FID2": "FID", "ID2": "IID"})
    long_kinship = pd.concat([dfk1, dfk2]).drop_duplicates()

    # Get the KINSHIP IIDs to the BASELINE FORMAT
    long_kinship["PATID"] = long_kinship.iloc[:, 1].str.extract(r"^\\w+\\_(\\w+\\d+)\\_\\w+")[0]

    # Make a join with BASELINE to get the IID and FID
    baseline = baseline.merge(
        long_kinship[["FID", "IID", "PATID"]], left_on="PATID", right_on="PATID", how="left"
    )
    baseline = baseline.drop(["PATID"], axis=1)

    kinship = kinship[["FID1", "ID1", "FID2", "ID2", "InfType"]]
    agesex = (
        baseline[["FID", "IID", "AGE", "MALE"]]
        .replace(
            # replace boolean value for integer: M = Male, F = Female
            {"MALE": {0: "F", 1: "M"}}
        )
        .rename(
            # change column names
            columns={"MALE": "sex", "AGE": "age"}
        )
    )

    kinship.to_csv("kinship.csv", sep="\t", index=False)
    agesex.to_csv("agesex.csv", sep="\t", index=False)
    """
}

process createPedigree {
    publishDir 'results', mode: 'copy'

    input:
    path agesex_file
    path kinship_file

    output:
    path "pedigree.txt"

    script:
    """
    #!/usr/bin/env python3    
    import pandas as pd
    from snipar.pedigree import create_pedigree

    # Import data
    pedigree = create_pedigree(king_address="$kinship_file", agesex_address="$agesex_file", same_parents_in_ped=True)
    pedigree.to_csv("pedigree.txt", sep=" ", index=False, header=False)
    """
}

process createPhenotype {
    publishDir 'results', mode: 'copy'

    input:
    path baseline_file
    path kinship_file
    path pedigree_file

    output:
    path "phenotype.txt", emit: "phenotype"

    script:
    """
    #!/usr/bin/env python3    

    import pandas as pd
    from scipy.special import ndtri

    def intnorm(x):
        # Creates a Inverse Normal Transformation (INT)
        # for a pandas series (x)

        x_rank = x.rank()
        numerator = x_rank - 0.5 
        par = numerator/len(x)
        x_normalized = ndtri(par)
        
        return x_normalized

    # Import data
    baseline = pd.read_csv("$baseline_file")
    kinship = pd.read_table("$kinship_file")
    pedigree = pd.read_csv("$pedigree_file", sep=" ", header=None, names=["FID", "IID", "FATHER_ID", "MOTHER_ID"])

    # Preliminary baseline transformation
    dfk1 = kinship[["FID1", "ID1"]].rename(columns={"FID1": "FID", "ID1": "IID"})
    dfk2 = kinship[["FID2", "ID2"]].rename(columns={"FID2": "FID", "ID2": "IID"})
    long_kinship = pd.concat([dfk1, dfk2]).drop_duplicates()
    long_kinship["PATID"] = long_kinship.iloc[:, 1].str.extract(r"^\\w+\\_(\\w+\\d+)\\_\\w+")[0]
    baseline = baseline.merge(
        long_kinship[["FID", "IID", "PATID"]], left_on="PATID", right_on="PATID", how="left"
    )
    baseline = baseline.drop(["PATID"], axis=1)

    # Transform baseline
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

    phenotype.to_csv("phenotype.txt", sep="\t", index=False)
    """
}