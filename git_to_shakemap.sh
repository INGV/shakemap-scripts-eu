#!/bin/bash
# ------------------------------------------------------------
# Author      : Valentino Lauciani 
# Date        : 06/06/2022
# ------------------------------------------------------------
#

# Import configurations
. $(dirname $0)/config.sh

### START - Functions ###
function syntax () {
    echo ""
    echo "Syntax:"
    echo "`basename $0` [ -e <fk_event> | -r ] | -h | --help"
    echo "-e by fk_event" 
    echo "-r real-time mode"
    echo "-p profile [world|italy]"
    echo ""
    echo "Example with -e option: $( basename ${0} ) -e 5269671 -p world"
    echo "Example with -r option: $( basename ${0} ) -r -p world"
    echo ""        
	exit 1
}
### END - Functions ###

### START - Check parameters ###
# Check input params
IN__EVENTID=
IN__PROFILE=
IN__REALTIME=0
while getopts :e:p:rh OPTION
do
	case ${OPTION} in
		e)  	
			IN__EVENTID="${OPTARG}"
			;;
		h)
			syntax
			;;
		p)  
			IN__PROFILE="${OPTARG}"
			[[ ${IN__PROFILE} == "world"  || ${IN__PROFILE} == "italy" ]] || syntax
                	;;
		r)  
			IN__REALTIME=1
                	;;
		\?)
			echo "Unknown option: -$OPTARG" >&2
			exit 1
			;;
		:) 
			echo "Missing option argument for -$OPTARG" >&2 
		        exit 1
			;;
		*)  
			echo "Unimplemented option: -$OPTARG" >&2
			exit 1
                	;;
        esac
done

if ((OPTIND == 1)); then
	echo "No options specified"
fi

shift $(($OPTIND - 1))

if [ -z ${IN__PROFILE} ]; then
	echo ""
	echo "Profile, is mandatory!"
	syntax
fi

#
if (( ${IN__REALTIME} == 1 )) && [ ! -z ${IN__EVENTID} ]; then
	echo "Cannot use -e and -r at same time"
	exit 1
fi

#
DIRSHAKEMAP4_PROFILE=${DIRSHAKEMAP4_PROFILES}/${IN__PROFILE}
if [ ! -d ${DIRSHAKEMAP4_PROFILE} ]; then
        echo "The DIRSHAKEMAP4_PROFILE directory (${DIRSHAKEMAP4_PROFILE}) doesn't exist"
        exit 1
fi
### END - Check parameters ###

date_start

### START - Check if the script already running ###
# make directory if not exists
if [ ! -d ${DIRLOCK} ]; then
    mkdir ${DIRLOCK}
fi
if [ ! -d ${DIRTMP} ]; then
    mkdir ${DIRTMP}
fi
if [ ! -d ${DIRLOG} ]; then
    mkdir ${DIRLOG}
fi

LCK_FILE=${DIRLOCK}/$( basename $0 ).lck

if [ -f "${LCK_FILE}" ]; then

	# The file exists so read the PID
	# to see if it is still running
	MYPID=`head -n 1 "${LCK_FILE}"`

	TEST_RUNNING=`ps -p ${MYPID} | grep ${MYPID}`

	if [ -z "${TEST_RUNNING}" ]; then
		# The process is not running
		# Echo current PID into lock file
		echo $$ > "${LCK_FILE}"
	else
		echo ""
		echo " The ${0} already running... [pid: ${MYPID}]"
		echo ""
		date_end
		exit 0
  	fi

else
	echo $$ > "${LCK_FILE}"
fi
### END - Check if the script already running ###

#
DIRSHAKEMAP4_PROFILE_DATA=${DIRSHAKEMAP4_PROFILE}/data
if [ ! -d ${DIRSHAKEMAP4_PROFILE_DATA} ]; then
	mkdir ${DIRSHAKEMAP4_PROFILE_DATA}
fi

#########################################################################
if (( ${IN__REALTIME} == 1 )); then
    echo_date "Run \"make_pull_from_gitlab.sh\" to get changes:"
    if [ -f ${DIRTMP}/make_pull_from_gitlab.sh.log ]; then
	    rm ${DIRTMP}/make_pull_from_gitlab.sh.log
    fi
    echo ""

    echo "${DIRWORK}/make_pull_from_gitlab.sh -g ${DIRGITSHAKEMAP_FOR_PULL} -d ${DIRSHAKEMAP4_PROFILE_DATA}"
    ${DIRWORK}/make_pull_from_gitlab.sh -g ${DIRGITSHAKEMAP_FOR_PULL} -d ${DIRSHAKEMAP4_PROFILE_DATA} 2>&1 | tee -a ${DIRTMP}/make_pull_from_gitlab.sh.log
    echo_date "Done"
    echo ""

    echo_date "Get eventid(s) changed:"
    EVENTIDS=$( grep "EVENTIDS=" ${DIRTMP}/make_pull_from_gitlab.sh.log | awk -F"=" '{print $2}' )
    echo "EVENTIDS=${EVENTIDS}"
    rm ${DIRTMP}/make_pull_from_gitlab.sh.log
    echo_date "Done"
    echo ""
elif (( ${IN__REALTIME} == 0 )); then
    echo "Check dir:"
    EVENTIDS=${IN__EVENTID}
    if [ -d ${DIRSHAKEMAP4_PROFILE_DATA}/${IN__EVENTID} ]; then
	    echo " the dir \"${DIRSHAKEMAP4_PROFILE_DATA}/${IN__EVENTID}\" already exists."
    else
	    echo " the dir \"${DIRSHAKEMAP4_PROFILE_DATA}/${IN__EVENTID}\" doesn't exist; create..."
	    mkdir -p ${DIRSHAKEMAP4_PROFILE_DATA}/${IN__EVENTID}
    fi
    echo "Copy files:"
    if [ -d ${DIRGITSHAKEMAP_FOR_PULL}/data/${IN__EVENTID:0:6}/${IN__EVENTID}/current ]; then
        cp -v ${DIRGITSHAKEMAP_FOR_PULL}/data/${IN__EVENTID:0:6}/${IN__EVENTID}/current/* ${DIRSHAKEMAP4_PROFILE_DATA}/${IN__EVENTID}/current/
    else
        echo " the input directory \"${DIRGITSHAKEMAP_FOR_PULL}/data/${IN__EVENTID:0:6}/${IN__EVENTID}/\" doesn't exist"
	exit 0
    fi
    echo "Done"
    echo ""
fi
#EVENTIDS="20220503_0000135 20220404_0000034" # To test

# Check EVENTIDS
if [ -z "${EVENTIDS}" ]; then
	echo "No event(s) to elaborate"
	remove_lock_file
	echo ""
	date_end
	exit 0
fi

#
echo_date "Start processing EVENTID(s):"
for EVENTID in ${EVENTIDS}; do
    echo_date "********** START - Elaborating IN__EVENTID: ${EVENTID} **********"
    FILE_EVENTXML=${DIRSHAKEMAP4_PROFILE_DATA}/${EVENTID}/current/event.xml
    if [[ -f ${FILE_EVENTXML} ]]; then
        echo "FILE_EVENTXML=${FILE_EVENTXML}"

        CATALOG=$( cat ${FILE_EVENTXML} | tr -s ' ' '\n' | grep "catalog=" | awk -F"=" '{print $2}' | sed 's/\"//g' )
        DEPTH=$( cat ${FILE_EVENTXML} | tr -s ' ' '\n' | grep "depth=" | awk -F"=" '{print $2}' | sed 's/\"//g' )
        LAT=$( cat ${FILE_EVENTXML} | tr -s ' ' '\n' | grep "lat=" | awk -F"=" '{print $2}' | sed 's/\"//g' )
        LON=$( cat ${FILE_EVENTXML} | tr -s ' ' '\n' | grep "lon=" | awk -F"=" '{print $2}' | sed 's/\"//g' )
        MAG=$( cat ${FILE_EVENTXML} | tr -s ' ' '\n' | grep "mag=" | awk -F"=" '{print $2}' | sed 's/\"//g' )
        TIME=$( cat ${FILE_EVENTXML} | tr -s ' ' '\n' | grep "time=" | awk -F"=" '{print $2}' | sed 's/\"//g' )
        NETID=$( cat ${FILE_EVENTXML} | tr -s ' ' '\n' | grep "netid=" | awk -F"=" '{print $2}' | sed 's/\"//g' )
        NETWORK=$( cat ${FILE_EVENTXML} | tr -s ' ' '\n' | grep "network=" | awk -F"=" '{print $2}' | sed 's/\"//g' )

        echo " CATALOG=${CATALOG}"
        echo " DEPTH=${DEPTH}"
        echo " LAT=${LAT}"
        echo " LON=${LON}"
        echo " MAG=${MAG}"
        echo " TIME=${TIME}"
        echo " NETID=${NETID}"
        echo " NETWORK=${NETWORK}"
        echo ""

        # Set Mail variables
        MAIL_GITHUB_EVENT_URL="https://github.com/INGV/shakemap-input-eu/blob/main/data/${EVENTID:0:6}/${EVENTID}/current"
        MAIL_GITHUB_CONF_URL="https://github.com/INGV/shakemap-conf-eu/tree/main/config"

        # Get country code
        echo_date "Get Country code:"
        CURL_RETRY_COUNT=1
        CURL_RETRY_COUNT_MAX=5
        HTTP_RESPONSE=-99
        URL="http://api.geonames.org/countryCode?lat=${LAT}&lng=${LON}&radius=100&username=spada"
        echo " URL=${URL}"
        while (( ${CURL_RETRY_COUNT} <= ${CURL_RETRY_COUNT_MAX} )) && [[ "${HTTP_RESPONSE}" != "200" ]]; do
            HTTP_RESPONSE=$(curl -s -o ${DIRTMP}/${EVENTID}__response.txt -w "%{http_code}" ${URL})
            echo "  HTTP_RESPONSE=${HTTP_RESPONSE}"
            if [[ "${HTTP_RESPONSE}" != "200" ]]; then
                sleep 2
            fi
            CURL_RETRY_COUNT=$(( ${CURL_RETRY_COUNT} + 1 ))
        done
        if (( ${CURL_RETRY_COUNT} > ${CURL_RETRY_COUNT_MAX} )) || [[ "${HTTP_RESPONSE}" != "200" ]]; then
            rm ${DIRTMP}/${EVENTID}__response.txt
            error_msg "!!! Error retreaving \"${URL}\"; HTTP_RESPONSE=${HTTP_RESPONSE}"
        else
            COUNTRY_CODE=$(cat ${DIRTMP}/${EVENTID}__response.txt | head -1 | tr -dc '[:print:]')
            rm ${DIRTMP}/${EVENTID}__response.txt
        fi
        echo " COUNTRY_CODE=${COUNTRY_CODE}"
        echo_date "Done"
        echo ""

        # START - Set ShakeMap conf. by Country code
        echo_date "Set ShakeMap conf. by Country code:"
        SHAKEMAP_FILES_CONF="gmpe_sets.conf model.conf modules.conf products.conf select.conf"
        DIRSHAKEMAP4_PROFILE_CONF="${DIRSHAKEMAP4_PROFILE}/install/config"

        echo " git pull last conf(s) into \"${DIRSHAKEMAP_CONFIGURATIONS}\":"
        cd ${DIRSHAKEMAP_CONFIGURATIONS}
        git pull
        cd -
        echo " done"
        echo ""

        echo " git status into \"${DIRSHAKEMAP4_PROFILE_CONF}\":"
        cd ${DIRSHAKEMAP4_PROFILE_CONF}
        git status . | grep "modified"
        echo " done"
        echo ""

        echo " git checkout conf. files"
        for SHAKEMAP_FILE_CONF in ${SHAKEMAP_FILES_CONF}; do
                git checkout ${SHAKEMAP_FILE_CONF}
        done
        echo " done"
        echo ""

        echo " copy conf files"
        #if [[ "${COUNTRY_CODE}" == "CH" ]]; then
        #    DIR_INSTITUTE="eth"
        #elif [[ "${COUNTRY_CODE}" == "GR" ]]; then 
        #    DIR_INSTITUTE="greece"
        #else
        #    DIR_INSTITUTE="ingv"
        #fi
        if [[ "${COUNTRY_CODE}" == "CH" ]]; then
            DIR_INSTITUTE="switzerland"
        elif [[ "${COUNTRY_CODE}" == "GR" ]]; then 
            DIR_INSTITUTE="greece"
        elif [[ "${COUNTRY_CODE}" == "AL" ]]; then 
            DIR_INSTITUTE="albania"
        elif [[ "${COUNTRY_CODE}" == "HR" ]]; then 
            DIR_INSTITUTE="croatia"
        elif [[ "${COUNTRY_CODE}" == "SI" ]]; then 
            DIR_INSTITUTE="slovenia"
        elif [[ "${COUNTRY_CODE}" == "RO" ]]; then 
            DIR_INSTITUTE="romania"
        elif [[ "${COUNTRY_CODE}" == "FR" ]]; then 
            DIR_INSTITUTE="france"
        elif [[ "${COUNTRY_CODE}" == "BE" ]]; then 
            DIR_INSTITUTE="belgium"
        else
            DIR_INSTITUTE="italy"
        fi

        MAIL_GITHUB_CONF=
        for SHAKEMAP_FILE_CONF in ${SHAKEMAP_FILES_CONF}; do
                if [[ -f ${DIRSHAKEMAP_CONFIGURATIONS}/${DIR_INSTITUTE}/${SHAKEMAP_FILE_CONF} ]]; then
                    cp -v ${DIRSHAKEMAP_CONFIGURATIONS}/${DIR_INSTITUTE}/${SHAKEMAP_FILE_CONF} ${DIRSHAKEMAP4_PROFILE_CONF}/
            MAIL_GITHUB_CONF="${MAIL_GITHUB_CONF} - ${MAIL_GITHUB_CONF_URL}/${DIR_INSTITUTE}/${SHAKEMAP_FILE_CONF} \n"
                else
                    echo " The file \"${DIRSHAKEMAP_CONFIGURATIONS}/${DIR_INSTITUTE}/${SHAKEMAP_FILE_CONF}\" doesn't exist."
                fi
            done
        echo " done"
        echo ""

        cd -
        echo_date "Done"
        echo ""
        # END - Set ShakeMap conf. by Country code

        # run ShakeMap
        echo -e " \
        Start ShakeMap for: \
        \n\n \
        EVENTID: ${EVENTID} \
        \n \
        TIME: ${TIME} \
        \n \
        MAG: ${MAG} \
        \n \
        COUNTRY_CODE: ${COUNTRY_CODE} \
        \n\n \
        INPUT PARAMS FROM: \
        \n \
        - ${MAIL_GITHUB_EVENT_URL} \
        \n\n \
        INPUT CONF FROM: \
        \n \
        ${MAIL_GITHUB_CONF} \
        \n\n \
        DOCKER IMAGE: ${DOCKER_SHAKEMAP4_IMAGE} \
        \n \
        SCRIPT: ${DIRWORK}/$( basename ${0} ) \
        \n \
        HOST: $( hostname -f ) \
        \n\n \
        " | mutt -e 'my_hdr From: ShakeMapEU <shakemap@ingv.it>' -s "$(hostname) - Start ShakeMap for ${EVENTID}" ${MAIL_TO} 
        #cd ${DIRSHAKEMAP4} 

        # Set 'select' module only for event M<7. Issue: https://gitlab.rm.ingv.it/shakemap/shakemap4/-/issues/15
        MODULE_SELECT=""
        if (( $(echo "${MAG} < 7" | bc -l) )); then
            MODULE_SELECT="select"
        fi

        # Run docker
        COMMAND="time docker run --rm --name shakemap4__${EVENTID} -v ${DIRSHAKEMAP4_PROFILES}:/home/shake/shakemap_profiles -v ${DIRSHAKEMAP4_DATA}:/home/shake/shakemap_data -v ${DIRSHAKEMAP4_LOCAL}:/home/shake/.local ${DOCKER_SHAKEMAP4_IMAGE} -p ${IN__PROFILE} -c\"shake ${EVENTID} ${MODULE_SELECT} assemble -c \\\"SM4 run\\\" model contour shape info stations raster rupture gridxml history plotregr mapping\" 2>&1 | tee -a ${DIRTMP}/shakemap4__${EVENTID}.txt "
        echo "COMMAND=${COMMAND}"
        eval ${COMMAND}
        #exit
        #time docker run --rm --name shakemap4__${EVENTID} -v ${DIRSHAKEMAP4_PROFILES}:/home/shake/shakemap_profiles -v ${DIRSHAKEMAP4_DATA}:/home/shake/shakemap_data -v ${DIRSHAKEMAP4_LOCAL}:/home/shake/.local ${DOCKER_SHAKEMAP4_IMAGE} -p ${IN__PROFILE} -c"shake ${EVENTID} ${MODULE_SELECT} assemble -c \"SM4 run\" model contour shape info stations raster rupture gridxml history plotregr mapping" 2>&1 | tee -a ${DIRTMP}/shakemap4__${EVENTID}.txt 

        #cd -
        echo ""

        # email for ending shakemap process
        echo_date "Email for ending shakemap process:"
        MAIL_JPGS=
        for FILE_JPG in $( ls ${DIRSHAKEMAP4_PROFILE_DATA}/${EVENTID}/current/products/*.jpg ); do
            if [ -f ${FILE_JPG} ]; then
                MAIL_JPGS="${MAIL_JPGS} -a ${FILE_JPG}"
            else
                echo " the file \"${FILE_JPG}\" doesn't exist."
            fi
        done
        echo -e " \
            End ShakeMap for: \
            \n\n \
            EVENTID: ${EVENTID} \
            \n \
            TIME: ${TIME} \
            \n \
            MAG: ${MAG} \
	    \n \
            COUNTRY_CODE: ${COUNTRY_CODE} \
            \n\n \
            INPUT PARAMS FROM: \
	    \n \
            - ${MAIL_GITHUB_EVENT_URL} \
            \n\n \
            INPUT CONF FROM: \
	    \n \
            ${MAIL_GITHUB_CONF} \
	    \n\n \
            DOCKER IMAGE: ${DOCKER_SHAKEMAP4_IMAGE} \
            \n \
            SCRIPT: ${DIRWORK}/$( basename ${0} ) \
            \n \
            HOST: $( hostname -f ) \
            \n\n \
        " | mutt -e 'my_hdr From: ShakeMapEU <shakemap@ingv.it>' -s "$(hostname) - End ShakeMap for ${EVENTID}" ${MAIL_TO} -a ${DIRTMP}/shakemap4__${EVENTID}.txt ${MAIL_JPGS}
        rm ${DIRTMP}/shakemap4__${EVENTID}.txt
        echo_date "Done"
        echo ""

        #echo_date "START - Rsync on the external web site webpage and all events."
        #echo "Sync base web page:"
        #COMMAND1="time flock --verbose -n /tmp/rsync_1.lock rsync --timeout=15 -av --delete --exclude=.git --exclude=Docker --exclude=data ${DIRSHAKEMAP4_WEB}/ valentino.lauciani@shakemap4.webfarm.rm.ingv.it:/var/www/shakemap/shake4"
        #echo "COMMAND1=${COMMAND1}"
        #eval ${COMMAND1}
        #echo ""

        #echo "Sync all events:"
        #COMMAND3="time flock --verbose -n /tmp/rsync_3.lock rsync -av --delete --timeout=15 --exclude=.git ${DIRSHAKEMAP4_PROFILES}/world/data/ valentino.lauciani@shakemap4.webfarm.rm.ingv.it:/var/www/shakemap/shake4/data/ &"
        #echo "COMMAND3=${COMMAND3}"
        #eval ${COMMAND3}
        #echo ""
        #echo_date "END - Rsync on the external web site webpage and all events."
        #echo ""
        
    else
        echo ""
        error_msg "!!! Doesn't exist file \"${FILE_EVENTXML}\" !!!"
    fi

    echo_date "********** END - Elaborating IN__EVENTID: ${EVENTID} **********"
done
echo_date "Done"
echo ""

# remove event(s) file
if [ -f ${FILE_EVENTS_TO_ELABORATE} ]; then
    rm -f "${FILE_EVENTS_TO_ELABORATE}"
fi
if [ -f ${FILE_EVENTS_TO_ELABORATE}_tmp ]; then
    rm -f "${FILE_EVENTS_TO_ELABORATE}_tmp"
fi
remove_lock_file

DATE_END=`date +%Y-%m-%d_%H:%M:%S`
date_end
echo ""
###################################
