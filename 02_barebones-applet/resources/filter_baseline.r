# "...excludes participants with previously diagnosed diabetes or an HbA1c level ≥7% at recruitment; those with other chronic diseases (ischemic heart disease, stroke, chronic kidney disease, cirrhosis, cancer, or emphysema) at recruitment; those with missing data on any analysis covariate (sex, district of residence, educational level attained, smoking status, alcohol intake, or leisure-time physical activity), comprising 0.1% of otherwise eligible participants; those with uncertain follow-up (0.8% of otherwise eligible participants); and those with missing data for any anthropometry measure (0.7% of otherwise eligible participants) or extreme measures of anthropometry: height <120 or >200 cm, weight <35 or >250 kg, waist circumference <60 or >180 cm, hip circumference <70 or >180 cm, waist-to-hip ratio <0.5 or >1.5, or BMI <18.5 or >60 kg/m2 (0.7% of otherwise eligible participants)."

suppressPackageStartupMessages(library("dplyr"))

# Define inputs paths
args <- commandArgs(trailingOnly = TRUE)
input_path <- args[1]
output_path <- args[2]

baseline <- read.csv(input_path, header=TRUE, sep=",")

# sex, district of residence, educational level attained, smoking status, 
# alcohol intake, or leisure-time physical activity
covariates <- c("MALE", "COYOACAN", "EDUGP")

filter_baseline <- baseline %>%
    filter(BASE_HBA1C < 7) %>%
    filter(if_any(contains("CANCER"), ~ .x == 0)) %>%
    filter(BASE_EMPHYSEMA == 0) %>%
    filter(BASE_HEARTATTACK == 0) %>%
    filter(BASE_STROKE == 0) %>%
    filter(BASE_CKD == 0) %>% # kidney disease
    filter(BASE_CIRR == 0) %>%
    # missing covariates
    filter(if_any(contains("SMOK"), ~ !is.na(.x))) %>%
    filter(if_any(contains("_ALC"), ~ !is.na(.x))) %>%
    filter(if_any(contains("_PHYS"), ~ !is.na(.x))) %>%
    filter(if_all(all_of(covariates), ~ !is.na(.x)))

# Output
write.csv(
    filter_baseline,
    file=output_path,
    row.names=FALSE,
    quote=TRUE
)