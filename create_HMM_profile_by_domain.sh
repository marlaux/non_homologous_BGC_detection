#!/bin/bash

# Check if the input files are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <interpro_fasta_file> <signature_acc> <interpro_member> <output_prefix>"
    echo "Members: AntiFam,CDD,Coils,FunFam,Gene3D,Hamap,MobiDBLite,NCBIfam,PANTHER,Pfam,PIRSF,PIRSR,PRINTS,ProSitePatterns,ProSiteProfiles,SFLD,SMART,SUPERFAMILY"
    exit 1
fi

INTERPRO_FASTA=$1
SIGNATURE_ACC=$2
INTERPRO_MEMBER=$3
PREFIX=$4

# Check if the filename contains a dot (.)
if [[ "$(basename "$INTERPRO_FASTA" .fasta)" == *.* ]]; then
    echo "Error: The filename of the input file (interpro_fasta_file) cannot contain a dot (.)"
    exit 1
fi

INTERPRO_PREFIX=$(basename "$INTERPRO_FASTA" .fasta)

# Check if the filtered BED file already exists
if [ -f "${INTERPRO_PREFIX}.bed" ]; then
    echo "Filtered BED file already exists: ${INTERPRO_PREFIX}_${SIGNATURE_ACC}.bed. Skipping BED file generation and bedtools command."
else
    # Check if the interproscan output exists
    if [ -f "${INTERPRO_PREFIX}.fasta.tsv" ]; then
        echo "Interproscan output already exists: ${INTERPRO_PREFIX}.fasta.tsv. Skipping interproscan."
    else
        # Step 2: Run interproscan
        if [ "$INTERPRO_MEMBER" == "interpro" ]; then
            # Run all databases (no --appl argument)
            /home/marlaux/interproscan-5.76-107.0/interproscan.sh -i "$INTERPRO_FASTA" -f TSV -cpu 12
        else
            # Run specific database
            /home/marlaux/interproscan-5.76-107.0/interproscan.sh -i "$INTERPRO_FASTA" -f TSV -cpu 12 -appl $INTERPRO_MEMBER
        fi
    fi

    # Step 3: Load in Python to select specific signature_acc and create a bed file
    python3 <<EOF
import pandas as pd

# Load interproscan output
interpro_output = pd.read_csv(f"${INTERPRO_PREFIX}.fasta.tsv", sep="\t", header=None,
                              names=["protein", "sequence", "seq_len", "analysis", "signature_acc", "signature_desc", "start", "stop", "score", "status", "date", "interpro_acc", "interpro_desc", "GO_annotations", "Pathways_annotations"])

# Filter by specific signature_acc and create bed file
filtered_bed = interpro_output[(interpro_output['signature_acc'] == "$SIGNATURE_ACC") | (interpro_output['interpro_acc'] == "$SIGNATURE_ACC")][['protein', 'start', 'stop', 'signature_desc']].drop_duplicates()
filtered_bed.to_csv(f"${INTERPRO_PREFIX}.bed", sep='\t', index=False, header=False)
EOF

    # Step 4: Run bedtools to extract the exact fasta sequence
    bedtools getfasta -fi "$INTERPRO_FASTA" -bed "${INTERPRO_PREFIX}.bed" > "${INTERPRO_PREFIX}.faa"
fi

# Step 5: Align the extracted sequences with mafft
mafft --auto --clustalout --thread 12 "${INTERPRO_PREFIX}.faa" > "${INTERPRO_PREFIX}.aln"

# activate antismash conda environment
source /home/marlaux/miniconda3/etc/profile.d/conda.sh
conda activate antismash

# Step 6: Run hmmbuild to create a hmm profile
hmmbuild "${PREFIX}_${SIGNATURE_ACC}.hmm" "${INTERPRO_PREFIX}.aln"

# Step 7: Run hmmpress in the hmm profile
hmmpress "${PREFIX}_${SIGNATURE_ACC}.hmm"

# check if the .hmm file was created and is not empty
if [ -s "${PREFIX}_${SIGNATURE_ACC}.hmm" ]; then
    rm "${INTERPRO_PREFIX}.bed" "${INTERPRO_PREFIX}.faa" "${INTERPRO_PREFIX}.aln"
    rm "${PREFIX}_${SIGNATURE_ACC}.hmm.h3m" "${PREFIX}_${SIGNATURE_ACC}.hmm.h3i" "${PREFIX}_${SIGNATURE_ACC}.hmm.h3f" "${PREFIX}_${SIGNATURE_ACC}.hmm.h3p"
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "HMM profile created successfully: ${PREFIX}_${SIGNATURE_ACC}.hmm"
    echo "Full HMM profile pipeline completed for $INTERPRO_FASTA, and $SIGNATURE_ACC".
    echo "------------------------------------------------------------------------------"
else
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "Failed to create HMM profile: ${INTERPRO_PREFIX}.hmm"
    echo "------------------------------------------------------------------------------"
fi

conda deactivate


