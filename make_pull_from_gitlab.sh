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
while getopts "d:g:h" OPTION
do
        case "${OPTION}" in
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

echo_date "Sync event current directories:"
EVENTID=
if [[ -f ${DIRTMP}/eventids.txt ]]; then
    rm "${DIRTMP}/eventids.txt"
fi
if [[ -f ${DIRTMP}/eventids_to_sync.txt ]]; then
    rm "${DIRTMP}/eventids_to_sync.txt"
fi
if [[ -s ${DIRTMP}/updated_file_form_git.txt ]]; then
	while read -r FILE; do
		echo " FILE=${FILE}"

		if [[ ! "${FILE}" =~ ^data/([0-9]{6})/([0-9]{8}_[0-9]{7})/current/.+ ]]; then
			echo "  the file path doesn't match expected format \"data/<YYYYMM>/<YYYYMMDD_0000000>/current/...\"; skip."
			echo ""
			continue
		fi

		EVENTID_SUB="${BASH_REMATCH[1]}"
		EVENTID="${BASH_REMATCH[2]}"
		echo " EVENTID_SUB=${EVENTID_SUB}"
		echo " EVENTID=${EVENTID}"
		echo "${EVENTID_SUB}/${EVENTID}" >> "${DIRTMP}/eventids_to_sync.txt"
		echo ""
	done < "${DIRTMP}/updated_file_form_git.txt"

	if [[ -f ${DIRTMP}/eventids_to_sync.txt ]]; then
		sort -u "${DIRTMP}/eventids_to_sync.txt" > "${DIRTMP}/eventids_to_sync.txt.new"
		checkReturnCode ${?}
		mv "${DIRTMP}/eventids_to_sync.txt.new" "${DIRTMP}/eventids_to_sync.txt"
		checkReturnCode ${?}

		while IFS="/" read -r EVENTID_SUB EVENTID; do
			SRC_CURRENT="data/${EVENTID_SUB}/${EVENTID}/current"
			DST_EVENT="${DIRDATA}/data/${EVENTID}"
			DST_CURRENT="${DST_EVENT}/current"

			echo " EVENTID=${EVENTID}"
			echo " SRC_CURRENT=${SRC_CURRENT}"
			echo " DST_EVENT=${DST_EVENT}"
			echo " DST_CURRENT=${DST_CURRENT}"

			if [[ -d "${SRC_CURRENT}" ]]; then
				echo "  the source current directory exists in Git; sync local current directory."
				if [[ -d "${DST_CURRENT}" ]]; then
					rm -rf "${DST_CURRENT}"
					checkReturnCode ${?}
					echo "  Removed: ${DST_CURRENT}"
				fi
				mkdir -p "${DST_CURRENT}"
				checkReturnCode ${?}
				cp -av "${SRC_CURRENT}/." "${DST_CURRENT}/"
				checkReturnCode ${?}
				echo "${EVENTID}" >> "${DIRTMP}/eventids.txt"
			else
				echo "  the source current directory doesn't exist in Git; remove local event directory."
				if [[ -d "${DST_EVENT}" ]]; then
					rm -rf "${DST_EVENT}"
					checkReturnCode ${?}
					echo "  Removed: ${DST_EVENT}"
				else
					echo "  Local event directory \"${DST_EVENT}\" doesn't exist; nothing to remove."
				fi
			fi
			echo ""
		done < "${DIRTMP}/eventids_to_sync.txt"
	fi
fi
if [[ -f ${DIRTMP}/eventids_to_sync.txt ]]; then
    rm "${DIRTMP}/eventids_to_sync.txt"
fi
rm "${DIRTMP}/updated_file_form_git.txt"
echo_date "Done"
echo ""

echo_date "Print eventid(s) changed:"
EVENTIDS=
if [[ -f ${DIRTMP}/eventids.txt ]]; then
    sort -u "${DIRTMP}/eventids.txt" > "${DIRTMP}/eventids.txt.new"
    checkReturnCode ${?}
    mv "${DIRTMP}/eventids.txt.new" "${DIRTMP}/eventids.txt"
    checkReturnCode ${?}
    EVENTIDS=$( tr -s '\n'  ' ' < "${DIRTMP}/eventids.txt" )
fi
echo "EVENTIDS=${EVENTIDS}"
if [[ -f ${DIRTMP}/eventids.txt ]]; then
    rm "${DIRTMP}/eventids.txt"
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
