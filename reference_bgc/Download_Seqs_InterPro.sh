 #!/bin/bash

# Check if the input arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <domain_id> <taxon_id> <output_file>"
    echo "Example: $0 IPR050087 1117 output.fasta"
    exit 1
fi

DOMAIN_ID=$1
TAXON_ID=$2
OUTPUT_FILE=$3

BASE_URL="https://www.ebi.ac.uk:443/interpro/api/protein/UniProt/entry/InterPro/${DOMAIN_ID}/taxonomy/uniprot/${TAXON_ID}/?page_size=200&extra_fields=sequence"
HEADER_SEPARATOR="|"
LINE_LENGTH=80

# Initialize variables
NEXT_URL="$BASE_URL"
ATTEMPTS=0

# Create or clear the output file
> "$OUTPUT_FILE"

# Function to fetch data from the API
fetch_data() {
    local url=$1
    curl -s -H "Accept: application/json" "$url"
}

# Loop through pages of the API
while [ -n "$NEXT_URL" ]; do
    RESPONSE=$(fetch_data "$NEXT_URL")

    # Check if the response is empty or an error occurred
    if [ -z "$RESPONSE" ]; then
        if [ "$ATTEMPTS" -lt 3 ]; then
            ATTEMPTS=$((ATTEMPTS + 1))
            sleep 61
            continue
        else
            echo "Error: Failed to fetch data after 3 attempts." >&2
            exit 1
        fi
    fi

    # Reset attempts on successful fetch
    ATTEMPTS=0

    # Extract the next URL
    NEXT_URL=$(echo "$RESPONSE" | jq -r '.next // empty')

    # Process each result
    echo "$RESPONSE" | jq -c '.results[]' | while read -r ITEM; do
        ACCESSION=$(echo "$ITEM" | jq -r '.metadata.accession')
        NAME=$(echo "$ITEM" | jq -r '.metadata.name')
        SEQUENCE=$(echo "$ITEM" | jq -r '.extra_fields.sequence')

        # Extract entries if available
        ENTRIES=$(echo "$ITEM" | jq -c '.entries // []')
        ENTRIES_HEADER=""
        if [ "$ENTRIES" != "[]" ]; then
            ENTRIES_HEADER=$(echo "$ENTRIES" | jq -r '.[] | "\(.accession)(\(.entry_protein_locations[] | .fragments[] | .start)"')
        fi

        # Write the header
        echo ">$ACCESSION$HEADER_SEPARATOR$ENTRIES_HEADER$HEADER_SEPARATOR$NAME" >> "$OUTPUT_FILE"

        # Write the sequence in chunks
        echo "$SEQUENCE" | fold -w $LINE_LENGTH >> "$OUTPUT_FILE"
    done

    # Wait before the next request
    sleep 1
done

echo "Sequences saved to $OUTPUT_FILE"