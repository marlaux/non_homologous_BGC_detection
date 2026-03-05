#!/bin/bash

# Check if the input files are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <GenBank feature table>"
    echo "./convert_genbank_features_to_table.sh target_feature_table.txt"
    exit 1
fi

FEATURE_TABLE=$1
TARGET_PREFIX=$(basename "$FEATURE_TABLE" .txt)

# Load in Python to select specific signature_acc and create a bed file
python3 <<EOF
import re

input_file = "${FEATURE_TABLE}"
output_file = "${TARGET_PREFIX}.tab"

# Open the input file and prepare the output file
with open(input_file, "r") as infile, open(output_file, "w") as outfile:
    # Write the header row
    outfile.write("protein\tproduct\tregion\tnote\tdb_xref\n")
    
    current_feature = None
    current_product = None
    current_region = None
    current_note = None
    current_db_xref = None

    for line in infile:
        line = line.strip()
        if line.startswith(">Feature"):
            # Write the previous feature's data if available
            if current_feature:
                outfile.write(f"{current_feature}\t{current_product}\t{current_region}\t{current_note}\t{current_db_xref}\n")
            # Start a new feature
            current_feature = line.split("|")[1]
            current_product = current_region = current_note = current_db_xref = None
        elif line.startswith("product"):
            current_product = line.split("\t")[-1]
        elif line.startswith("region"):
            current_region = line.split("\t")[-1]
        elif line.startswith("note"):
            current_note = line.split("\t")[-1]
        elif line.startswith("db_xref"):
            current_db_xref = line.split("\t")[-1]
    
    # Write the last feature's data
    if current_feature:
        outfile.write(f"{current_feature}\t{current_product}\t{current_region}\t{current_note}\t{current_db_xref}\n")
EOF