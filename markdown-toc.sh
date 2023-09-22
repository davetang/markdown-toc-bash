#!/usr/bin/env bash
#
# Forked from https://github.com/Lirt/markdown-toc-bash/
#
set -euo pipefail

VERSION=0.1.0
PROGRAM=$0
DESCRIPTION="Generate a Table of Contents from Markdown"
UL_SPECIFIER='-'
INSERT=0
BACKUP=1

usage(){
>&2 cat << EOF

Program: ${PROGRAM} (${DESCRIPTION})
Version: ${VERSION}

Usage:   $0 [options] <infile.md>

Options:

     -s | specifier      symbol ("-", "*", or "+") to use for ToC (default: "-")
     -i | insert         directly insert ToC into input (overwrites original)
     -n | no-backup      no backup file when using the insert option (default: false)
     -h | help           display this help message
     -v | version        display version

EOF
exit 1
}

print_ver(){
   >&2 echo ${VERSION}
   exit 0
}

args=$(getopt -a -o inhvs: --long no-backup,insert,help,version,specifier: -- "$@")
if [[ $? -gt 0 ]]; then
  usage
fi

eval set -- ${args}
while :
do
  case $1 in
    -h | --help)      usage            ; shift    ;;
    -v | --version)   print_ver        ; shift    ;;
    -i | --insert)    INSERT=1         ; shift    ;;
    -n | --no-backup) BACKUP=0         ; shift    ;;
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
TOC_FILE=${FILE}.this.contains.the.toc
TMP_FILE=${FILE}.this.is.a.temporary.file

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

echo -e "## Table of Contents\n" > ${TOC_FILE}
for LINE in "${TOC[@]}"; do
    case "${LINE}" in
        '#####'*)
          echo -n "        ${UL_SPECIFIER} " >> ${TOC_FILE}
          ;;
        '####'*)
          echo -n "      ${UL_SPECIFIER} " >> ${TOC_FILE}
          ;;
        '###'*)
          echo -n "    ${UL_SPECIFIER} " >> ${TOC_FILE}
          ;;
        '##'*)
          echo -n "  ${UL_SPECIFIER} " >> ${TOC_FILE}
          ;;
        '#'*)
          echo -n "${UL_SPECIFIER} " >> ${TOC_FILE}
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
    echo "[${LINE#\#* }](#${LINK})" >> ${TOC_FILE}
done
echo -e "\n<!-- END TOC -->" >> ${TOC_FILE}

skip_toc () {
   local FILE=$1
   SKIP=0
   NR=0
   while read -r LINE; do
      NR=$((NR + 1))
      # Assuming that the ToC starts on the first line
      if [[ ${LINE} =~ "Table of Contents" && ${NR} == 1 ]]; then
         SKIP=1
         continue
      fi
      if [[ ${LINE} =~ "END TOC" ]]; then
         SKIP=0
         continue
      fi

      if [[ ${SKIP} == 0 ]]; then
         echo ${LINE}
      fi
   done < ${FILE}
}

if [[ ${INSERT} == 0 ]]; then
   cat ${TOC_FILE}
else
   if [[ ${BACKUP} == 1 ]]; then
      cp ${FILE} ${FILE}.bk
   fi
   cat ${TOC_FILE} <(skip_toc ${FILE}) > ${TMP_FILE}
   mv -f ${TMP_FILE} ${FILE}
fi
rm ${TOC_FILE}
