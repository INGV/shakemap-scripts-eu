#!/bin/bash
# ------------------------------------------------------------
# Author      : Valentino Lauciani
# Date        : 10/04/2026
# Description : Compare local earthquake event directories
#               against a remote SSH server and report
#               differences, iterating over all YYYYMM
#               subdirectories found under the local data dir.
# ------------------------------------------------------------
#

# Check for required commands
REQUIRED_COMMANDS=("ssh" "sort" "comm" "basename" "find" "mktemp")
for CMD in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "${CMD}" >/dev/null 2>&1; then
        echo "[ERROR] Required command '${CMD}' is not installed." >&2
        exit 1
    fi
done

# Detect OS type for cross-platform compatibility
OS_TYPE=$(uname)

# Functions
function date_start() {
    if [[ "${OS_TYPE}" == "Darwin" ]]; then
        DATE_START=$(date +%Y-%m-%d_%H:%M:%S)
    else
        DATE_START=$(date +%Y-%m-%d_%H:%M:%S)
    fi
    echo "-------------------- START - $(basename $0) - ${DATE_START} --------------------"
}
function date_end() {
    if [[ "${OS_TYPE}" == "Darwin" ]]; then
        DATE_END=$(date +%Y-%m-%d_%H:%M:%S)
    else
        DATE_END=$(date +%Y-%m-%d_%H:%M:%S)
    fi
    echo "-------------------- END - $(basename $0) - ${DATE_END} --------------------"
    echo ""
}
function echo_date() {
    if [[ "${OS_TYPE}" == "Darwin" ]]; then
        DATE_ECHO=$(date +%Y-%m-%d_%H:%M:%S)
    else
        DATE_ECHO=$(date +%Y-%m-%d_%H:%M:%S)
    fi
    echo "[${DATE_ECHO}] - ${1}"
}
function usage() {
    echo ""
    echo "Usage: $(basename "$0") -H HOST -p REMOTE_PATH -l LOCAL_DIR [-x SUFFIX] [-h]"
    echo ""
    echo "  -H, --host              Remote SSH host (e.g. shake@shakemapeu.int.ingv.it)  [required]"
    echo "  -p, --remote-path       Remote base directory path                            [required]"
    echo "  -l, --local-dir         Local data directory containing YYYYMM subdirs        [required]"
    echo "                          (e.g. ./data/)"
    echo "  -x, --exclude-dir-end   Suffix to exclude from remote dirs (repeatable)"
    echo "                          (e.g. -x _ri -x _test)"
    echo "  -h, --help              Show this help and exit"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") -H shake@host -p /remote/world/data -l ./data/ -x _ri"
    echo "  $(basename "$0") -H shake@host -p /remote/world/data -l ./data/ -x _ri -x _test"
    echo "  $(basename "$0") -H shake@shakemapeu.int.ingv.it -p /home/shake/gitwork/_shakemap/shakemap4/data/shakemap_profiles/world/data -l ./data -x _ri"
    echo ""
    date_end
    exit 0
}

# Initialize variables
REMOTE_HOST=""
REMOTE_PATH=""
LOCAL_DIR=""
EXCLUDE_SUFFIXES=()

date_start

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "${1}" in
        -H|--host)
            REMOTE_HOST="${2}"
            shift 2
            ;;
        -p|--remote-path)
            REMOTE_PATH="${2}"
            shift 2
            ;;
        -l|--local-dir)
            LOCAL_DIR="${2}"
            shift 2
            ;;
        -x|--exclude-dir-end)
            EXCLUDE_SUFFIXES+=("${2}")
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo_date "[ERROR] Unknown option: ${1}" >&2
            echo "" >&2
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "${REMOTE_HOST}" ]]; then
    echo_date "[ERROR] Missing required option: -H / --host" >&2
    date_end
    exit 1
fi
if [[ -z "${REMOTE_PATH}" ]]; then
    echo_date "[ERROR] Missing required option: -p / --remote-path" >&2
    date_end
    exit 1
fi
if [[ -z "${LOCAL_DIR}" ]]; then
    echo_date "[ERROR] Missing required option: -l / --local-dir" >&2
    date_end
    exit 1
fi

# Validate and resolve local directory
if [[ ! -d "${LOCAL_DIR}" ]]; then
    echo_date "[ERROR] Local directory '${LOCAL_DIR}' does not exist." >&2
    date_end
    exit 1
fi
LOCAL_DIR_ABS=$(cd "${LOCAL_DIR}" && pwd)

# Build excluded suffix display string
EXCLUDE_DISPLAY="${EXCLUDE_SUFFIXES[*]}"
[[ -z "${EXCLUDE_DISPLAY}" ]] && EXCLUDE_DISPLAY="(none)"

echo_date "[INFO] Local dir   : ${LOCAL_DIR_ABS}"
echo_date "[INFO] Remote host : ${REMOTE_HOST}"
echo_date "[INFO] Remote path : ${REMOTE_PATH}"
echo_date "[INFO] Excludes    : ${EXCLUDE_DISPLAY}"
echo ""

# Collect YYYYMM subdirectories from local dir
YYYYMM_DIRS=()
while IFS= read -r LINE; do
    [[ -z "${LINE}" ]] && continue
    YYYYMM_DIRS+=("$(basename "${LINE}")")
done < <(find "${LOCAL_DIR_ABS}" -maxdepth 1 -mindepth 1 -type d | sort)

if [[ ${#YYYYMM_DIRS[@]} -eq 0 ]]; then
    echo_date "[ERROR] No subdirectories found in '${LOCAL_DIR_ABS}'." >&2
    date_end
    exit 1
fi
echo_date "[INFO] YYYYMM months found: ${#YYYYMM_DIRS[@]}"

# Create working temp dir (cleaned up on exit)
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "${TMPDIR_WORK}"' EXIT

# Open persistent SSH ControlMaster connection (reused for all months)
SSH_CTL="${TMPDIR_WORK}/ssh_ctl"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o "ControlPath=${SSH_CTL}" -o ControlMaster=auto -o ControlPersist=60)
echo_date "[INFO] Opening SSH connection to ${REMOTE_HOST}..."
ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" true
SSH_EXIT=$?
if [[ ${SSH_EXIT} -ne 0 ]]; then
    echo_date "[ERROR] SSH connection to '${REMOTE_HOST}' failed (exit code: ${SSH_EXIT})." >&2
    date_end
    exit 1
fi
echo_date "[INFO] SSH connection established."
echo ""

# Grand total accumulators
GRAND_LOCAL=0
GRAND_REMOTE_ALL=0
GRAND_REMOTE_CLEAN=0
GRAND_EXCLUDED=0
GRAND_BOTH=0
GRAND_ONLY_LOCAL=0
GRAND_ONLY_REMOTE=0

# Per-month discrepancy details (accumulated for final detail section)
DISCREPANCY_DETAILS=""

# Flat global lists (all dirs across all months, unsegmented)
GRAND_ONLY_LOCAL_LIST=""
GRAND_ONLY_REMOTE_LIST=""

# ─── Per-month loop ───────────────────────────────────────────────────────────
for YYYYMM in "${YYYYMM_DIRS[@]}"; do
    MONTH_DIR="${LOCAL_DIR_ABS}/${YYYYMM}"

    # Collect local event dirs for this month
    LOCAL_DIRS=()
    while IFS= read -r LINE; do
        [[ -z "${LINE}" ]] && continue
        LOCAL_DIRS+=("$(basename "${LINE}")")
    done < <(find "${MONTH_DIR}" -maxdepth 1 -mindepth 1 -type d | sort)

    # Collect remote dirs for this month via SSH (reuses ControlMaster)
    REMOTE_RAW=$(ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" \
        "ls -d ${REMOTE_PATH}/${YYYYMM}*/ 2>/dev/null")

    REMOTE_ALL=()
    while IFS= read -r LINE; do
        [[ -z "${LINE}" ]] && continue
        DIR=$(basename "${LINE%/}")
        REMOTE_ALL+=("${DIR}")
    done <<< "${REMOTE_RAW}"

    # Filter excluded suffixes
    REMOTE_CLEAN=()
    REMOTE_EXCLUDED=()
    for DIR in "${REMOTE_ALL[@]}"; do
        EXCLUDE=0
        for SFX in "${EXCLUDE_SUFFIXES[@]}"; do
            if [[ "${DIR}" == *"${SFX}" ]]; then
                EXCLUDE=1
                break
            fi
        done
        if [[ ${EXCLUDE} -eq 1 ]]; then
            REMOTE_EXCLUDED+=("${DIR}")
        else
            REMOTE_CLEAN+=("${DIR}")
        fi
    done

    # Set-difference with comm
    printf '%s\n' "${LOCAL_DIRS[@]}"   | sort > "${TMPDIR_WORK}/local.txt"
    printf '%s\n' "${REMOTE_CLEAN[@]}" | sort > "${TMPDIR_WORK}/remote.txt"

    ONLY_LOCAL_COUNT=0
    ONLY_LOCAL_LIST=""
    while IFS= read -r LINE; do
        [[ -z "${LINE}" ]] && continue
        ONLY_LOCAL_COUNT=$((ONLY_LOCAL_COUNT + 1))
        ONLY_LOCAL_LIST="${ONLY_LOCAL_LIST}    ${LINE}\n"
    done < <(comm -23 "${TMPDIR_WORK}/local.txt" "${TMPDIR_WORK}/remote.txt")

    ONLY_REMOTE_COUNT=0
    ONLY_REMOTE_LIST=""
    while IFS= read -r LINE; do
        [[ -z "${LINE}" ]] && continue
        ONLY_REMOTE_COUNT=$((ONLY_REMOTE_COUNT + 1))
        ONLY_REMOTE_LIST="${ONLY_REMOTE_LIST}    ${LINE}\n"
    done < <(comm -13 "${TMPDIR_WORK}/local.txt" "${TMPDIR_WORK}/remote.txt")

    BOTH_COUNT=0
    while IFS= read -r LINE; do
        [[ -z "${LINE}" ]] && continue
        BOTH_COUNT=$((BOTH_COUNT + 1))
    done < <(comm -12 "${TMPDIR_WORK}/local.txt" "${TMPDIR_WORK}/remote.txt")

    COUNT_LOCAL=${#LOCAL_DIRS[@]}
    COUNT_REMOTE_ALL=${#REMOTE_ALL[@]}
    COUNT_REMOTE_CLEAN=${#REMOTE_CLEAN[@]}
    COUNT_EXCLUDED=${#REMOTE_EXCLUDED[@]}

    # Accumulate grand totals
    GRAND_LOCAL=$((GRAND_LOCAL + COUNT_LOCAL))
    GRAND_REMOTE_ALL=$((GRAND_REMOTE_ALL + COUNT_REMOTE_ALL))
    GRAND_REMOTE_CLEAN=$((GRAND_REMOTE_CLEAN + COUNT_REMOTE_CLEAN))
    GRAND_EXCLUDED=$((GRAND_EXCLUDED + COUNT_EXCLUDED))
    GRAND_BOTH=$((GRAND_BOTH + BOTH_COUNT))
    GRAND_ONLY_LOCAL=$((GRAND_ONLY_LOCAL + ONLY_LOCAL_COUNT))
    GRAND_ONLY_REMOTE=$((GRAND_ONLY_REMOTE + ONLY_REMOTE_COUNT))

    # Status marker for this month
    if [[ ${ONLY_LOCAL_COUNT} -eq 0 && ${ONLY_REMOTE_COUNT} -eq 0 ]]; then
        MONTH_STATUS="[OK]"
    else
        MONTH_STATUS="[!!]"
    fi

    # Print one-line summary per month
    printf "  %-8s %s  Local:%-4s  Remote:%-4s (clean:%-4s excl:%-3s)  Both:%-4s  LOCAL-only:%-3s  Remote-only:%-3s\n" \
        "[${YYYYMM}]" "${MONTH_STATUS}" \
        "${COUNT_LOCAL}" "${COUNT_REMOTE_ALL}" "${COUNT_REMOTE_CLEAN}" "${COUNT_EXCLUDED}" \
        "${BOTH_COUNT}" "${ONLY_LOCAL_COUNT}" "${ONLY_REMOTE_COUNT}"

    # Accumulate discrepancy details for the final section
    if [[ ${ONLY_LOCAL_COUNT} -gt 0 ]]; then
        DISCREPANCY_DETAILS="${DISCREPANCY_DETAILS}  [${YYYYMM}] Only in LOCAL (missing on remote):\n${ONLY_LOCAL_LIST}\n"
        GRAND_ONLY_LOCAL_LIST="${GRAND_ONLY_LOCAL_LIST}${ONLY_LOCAL_LIST}"
    fi
    if [[ ${ONLY_REMOTE_COUNT} -gt 0 ]]; then
        DISCREPANCY_DETAILS="${DISCREPANCY_DETAILS}  [${YYYYMM}] Only on REMOTE (missing locally):\n${ONLY_REMOTE_LIST}\n"
        GRAND_ONLY_REMOTE_LIST="${GRAND_ONLY_REMOTE_LIST}${ONLY_REMOTE_LIST}"
    fi
done
# ─────────────────────────────────────────────────────────────────────────────

# Close SSH ControlMaster
ssh -o "ControlPath=${SSH_CTL}" -O exit "${REMOTE_HOST}" 2>/dev/null

# Build grand total remote line
if [[ ${GRAND_EXCLUDED} -gt 0 ]]; then
    GRAND_REMOTE_LINE="${GRAND_REMOTE_ALL}  (${GRAND_REMOTE_CLEAN} clean, ${GRAND_EXCLUDED} excluded \"${EXCLUDE_DISPLAY}\")"
else
    GRAND_REMOTE_LINE="${GRAND_REMOTE_ALL}"
fi

# Status markers for grand total
if [[ ${GRAND_ONLY_LOCAL} -eq 0 ]]; then MARK_LOCAL="[OK]"; else MARK_LOCAL="[!!]"; fi
if [[ ${GRAND_ONLY_REMOTE} -eq 0 ]]; then MARK_REMOTE="[OK]"; else MARK_REMOTE="[!!]"; fi

# Print final report
echo ""
echo "================================================================================"
echo "REPORT: Compare local vs remote"
echo "================================================================================"
printf "%-16s : %s\n" "Local dir"    "${LOCAL_DIR_ABS}"
printf "%-16s : %s\n" "Remote host"  "${REMOTE_HOST}"
printf "%-16s : %s\n" "Remote path"  "${REMOTE_PATH}"
printf "%-16s : %s\n" "Excluded sfx" "${EXCLUDE_DISPLAY}"
echo "--------------------------------------------------------------------------------"
printf "%-16s : %s\n" "Months checked" "${#YYYYMM_DIRS[@]}"
echo "--------------------------------------------------------------------------------"
printf "%-16s : %s\n" "Local  total"   "${GRAND_LOCAL}"
printf "%-16s : %s\n" "Remote total"   "${GRAND_REMOTE_LINE}"
echo "--------------------------------------------------------------------------------"
printf "%-4s %-40s : %s\n" "[OK]"          "Directories in BOTH"          "${GRAND_BOTH}"
printf "%-4s %-40s : %s\n" "${MARK_LOCAL}"  "Only in LOCAL  (not remote)"  "${GRAND_ONLY_LOCAL}"
printf "%-4s %-40s : %s\n" "${MARK_REMOTE}" "Only on REMOTE (not local)"   "${GRAND_ONLY_REMOTE}"
printf "%-4s %-40s : %s\n" "[~~]"          "Excluded on remote"            "${GRAND_EXCLUDED}"
echo "================================================================================"

# Print discrepancy details if any (per-month breakdown)
if [[ -n "${DISCREPANCY_DETAILS}" ]]; then
    echo ""
    echo "Details — Discrepancies (by month):"
    printf "${DISCREPANCY_DETAILS}"
fi

# Print flat global lists (comma-separated, single line)
if [[ -n "${GRAND_ONLY_LOCAL_LIST}" ]]; then
    GRAND_ONLY_LOCAL_CSV=$(printf "${GRAND_ONLY_LOCAL_LIST}" | tr -s ' \n' ',' | sed 's/^,//;s/,$//')
    echo ""
    echo "================================================================================"
    echo "Complete list — Only in LOCAL (missing on remote): ${GRAND_ONLY_LOCAL} dirs"
    echo "================================================================================"
    echo "${GRAND_ONLY_LOCAL_CSV}"
fi

if [[ -n "${GRAND_ONLY_REMOTE_LIST}" ]]; then
    GRAND_ONLY_REMOTE_CSV=$(printf "${GRAND_ONLY_REMOTE_LIST}" | tr -s ' \n' ',' | sed 's/^,//;s/,$//')
    echo ""
    echo "================================================================================"
    echo "Complete list — Only on REMOTE (missing locally): ${GRAND_ONLY_REMOTE} dirs"
    echo "================================================================================"
    echo "${GRAND_ONLY_REMOTE_CSV}"
fi

echo ""
date_end
exit 0
