#!/usr/bin/env python3

# standard library modules
import sys, json, ssl
from urllib import request
from urllib.error import HTTPError
from time import sleep
import argparse

def count_sequences(domain_id, taxon_id):
    BASE_URL = f"https://www.ebi.ac.uk:443/interpro/api/protein/UniProt/entry/InterPro/{domain_id}/taxonomy/uniprot/{taxon_id}/?page_size=200"

    # Disable SSL verification to avoid config issues
    context = ssl._create_unverified_context()

    next_url = BASE_URL
    total_count = 0

    while next_url:
        try:
            req = request.Request(next_url, headers={"Accept": "application/json"})
            res = request.urlopen(req, context=context)

            # If the API times out due to a long-running query
            if res.status == 408:
                sleep(61)
                continue
            elif res.status == 204:
                # No data, so leave the loop
                break

            payload = json.loads(res.read().decode())
            total_count += len(payload["results"])
            next_url = payload.get("next")

            # Don't overload the server, give it time before asking for more
            sleep(1)
        except HTTPError as e:
            if e.code == 408:
                sleep(61)
                continue
            else:
                sys.stderr.write("Error: " + str(e) + "\n")
                sys.exit(1)

    print(f"Total sequences for domain {domain_id} and taxon {taxon_id}: {total_count}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Count sequences from InterPro API.")
    parser.add_argument("domain_id", help="InterPro domain ID (e.g., IPR050087)")
    parser.add_argument("taxon_id", help="Taxonomy ID (e.g., 1117)")

    args = parser.parse_args()

    count_sequences(args.domain_id, args.taxon_id)