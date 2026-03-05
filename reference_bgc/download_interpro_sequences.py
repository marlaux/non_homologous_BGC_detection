import json
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

def download_interpro_sequences(domain_id, taxon_id, output_file):
    """
    Download sequences from UniProt for accessions identified via InterPro.

    Args:
        domain_id (str): InterPro domain ID (e.g., PS51747).
        taxon_id (str): Taxonomy ID (e.g., 1117 for Cyanobacteria).
        output_file (str): Path to save the downloaded sequences in FASTA format.
    """
    interpro_api_url = "https://www.ebi.ac.uk/interpro/api"
    uniprot_api_url = "https://rest.uniprot.org/uniprotkb/"

    categories = ["reviewed", "unreviewed"]

    try:
        with open(output_file, 'w') as file:
            for category in categories:
                next_url = f"{interpro_api_url}/protein/{category}/entry/interpro/{domain_id}/taxonomy/uniprot/{taxon_id}/?page_size=200"

                while next_url:
                    try:
                        with urlopen(next_url) as res:
                            data = json.loads(res.read().decode("utf-8"))

                        for result in data.get("results", []):
                            metadata = result.get("metadata", {})
                            accession = metadata.get("accession")
                            sequence_url = f"{uniprot_api_url}{accession}.fasta"

                            retries = 3  # Number of retries for each request
                            while retries > 0:
                                try:
                                    with urlopen(sequence_url, timeout=60) as seq_res:  # Increased timeout to 60 seconds
                                        fasta_data = seq_res.read().decode("utf-8")
                                        file.write(fasta_data)
                                    break  # Exit retry loop if successful
                                except URLError as e:
                                    retries -= 1
                                    if retries == 0:
                                        print(f"Failed to fetch sequence for {accession} after multiple attempts: {e}")
                                    else:
                                        print(f"Retrying sequence for {accession} due to error: {e}. Remaining retries: {retries}")
                                        time.sleep(5)  # Wait 5 seconds before retrying

                        # Check for next page
                        next_url = data.get("next")
                    except HTTPError as e:
                        print(f"Failed to retrieve data for category {category}: {e}")
                        break

    except HTTPError as e:
        print(f"Failed to retrieve data: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python download_interpro_sequences.py <domain_id> <taxon_id> <output_file>")
        sys.exit(1)

    domain_id = sys.argv[1]
    taxon_id = sys.argv[2]
    output_file = sys.argv[3]

    download_interpro_sequences(domain_id, taxon_id, output_file)