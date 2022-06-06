#!/bin/bash
# ------------------------------------------------------------
# Author      : Valentino Lauciani 
# Date        : 06/06/2022
# ------------------------------------------------------------
#

# Check software(s)
for PROGRAM in mkdir git mail docker tr date ; do
    command -v ${PROGRAM} >/dev/null 2>&1 || { echo >&2 " \"${PROGRAM}\" program doesn't exist.  Aborting."; exit 1; }
done

### START - Config ###
DIRHOME=${HOME}
DIRWORK=$( cd $(dirname $0) ; pwd)
DIRTMP=${DIRWORK}/tmp
DIRLOG=${DIRWORK}/log
DIRLOCK=${DIRWORK}/lock
DIRSHAKEMAP4=/Users/valentino/gitwork/gitlab/_shakemap/shakemap4
DIRSHAKEMAP4_WEB=/Users/valentino/tmp/shakemap4-web
FILE_EVENTS_TO_ELABORATE=${DIRTMP}/$(basename $0)__FILE_EVENTS_TO_ELABORATE__$(date +%Y%m%dT%H%M%S)
#DIRGITSHAKEMAP_FOR_PULL="/home/shake/gitwork/_shakemap/shakemap-input-it__to_pull" # !!! This must be the absolute path !!!
DIRGITSHAKEMAP_FOR_PULL="/Users/valentino/gitwork/github/_INGV/shakemap-input-eu" # !!! This must be the absolute path !!!
SLACK_CHANNEL="#valentino_debug"
SLACK_HOOK_URL="https://hooks.slack.com/services/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"
#MAIL_TO="valentino.lauciani@ingv.it,alberto.michelini@ingv.it,dario.jozinovic@ingv.it,licia.faenza@ingv.it,ilaria.oliveti@ingv.it,emanuele.casarotti@ingv.it"
MAIL_TO="valentino.lauciani@ingv.it"
### END - Config ###

### END - Functions ###
function date_start () {
    DATE_START=`date +%Y-%m-%d_%H:%M:%S`
    echo -------------------- START - $(basename $0) - ${DATE_START} --------------------
}

function date_end () {
    DATE_END=`date +%Y-%m-%d_%H:%M:%S`
    echo -------------------- END - $(basename $0) - ${DATE_END} --------------------
    echo ""
}

function error_msg () {
    MSG="${HOSTNAME}: ${1} ${2}"
    echo_date "${MSG}"
    if [ -f "${2}" ]; then
        cat ${2}
    fi
    echo "${MSG}" | mail -s "${HOSTNAME} - $(basename $0)" valentino.lauciani@ingv.it
    remove_lock_file
    date_end
    exit 1
}

function echo_date() {
    DATE_ECHO=`date +"%Y-%m-%d %H:%M:%S %Z"`
    echo "[${DATE_ECHO}] - ${1}"
}

function remove_lock_file () {
    # remove lock file
    if [ -f ${LCK_FILE} ]; then
        rm -f "${LCK_FILE}"
    fi
}

function checkReturnCode() {
	DATE_TIMESTAMP_NOW=$(date +%s)
    RET=${1}
    if [ -z ${RET} ] || (( ${RET} != 0 )); then
    TEXT="Last command return: ${RET}."
    if [ ! -z ${2} ] && [ -f ${2} ]; then
        VARIABLE_LOAD_RECORDS=$( cat ${2} )
        VARIABLE_LOAD_RECORDS_ESCAPED=$(echo -e "${VARIABLE_LOAD_RECORDS}" | sed 's/\"/\\"/g' | sed "s/'/\'/g" | sed 's/`/\`/g')
        TEXT="${TEXT} The outpt log is: \`\`\` ${VARIABLE_LOAD_RECORDS_ESCAPED} \`\`\`"
    else
        TEXT="${TEXT} Check the logs from crontab."
    fi
        echo ""
        echo "Last command return: ${RET}"

    if [ -f /tmp/$(basename $0).touch ]; then
        DATE_TIMESTAMP_TOUCH=$( cat /tmp/$(basename $0).touch ) 
    else
        DATE_TIMESTAMP_TOUCH=0
    fi

    if (( $(( ${DATE_TIMESTAMP_NOW} - ${DATE_TIMESTAMP_TOUCH} )) > 3600 )); then # 3600sec
curl -X POST -H 'Content-type: application/json' --data "$(cat <<EOF
{ 
"channel":"${SLACK_CHANNEL}",
"username": "$(whoami)@$(hostname -f)",
"icon_emoji": ":bangbang:",
    "blocks": [
            {
                    "type": "section",
                    "text": {
                            "type": "mrkdwn",
                            "text": "${TEXT}"
                    }
            }
    ]
}
EOF
)" ${SLACK_HOOK_URL}
echo ""
        date +%s > /tmp/$(basename $0).touch
    else
        echo "Slack message already sent."
        echo ""
    fi
        date_end
        exit 1
    fi
}
### END - Functions ###

### START - Check parameters ###
#
if [ ! -d ${DIRSHAKEMAP4} ]; then
    echo "The \"SHAKEMAP4\" directory (${DIRSHAKEMAP4}) doesn't exist"
    exit 1
fi

#
DIRSHAKEMAP4_PROFILES=${DIRSHAKEMAP4}/data/shakemap_profiles
if [ ! -d ${DIRSHAKEMAP4_PROFILES} ]; then
        echo "The \"DIRSHAKEMAP4_PROFILES\" directory (${DIRSHAKEMAP4_PROFILES}) doesn't exist"
        exit 1
fi

#
DIRSHAKEMAP4_DATA=${DIRSHAKEMAP4}/data/shakemap_data
if [ ! -d ${DIRSHAKEMAP4_DATA} ]; then
        echo "The \"DIRSHAKEMAP4_DATA\" directory (${DIRSHAKEMAP4_DATA}) doesn't exist"
        exit 1
fi

#
DIRSHAKEMAP4_LOCAL=${DIRSHAKEMAP4}/data/local
if [ ! -d ${DIRSHAKEMAP4_LOCAL} ]; then
        echo "The \"DIRSHAKEMAP4_LOCAL\" directory (${DIRSHAKEMAP4_LOCAL}) doesn't exist"
        exit 1
fi

#
if [ ! -d ${DIRGITSHAKEMAP_FOR_PULL} ]; then
        echo " the directory \"${DIRGITSHAKEMAP_FOR_PULL}\" doesn't exist; please, set variable into \"$(basename $0)\" file and try again."
        echo ""
        exit 1
fi
### END - Check parameters ###