#!/usr/bin/env bash
#
# Forked from https://github.com/Lirt/markdown-toc-bash/
#
set -euo pipefail

VERSION=0.1.0
PROGRAM=$0
DESCRIPTION="Generate a Table of Contents from Markdown"
UL_SPECIFIER='-'

usage(){
>&2 cat << EOF

Program: ${PROGRAM} (${DESCRIPTION})
Version: ${VERSION}

Usage:   $0 [options] <infile.md>

Options:

     -s | specifier      symbol ("-", "*", or "+") to use for ToC (default: "-")
     -h | help           display this help message
     -v | version        display version

EOF
exit 1
}

print_ver(){
   >&2 echo ${VERSION}
   exit 0
}

args=$(getopt -a -o hvs: --long help,version,specifier: -- "$@")
if [[ $? -gt 0 ]]; then
  usage
fi

eval set -- ${args}
while :
do
  case $1 in
    -h | --help)      usage            ; shift    ;;
    -v | --version)   print_ver        ; shift    ;;
    -s | --specifier) UL_SPECIFIER=$2  ; shift 2  ;;
    --) shift; break ;;
    *) >&2 echo Unsupported option: $1
       usage ;;
  esac
done

if [[ ! ${UL_SPECIFIER} =~ [-+*] ]]; then
   >&2 echo 'Please enter "-", "+", or "*" (with quotes) for the specifier'
   exit 1
fi

if [[ $# -eq 0 ]]; then
  usage
fi

FILE=$1

declare -a TOC
CODE_BLOCK=0
CODE_BLOCK_REGEX='^```'
HEADING_REGEX='^#{1,}'

while read -r LINE; do
    # Treat code blocks
    if [[ "${LINE}" =~ $CODE_BLOCK_REGEX ]]; then
        # Ignore things until we see code block ending
        CODE_BLOCK=$((CODE_BLOCK + 1))
        if [[ "${CODE_BLOCK}" -eq 2 ]]; then
            # We hit the closing code block
            CODE_BLOCK=0
        fi
        continue
    fi

    # Treat normal line
    if [[ "${CODE_BLOCK}" == 0 ]]; then
        # If we see heading, we save it to ToC map
        if [[ "${LINE}" =~ ${HEADING_REGEX} ]]; then
            TOC+=("${LINE}")
        fi
    fi
done < <(grep -v '## Table of Contents' "${FILE}")

echo -e "## Table of Contents\n"
for LINE in "${TOC[@]}"; do
    case "${LINE}" in
        '#####'*)
          echo -n "        ${UL_SPECIFIER} "
          ;;
        '####'*)
          echo -n "      ${UL_SPECIFIER} "
          ;;
        '###'*)
          echo -n "    ${UL_SPECIFIER} "
          ;;
        '##'*)
          echo -n "  ${UL_SPECIFIER} "
          ;;
        '#'*)
          echo -n "${UL_SPECIFIER} "
          ;;
    esac

    LINK=${LINE}
    # Detect markdown links in heading and remove link part from them
    if grep -qE "\[.*\]\(.*\)" <<< "${LINK}"; then
        LINK=$(sed 's/\(\]\)\((.*)\)/\1/' <<< "${LINK}")
    fi
    # Special characters (besides '-') in page links in markdown
    # are deleted and spaces are converted to dashes
    LINK=$(tr -dc "[:alnum:] _-" <<< "${LINK}")
    LINK=${LINK/ /}
    LINK=${LINK// /-}
    LINK=${LINK,,}
    LINK=$(tr -s "-" <<< "${LINK}")

    # Print in format [Very Special Heading](#very-special-heading)
    echo "[${LINE#\#* }](#${LINK})"
done
