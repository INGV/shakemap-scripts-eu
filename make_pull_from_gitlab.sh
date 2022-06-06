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
    echo "`basename $0` -g <git_shakemap-input> -d <base_directory> | -h | --help"
    echo "-d shakemap data directory"
    echo "-g git shakemap-input-it__to_pull"
    echo ""
    echo "Example: $( basename ${0} ) -g /home/shake/gitwork/_shakemap/shakemap-input-it__to_pull -d /home/shake/gitwork/_shakemap/shakemap4/data/shakemap_profiles/world/data "
    echo ""
    exit 1
}
### END - Functions ###

### START - Check parameters ###
IN__DIRDATA=
IN__DIRGITSHAKEMAP_FOR_PULL=
while getopts d:g:h OPTION
do
        case ${OPTION} in
        d)
            IN__DIRDATA="${OPTARG}"
            ;;
        g)
            IN__DIRGITSHAKEMAP_FOR_PULL="${OPTARG}"
            ;;
        h)
            syntax
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
	syntax
	exit 1
fi

shift $(($OPTIND - 1))

#
if [ -z ${IN__DIRDATA} ]; then
	echo ""
	echo "dir (-d) is mandatory"
	exit 1
else
	DIRDATA=$( cd ${IN__DIRDATA} && cd .. && pwd)
fi
if [ ! -d ${DIRDATA} ]; then
	echo ""
	echo "The input dir \"${DIRDATA}\" doesn't exist."
	exit 1
fi

#
if [ -z ${IN__DIRGITSHAKEMAP_FOR_PULL} ]; then
        echo ""
        echo "dir (-g) is mandatory"
        exit 1
else
        DIRGITSHAKEMAP_FOR_PULL=$( cd ${IN__DIRGITSHAKEMAP_FOR_PULL} && pwd)
fi
if [ ! -d ${DIRGITSHAKEMAP_FOR_PULL} ]; then
        echo ""
        echo "The input dir \"${DIRGITSHAKEMAP_FOR_PULL}\" doesn't exist."
        exit 1
fi
### END - Check parameters ###

date_start

cd ${DIRGITSHAKEMAP_FOR_PULL}
pwd

echo_date "Get actual commit:"
LAST_COMMIT=$(git rev-parse HEAD)
echo " LAST_COMMIT=${LAST_COMMIT}"
echo_date "Done"
echo ""

echo_date "Git fetch:"
git fetch
checkReturnCode ${?} ${DIRTMP}/make_pull_from_gitlab.sh.log
echo_date "Done"
echo ""

echo_date "Git log to get file new/updated:"
mkdir -p ${DIRTMP}
git log --name-only --pretty=format: main...origin/main | sed '/^$/d' > ${DIRTMP}/updated_file_form_git.txt
checkReturnCode ${?}
if [[ -s ${DIRTMP}/updated_file_form_git.txt ]]; then
	cat ${DIRTMP}/updated_file_form_git.txt
fi
echo_date "Done"
echo ""

echo_date "Git pull:"
git pull
checkReturnCode ${?}
echo_date "Done"
echo ""

echo_date "Check files new/updated:"
RUN=0
EVENTID=
if [[ -f ${DIRTMP}/eventids.txt ]]; then 
    rm ${DIRTMP}/eventids.txt
fi
if [[ -s ${DIRTMP}/updated_file_form_git.txt ]]; then
	while read FILE; do
		EVENTID=$( echo ${FILE} | awk -F"/" '{print $3}' )
		EVENTID_SUB=$( echo ${FILE} | awk -F"/" '{print $2}' )
        echo ${EVENTID} >> ${DIRTMP}/eventids.txt
		echo " FILE=${FILE}"
		FILE_WITHOUT_EVENTID_SUB=$( echo ${FILE} | sed "s/${EVENTID_SUB}\///" )
		echo " FILE_WITHOUT_EVENTID_SUB=${FILE_WITHOUT_EVENTID_SUB}"
		echo " EVENTID=${EVENTID}"

		if [ -f ${DIRDATA}/${FILE_WITHOUT_EVENTID_SUB} ]; then
			if diff -q ${FILE} ${DIRDATA}/${FILE_WITHOUT_EVENTID_SUB} &>/dev/null ; then
				echo "  the file \"${FILE_WITHOUT_EVENTID_SUB}\" already exists and is equal; nothing to do."
			else
				echo "  the file \"${FILE_WITHOUT_EVENTID_SUB}\" already exists but is different; update."
				RUN=1
			fi
		else
			echo "  the file \"${DIRDATA}/${FILE_WITHOUT_EVENTID_SUB}\" doesn't exist; copy."
			mkdir -p $(dirname ${DIRDATA}/${FILE_WITHOUT_EVENTID_SUB})
			checkReturnCode ${?}
			RUN=1
		fi

		#
		if (( ${RUN} == 1 )); then
			cp -v ${FILE} ${DIRDATA}/${FILE_WITHOUT_EVENTID_SUB}
			checkReturnCode ${?}
		fi
		echo ""
	done < ${DIRTMP}/updated_file_form_git.txt
fi
rm ${DIRTMP}/updated_file_form_git.txt
echo_date "Done"
echo ""

echo_date "Print eventid(s) changed:"
EVENTIDS=
if [[ -f ${DIRTMP}/eventids.txt ]]; then
    EVENTIDS=$( tr -s '\n'  ' ' < ${DIRTMP}/eventids.txt )
fi
echo "EVENTIDS=${EVENTIDS}"
if [[ -f ${DIRTMP}/eventids.txt ]]; then
    rm ${DIRTMP}/eventids.txt
fi
echo_date "Done"

#
#echo_date "Run docker:"
#for EVENTID in "${EVENTIDS[@]}"; do
#	echo " EVENTID=${EVENTID}"
        # Run docker
	#IN__PROFILE="world"
        #time ${DOCKER} run --rm --name shakemap4__${EVENTID} -v ${DIRSHAKEMAP4_PROFILES}:/home/shake/shakemap_profiles -v ${DIRSHAKEMAP4_DATA}:/home/shake/shakemap_data -v ${DIRSHAKEMAP4_LOCAL}:/home/shake/.local ${DOCKER_SHAKEMAP4_IMAGE} -p ${IN__PROFILE} -c"shake ${EVENTID} ${MODULE_SELECT} assemble -c \"SM4 run\" model contour shape info stations raster rupture gridxml history plotregr mapping" 2>&1 | tee -a ${DIRTMP}/shakemap4__${EVENTID}.txt
	#checkReturnCode ${?}
#	echo ""
#done
#echo_date "Done"
date_end
