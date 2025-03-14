import gateway as gate
import pandas as pd

# Define inputs paths (if mounted)
input_paths = [
      '/mnt/project/Data/Baseline/MCPS BASELINE.csv' # survey
    , '/mnt/project/Data/PCs/pc_projections_unrelateds_rsq005_maf05.txt' # gen_ids
]

# Read files
df_baseline = gate.Data_Gateway(input_paths[0]).load_csv()
df_pcs = gate.Data_Gateway(input_paths[1]).load_table()

# Get PC IDs as the BASELINE format
df_pcs["PATID"] = df_pcs.iloc[:,0].str.extract(r'^\w+\_(\w+\d+)\_\w+')[0]

# Add GENOTYPE and FAMILY IDs to BASELINE
phenotype = df_baseline.merge(
    df_pcs[["sample.ID","PATID"]], 
    left_on = "PATID", right_on = "PATID", how = "left"
).rename(columns={"sample.ID":"GTID"})

# Save the New Baseline (gt_baseline = "Genotyped Baseline")
gate.Data_Gateway.export(
    {"phenotype": phenotype},
    extension = "txt",
    sep = " ",
    temp = True
)