#!/bin/bash

# Check if the input files are provided
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <target_protein_file> <GenBank feature table> <evalue> <interpro executable path> <threads>"
    echo "./get_genbank_reference_bgc_domains.sh target_protein_file.faa target_feature_table.ft 0.05 /path/to/interproscan 20"
    exit 1
fi

TARGET_FASTA=$1
FEATURE_TABLE=$2
EVALUE=$3
INTERPROSCAN_PATH=$4
THREADS=$5
TARGET_PREFIX=$(basename "$TARGET_FASTA" .faa)

# Use the provided InterProScan directory path directly
if [ -f "${TARGET_FASTA}.tsv" ]; then
    echo "Interproscan output already exists: ${TARGET_FASTA}.tsv. Skipping interproscan."
else
    # Run interproscan
    ${INTERPROSCAN_PATH}/interproscan.sh -i "$TARGET_FASTA" -f TSV -cpu ${THREADS}
fi

# Load in Python to filter domains and get the features
python3 <<EOF
import pandas as pd
import re

# Load interproscan output
interpro_output = pd.read_csv(f"${TARGET_FASTA}.tsv", sep="\t", header=None,
                              names=["protein", "sequence", "seq_len", "analysis", "signature_acc", "signature_desc", "start", "stop", "score", "status", "date", "interpro_acc", "interpro_desc", "GO_annotations", "Pathways_annotations"])
interpro_output = interpro_output[interpro_output['score'] != '-']
interpro_output['score'] = interpro_output['score'].astype(float)
# Filter signatures by evalue
filtered_output = interpro_output[interpro_output['score'] < $EVALUE]
# Create significant domains file
filtered_domains = filtered_output[["protein", "seq_len", "score", "analysis", "signature_acc", "signature_desc", "interpro_acc", "interpro_desc"]].drop_duplicates()

# Remove the intermediate output file creation and directly merge the data
# Merge filtered_domains and feature table
input_file = "${FEATURE_TABLE}"

# Parse the GenBank feature table into a DataFrame
features = []
current_protein = None
current_product = None

with open(input_file, "r") as infile:
    for line in infile:
        line = line.strip()
        if "CDS" in line:
            if current_protein and current_product:
                features.append([current_protein, current_product])
            current_protein = None
            current_product = None
        elif line.startswith("protein_id"):
            current_protein = line.split("\t")[-1].replace("gb|", "").replace("|", "")
        elif line.startswith("product"):
            current_product = line.split("\t")[-1]

    if current_protein and current_product:
        features.append([current_protein, current_product])

# Convert features to a DataFrame
features_df = pd.DataFrame(features, columns=["protein", "product"])

# Merge filtered_domains and feature table
filtered_domains_features = pd.merge(filtered_domains, features_df, on="protein", how="left")

# Save the final merged output
filtered_domains_features.to_csv(f"${TARGET_PREFIX}_filtered_domains.tab", sep="\t", index=False)

# get list of significant domain ids by protein
# Group by 'protein' and 'product' and get the unique 'interpro_acc'
filtered_interpro_by_protein = filtered_domains_features.groupby(['protein'])['interpro_acc'].unique()
filtered_domains_by_protein = filtered_domains_features.groupby(['protein'])['signature_acc'].unique()

# Save the significant domain ids and interpro ids
with open(f"${TARGET_PREFIX}_domains_by_protein.txt", "w") as outfile:
    for (protein), domain_ids in filtered_domains_by_protein.items():
        interpro_ids = filtered_interpro_by_protein.get((protein), [])
        outfile.write(f"{protein}\t{','.join(domain_ids)}\t{','.join(interpro_ids)}\n")
EOF