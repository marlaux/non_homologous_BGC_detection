#!/bin/bash

ACCESSION=''
TITLE=''
DB=''
GENOME=''
PACKAGE=''
OUT_PREFIX=''

usage () {
        echo "##################################################"
        echo " "
        echo "DOWNLOAD NCBI SEQUENCES OR GENOME PACKAGE"
        echo " "
        echo "Usage: ${0} [-a accession] [-t GenBank title] [-d protein] [-o output_prefix]"
        echo "Usage: ${0} [-a accession] [-d nucleotide] [-o output_prefix]"
        echo "-a     GenBank accession, e.g MH341392.1"
        echo "-t     Title of GenBank title, required to download proteins"
        echo "-d     database, 'nucleotide' or 'protein'"
        echo "-o     output prefix, e.g. Hcrispum_saxitoxin"
        echo "-h     print this help"
        echo " "
        echo "##################################################"
                > /dev/null 2>&1; exit 1;

}
while getopts "a:t:d:o:g:p:h" option; do
        case $option in
        a) ACCESSION="${OPTARG}"
                ;;
        t) TITLE="${OPTARG}"
                ;;
        d) DB="${OPTARG}"
                ;;
        o) OUT_PREFIX="${OPTARG}"
                ;;
        g) GENOME="${OPTARG}"
                ;;
	p) PACKAGE="${OPTARG}"
                ;;
        h | *) usage
                exit 0
                ;;
        \?) echo "Invalid option: -$OPTARG"
                exit 1
                ;;
   esac
done

if [ -z "${ACCESSION}" ] || [ -z "${OUT_PREFIX}" ] || [ -z "${DB}" ]; then
                echo 'Missing argument' >&2
                exit 1
fi

if [ "$DB" = "nucleotide" ]; then
        esearch -db nuccore -query "${ACCESSION}" | efetch -format gb > "${OUT_PREFIX}.gb"
        esearch -db nuccore -query "${ACCESSION}" | efetch -format ft > "${OUT_PREFIX}.ft"
        esearch -db nuccore -query "${ACCESSION}" | efetch -format ft > "${OUT_PREFIX}.fna"
fi

if [ "$DB" = "protein" ]; then
        if [ -z "${TITLE}" ]; then
            echo "Error: Title is required to download protein sequences." >&2
            exit 1
        fi
        esearch -db nuccore -query "${ACCESSION}" | efetch -format ft > "${OUT_PREFIX}.ft"
        esearch -db protein -query "${TITLE}" | efetch -format fasta >> "${OUT_PREFIX}.faa"
fi
