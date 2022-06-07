#!/usr/bin/env python
# coding: utf-8

import os
import requests
import argparse
import json
import time

import xml.etree.ElementTree as ET

from obspy import UTCDateTime, Catalog
from obspy.core.event import Event, Origin, Magnitude, EventDescription, CreationInfo
from obspy.clients.fdsn import Client

#
# the new username should be asked to geonames
# http://www.geonames.org/login
USRNAME = "&username=spada"
ONEDAY = 3600*24
#
def get_IMs_ESM(ev, CATALOG, INPUTEVENTDIR):
	# create filename for  _dat.xml output file
	fname_dat = "%s_ESM_dat.xml" % (str(ev))
	FNAME_DAT = os.path.join(INPUTEVENTDIR, fname_dat)
	#
	# url_i_event='https://esm.mi.ingv.it/esmws/shakemap/1/query?eventid='+evid+'&catalog=EMSC&format=event'
	# url_i_fault='https://esm.mi.ingv.it/esmws/shakemap/1/query?eventid='+evid+'&catalog=EMSC&format=event_fault'
	# url_i_dat='https://esm.mi.ingv.it/esmws/shakemap/1/query?eventid='+evid+'&catalog=EMSC&format=event_dat&flag=all'

	# url_str_dat = "https://esm.mi.ingv.it/esmws/shakemap/1/query?eventid=%s&catalog=%s&format=event_dat" % (str(ev), CATALOG)
	url_str_dat = "https://esm-db.eu/esmws/shakemap/1/query?eventid=%s&catalog=%s&format=event_dat" % (str(ev), CATALOG)
	print ("request to ESM event_dat ws: %s" % (url_str_dat))
	try:
		r = requests.get(url_str_dat)
		status_dat = r.status_code
	except:
		print ("ESM event_dat problems: status_dat forced to 204")
		status_dat = 204
		pass

#     print "status:", status
	# if status == 204:
	#        return status

		# url_str_dat = "https://esm.mi.ingv.it/esmws/shakemap/1/query?eventid=%s&catalog=%s&format=event_dat&encoding=US-ASCII" % (str(ev), CATALOG)
		# r = requests.get(url_str_dat)
	if status_dat == 200:
		with open(FNAME_DAT, mode='wb') as localfile:
			localfile.write(r.content)

# ---------- done data
#
	# prepare for _ev
	fname_ev = "event.xml"
	FNAME_EV = os.path.join(INPUTEVENTDIR,fname_ev)
	FNAME_EV_TMP = os.path.join(INPUTEVENTDIR,"event_SM4.xml")
	#
	url_str_ev = "https://esm-db.eu/esmws/shakemap/1/query?eventid=%s&catalog=%s&format=event" % (str(ev), CATALOG)
	print ("request to ESM event ws: %s" % (url_str_ev))
	try:
		r = requests.get(url_str_ev)
		status_ev = r.status_code
	except:
		print ("ESM event problems: status_ev forced to 204")
		status_ev = 204
		pass


	status_ev = r.status_code
#     print "status:", status

	if status_ev == 200:
		with open(FNAME_EV, mode='wb') as localfile:
			localfile.write(r.content)
		# clean to adhere to new standard SM4
		clean_eventxml(FNAME_EV, FNAME_EV_TMP)
		stringa = "cp -p %s %s" % (FNAME_EV, FNAME_EV + '.ESM_save')
		os.system(stringa)

		stringa = "cp %s %s" % (FNAME_EV_TMP, FNAME_EV)
		os.system(stringa)

# ---------- done event
# # ---------- the following is added to skip the fault request that gives arror -
# 	status_fault = 204
# 	return status_dat, status_ev, status_fault
# # ---------- end of the modification fault request that gives arror -

	# prepare for _fault
	fname_fault = "event_fault.txt"
	rupture = "rupture.json"
	FNAME_FAULT = os.path.join(INPUTEVENTDIR,fname_fault)
	FNAME_RUPT = os.path.join(INPUTEVENTDIR,rupture)
	#

	url_str_fault = "https://esm-db.eu/esmws/shakemap/1/query?eventid=%s&catalog=%s&format=event_fault" % (str(ev), CATALOG)
	print ("request to ESM fault ws: %s" % (url_str_fault))
	try:
		r = requests.get(url_str_fault)
		status_fault = r.status_code
	except:
		print ("ESM event_fault problems: status_fault forced to 204")
		status_fault = 204
		pass

#     print "status:", status
	if status_fault == 200:
		with open(FNAME_FAULT, mode='wb') as localfile:
			localfile.write(r.content)
		jdict = text_to_json(FNAME_FAULT, new_format=False)
		with open(FNAME_RUPT,'w') as f:
			json.dump(jdict,f)
		stringa = "mv %s %s.sav" % (FNAME_FAULT, FNAME_FAULT)
		os.system(stringa)
	return status_dat, status_ev, status_fault

#
def get_IMs_RRSM(ev, CATALOG, INPUTEVENTDIR):
	# create filename for  _dat.xml output file
	fname_dat = "%s_RRSM_dat.xml" % (str(ev))
	FNAME_DAT = os.path.join(INPUTEVENTDIR, fname_dat)
	#
    # urlrrsm_event='http://www.orfeus-eu.org/odcws/rrsm/1/shakemap?eventid='+evid+'&type=event'
    # #urlrrsm_dat='ftp://www.orfeus-eu.org/pub/data/shakemaps/'+evid+'/input/event_dat.xml'
    # urlrrsm_dat='http://www.orfeus-eu.org/odcws/rrsm/1/shakemap?eventid='+evid
	url_str_dat = "http://www.orfeus-eu.org/odcws/rrsm/1/shakemap?eventid=%s" % (str(ev))
	print ("request to RRSM event_dat ws: %s" % (url_str_dat))
	try:
		r = requests.get(url_str_dat)
		status_dat = r.status_code
	except:
		print ("RRSM event_dat problems: status_dat forced to 204")
		status_dat = 204
		pass

	# print ("status:", status, 'event:', ev)

	if status_dat == 200:
		with open(FNAME_DAT, mode='wb') as localfile:
			localfile.write(r.content)

# ---------- done data
#
	# prepare for _ev
	fname_ev = "event.xml"
	FNAME_EV = os.path.join(INPUTEVENTDIR,fname_ev)
	FNAME_EV_TMP = os.path.join(INPUTEVENTDIR,"event_SM4.xml")
	#
	url_str_ev = "http://www.orfeus-eu.org/odcws/rrsm/1/shakemap?eventid=%s&type=event" % (str(ev))
	print ("request to RRSM event ws: %s" % (url_str_ev))
	try:
		r = requests.get(url_str_ev)
		status_ev = r.status_code
	except:
		print ("RRSM event problems: status_ev forced to 204")
		status_ev = 204
		pass
#     print "status:", status
	if status_ev == 200:
		with open(FNAME_EV, mode='wb') as localfile:
				localfile.write(r.content)
		# clean to adhere to new standard SM4
		clean_eventxml(FNAME_EV, FNAME_EV_TMP)
		stringa = "cp -p %s %s" % (FNAME_EV, FNAME_EV + '.RRSM_save')
		os.system(stringa)

		stringa = "cp -p %s %s" % (FNAME_EV_TMP, FNAME_EV)
		os.system(stringa)
	# ---------- done event
	return status_dat, status_ev
#

def clean_eventxml(event_file, new_event_file):
    netid = "IV"
    network = "INGV-ONT"
    #
    tree = ET.parse(event_file)
    root = tree.getroot()
    event = root.attrib
    # define the new attributes
    event['netid'] = netid
    event['network'] = network
    event['time'] = "%04d-%02d-%02dT%02d:%02d:%02dZ" % (int(event['year']), int(event['month']), int(event['day']),
                                        int(event['hour']),int(event['minute']),int(event['second']))
    # drop not needed values
    for k in ['year', 'month', 'day', 'hour', 'minute', 'second']:
        if k in event:
            del event[k]
    tree.write(new_event_file, xml_declaration=True, encoding="UTF-8")
    return

class ShakeLibException(Exception):
    """
    Class to represent errors in the Fault class.
    """

    def __init__(self, value):
        self.value = value

    def __str__(self):
        return repr(self.value)


def text_to_json(file, new_format=True):
    """
    Read in old or new ShakeMap 3 textfile rupture format and convert to
    GeoJSON.

    This will handle ShakeMap3.5-style fault text files, which can have the
    following format:
     - # at the top indicates a reference.
     - Lines beginning with a > indicate the end of one segment and the
       beginning of another.
     - Coordinates are specified in lat,lon,depth order.
     - Coordinates can be separated by commas or spaces.
     - Vertices can be specified in top-edge or bottom-edge first order.

    Args:
        file (str):
            Path to rupture file OR file-like object in GMT
            psxy format, where:

                * Rupture vertices are space/comma separated lat, lon, depth
                  triplets on a single line.
                * Rupture groups are separated by lines containing ">"
                * Rupture groups must be closed.
                * Verticies within a rupture group must start along the top
                  edge and move in the strike direction then move to the bottom
                  edge and move back in the opposite direction.

        new_format (bool):
            Indicates whether text rupture format is
            "old" (lat, lon, depth) or "new" (lon, lat, depth) style.

    Returns:
        dict: GeoJSON rupture dictionary.

    """
    isfile = False
    if hasattr(file, 'read'):
        f = file
    else:
        f = open(file, 'rt')
        isfile = True

    reference = ''
    polygons = []
    polygon = []
    for line in f.readlines():
        if not len(line.strip()):
            continue

        if line.strip().startswith('#'):
            # Get reference string
            reference += line.strip().replace('#', '')
            continue

        if line.strip().startswith('>'):
            if not len(polygon):
                continue
            polygons.append(polygon)
            polygon = []
            continue

        # first try to split on whitespace
        parts = line.split()
        if len(parts) == 1:
            if new_format:
                raise ShakeLibException(
                    'Rupture file %s has unspecified delimiters.' % file)
            parts = line.split(',')
            if len(parts) == 1:
                raise ShakeLibException(
                    'Rupture file %s has unspecified delimiters.' % file)

        if len(parts) != 3:
            msg = 'Rupture file %s is not in lat, lon, depth format.'
            if new_format:
                'Rupture file %s is not in lon, lat, depth format.'
            raise ShakeLibException(msg % file)

        parts = [float(p) for p in parts]
        if not new_format:
            old_parts = parts.copy()
            parts[0] = old_parts[1]
            parts[1] = old_parts[0]
        polygon.append(parts)

    if len(polygon):
        polygons.append(polygon)

    if isfile:
        f.close()

    # Try to fix polygons
    original_polygons = polygons.copy()
    fixed = []
    n_polygons = len(polygons)
    for i in range(n_polygons):
        n_verts = len(polygons[i])
        success = False
        for j in range(n_verts - 1):
            try:
                _check_polygon(polygons[i])
                success = True
                break
            except ValueError:
                polygons[i] = _rotate_polygon(polygons[i])
        if success:
            fixed.append(True)
        else:
            fixed.append(False)

    if not all(fixed):
        polygons = original_polygons

    json_dict = {
        "type": "FeatureCollection",
        "metadata": {
            'reference': reference
        },
        "features": [
            {
                "type": "Feature",
                "properties": {
                    "rupture type": "rupture extent"
                },
                "geometry": {
                    "type": "MultiPolygon",
                    "coordinates": [polygons]
                }
            }
        ]
    }
    validate_json(json_dict)

    return json_dict

def _check_polygon(p):
    """
    Check if the verticies are specified top first.

    Args:
        p (list):
            A list of five lon/lat/depth lists.

    Raises:
        ValueError: incorrectly specified polygon.

    """
    n_points = len(p)
    if n_points % 2 == 0:
        raise ValueError('Number of points in polyon must be odd.')

    if p[0] != p[-1]:
        raise ValueError('First and last points in polygon must be '
                         'identical.')

    n_pairs = int((n_points - 1) / 2)
    for j in range(n_pairs):
        # -------------------------------------------------------------
        # Points are paired and in each pair the top is first, as in:
        #
        #      _.-P1-._
        #   P0'        'P2---P3
        #   |                  \
        #   P7---P6----P5-------P4
        #
        # Pairs: P0-P7, P1-P6, P2-P5, P3-P4
        # -------------------------------------------------------------
        top_depth = p[j][2]
        bot_depth = p[-(j + 2)][2]
        if top_depth >= bot_depth:
            raise ValueError(
                'Top points must be ordered before bottom points.')

def validate_json(d):
    """
    Check that the JSON format is acceptable. This is only for requirements
    that are common to both QuadRupture and EdgeRupture.

    Args:
        d (dict): Rupture JSON dictionary.
    """
    if d['type'] != 'FeatureCollection':
        raise Exception('JSON file is not a \"FeatureColleciton\".')

    if len(d['features']) != 1:
        raise Exception('JSON file should contain excactly one feature.')

    if 'reference' not in d['metadata'].keys():
        raise Exception('Json metadata field should contain '
                        '\"reference\" key.')

    f = d['features'][0]

    if f['type'] != 'Feature':
        raise Exception('Feature type should be \"Feature\".')

    geom = f['geometry']

    if (geom['type'] != 'MultiPolygon' and
            geom['type'] != 'Point'):
        raise Exception('Geometry type should be \"MultiPolygon\" '
                        'or \"Point\".')

    if 'coordinates' not in geom.keys():
        raise Exception('Geometry dictionary should contain \"coordinates\" '
                        'key.')

    polygons = geom['coordinates'][0]

    if geom['type'] == 'MultiPolygon':
        n_polygons = len(polygons)
        for i in range(n_polygons):
            _check_polygon(polygons[i])

#
def get_country_from_geonames_ws(lon, lat, radius='0.01'):
    """
    This function reads the GeoNames web services to determine the country code of nearest country from a given circle
    """

    # fix for dateline issue
    lon_ws = lon
    if lon > 180: lon_ws = lon - 360
    if lon < -180: lon_ws = lon + 360

    FEEDURL = "http://api.geonames.org/countryCodeJSON?lat=" + str(lat) + "&lng=" + str(lon_ws) + '&radius=' + str(radius) + USRNAME

    response_not_ok = True
    status = 0
    ind = 0
    while (status != 200 or response_not_ok) and ind < 5:
        if ind > 0: time.sleep(3)
        response = requests.get(FEEDURL)
        status = response.status_code
        if response.text.find('"message":"no country code found"') != -1 or response.text.find('"countryName"') != -1:
            response_not_ok = False
        ind = ind + 1
    jdict = response.json()

    if 'countryCode' in jdict.keys():
        countryCode = jdict['countryCode']
        countryName = jdict['countryName']
        distance = jdict['distance']
        # print("-- Nearest country to given location (lat: %.2f, lon: %.2f, radius: %s) is %s" % (lat, lon_ws, radius, countryName))
        return countryCode, countryName, distance
    else:
        # print("-- Location (%.2f, %.2f) is more than %s km from nearest coast" % (lat, lon_ws, radius))
        countryCode, countryName, distance = (False, False, False)
        return countryCode, countryName, distance

def read_event_coords(fname):
    tree = ET.parse(fname)
    root = tree.getroot()
    #
    for c in root.iter('earthquake'):
        eq_dict = c.attrib
    lon = eq_dict['lon']
    lat = eq_dict['lat']
    return float(lon),float(lat)

def init_confs(conf_file_list, config_dir):
    extension = '.conf'
    out_target_files = []

    for f in conf_file_list:
        target_fname = f + extension
        full_target_file = os.path.join(config_dir,target_fname)
        out_target_files.append(full_target_file)
    return out_target_files

def src_confs(conf_file_list, config_dir,country_name):
    extension = '.conf' + '.' + country_name
    out_src_files = []
    for f in conf_file_list:
        model_src_fname = f + extension
        source_file = os.path.join(config_dir,model_src_fname)
        out_src_files.append(source_file)
    return out_src_files

    cp_command = "cp -p %s %s" % (model_src_fname,model_target_file)
    print (cp_command)
    os.system(cp_command)

# extract ID from event string
def extract_id(string, fdsn_client):

    if fdsn_client == "USGS":
        tmp1, tmp2 = string.split("&")
        tmp3, event_id = tmp1.split("=")

    elif fdsn_client == "INGV":
        tmp1, tmp2 = string.split("?")
        tmp3, event_id = tmp2.split("=")

    elif fdsn_client == "IRIS":
        tmp1, tmp2 = string.split("?")
        tmp3, event_id = tmp2.split("=")

    elif fdsn_client == "EMSC":
        tmp1, tmp2 = string.split(":")
        tmp3, tmp4, event_id = tmp2.split("/")

    elif fdsn_client == "GFZ":
        event_id = string
    else:
        event_id = string

    return event_id

# routine to extract an obspy catalog and a list of event_ids from fdsn event ws
def find_events(fdsn_client, start_time="1900-01-01", end_time="2100-01-01", minmag=5.0, maxmag=9.9, latmin=-90, latmax=90, lonmin=-180, lonmax=180, mode='sing', orderby='time', verbose=True):

    # mode = hist -> historical records of seismicity (eg. custom time window)
    # mode = sing -> discovery of a (hopefully) single event

    end_time = UTCDateTime(end_time)

    if mode == 'sing':
        delta_time = 7 # 7 seconds around event time on either side
        starttime = end_time - delta_time
        endtime = end_time + delta_time
    elif mode == 'hist':
        endtime = end_time
        starttime = UTCDateTime(start_time)
    else:
        print("mode " + mode + " is not supported.")
        return False

    client = Client(fdsn_client)

    # another shitty dateline patch
    if lonmax > 180:
        # split in two requests
        try: cat1 = client.get_events(starttime=starttime, endtime=endtime, minmagnitude=minmag, maxmagnitude=maxmag, minlatitude=latmin, maxlatitude=latmax, minlongitude=lonmin, maxlongitude=180, orderby=orderby, limit=1000)
        except: cat1 = Catalog()
        try: cat2 = client.get_events(starttime=starttime, endtime=endtime, minmagnitude=minmag, maxmagnitude=maxmag, minlatitude=latmin, maxlatitude=latmax, minlongitude=-180, maxlongitude=-(360-lonmax), orderby=orderby, limit=1000)
        except: cat2 = Catalog()
        # combine the catalog object
        cat = cat1 + cat2
    else:
        try:
            cat = client.get_events(starttime=starttime, endtime=endtime, minmagnitude=minmag, maxmagnitude=maxmag, minlatitude=latmin, maxlatitude=latmax, minlongitude=lonmin, maxlongitude=lonmax, orderby=orderby, limit=1000)
        except:
            print ("No events were found in the time window: [%s / %s]" % (starttime, endtime))
            quit()

#     tmp = str(cat[0].resource_id)
#     event_id = extract_id(tmp, fdsn_client)
    event_ids=[]
    for c in cat:
        tmp = str(c.resource_id)
        event_ids.append(extract_id(tmp, fdsn_client))

    if verbose == True:

        for c in cat:
            ot = c.origins[0].time
            lat = c.origins[0].latitude
            lon = c.origins[0].longitude
            dep = c.origins[0].depth #/ 1000.
            mag = c.magnitudes[0].mag
            mag_type = c.magnitudes[0].magnitude_type
            print("%s %s      %s   %s %s %s   %s (%s)" % (fdsn_client, event_id, ot, lat, lon, dep, mag, mag_type))

    return cat, event_ids

if __name__ == "__main__":
    #
    # set default values
    break_flag = 0
    #
    # define the default value of end_time to 'now'
    time_end = UTCDateTime()
    end_time = time_end.strftime("%Y-%m-%dT%H:%M:%S")
    #
    # default min magnitude
    minmag = 4.0
    #
    # default time backward to cross-check the input files of ESM
    chkbcktime = 1.0 # in days
    # check_time_bckwd = chkbcktime*ONEDAY # in seconnds

    parser = argparse.ArgumentParser()

    parser.add_argument("days",  help="set the number of days before end time (15m, 1d, 5d, 10d, 30d, 365d)", choices=['15m', '1d', '5d', '10d', '30d', '365d'])
    parser.add_argument("shake_home_dir", help="provide the shakemap installation home dir (e.g., /Users/michelini/shakemap_profiles/world)")
    parser.add_argument("-e","--end_time", nargs="?", const=end_time, help="provide the end time  (e.g., 2020-10-23); [default is now]")
    parser.add_argument("-m","--minmag", nargs="?", const=minmag, help="provide the minimum magnitude (e.g.,4.5); [default is 4.0]")
    parser.add_argument("-b","--chkbcktime", nargs="?", const=chkbcktime, help="provide the number of days to check for ESM new input data [default is 1.0]")

    args = parser.parse_args()
    #
    day_str = args.days
    if day_str == '15m':
        days = 1./24. * 0.25
    else:
        days = float(day_str[:-1])
    #
    #
    SHAKE_HOME_DIR = args.shake_home_dir
    #
    if args.end_time is not None:
        end_time = args.end_time
        time_end = UTCDateTime(end_time)
    #
    if args.minmag is not None:
        minmag = float(args.minmag)

    # time to verify backward if input files from ESM have changed
    if args.chkbcktime is not None:
        chkbcktime = float(args.chkbcktime)
    check_time_bckwd = chkbcktime*ONEDAY # in seconnds


    # define the number of seconds in order to calculate the start_time
    # identify start and end times of the last month
    #
    time_span = days * ONEDAY

    time_start = time_end - time_span
    start_time = time_start.strftime("%Y-%m-%dT%H:%M:%S")
    #
    #
    #
    fdsn_client = 'EMSC'
    cat,event_ids = find_events(fdsn_client, start_time=start_time, end_time=end_time, minmag=minmag, latmin=27, latmax=81,
                                lonmin=-32, lonmax=51, mode='hist', verbose=False)
    #
    # define the event directories
    DATA_DIR = os.path.join(SHAKE_HOME_DIR,'data')
    #
    #  summary of input parameters variables
    print ('EVENTS:')
    print (event_ids)
    #
    print ("STARTIME: %s   ENDTIME: %s" % (start_time, end_time))
    print ("MINMAG: %.1f" % (minmag))
    print ("ESM BCK VERIFICATION (days): %.2f" % (chkbcktime))
    #
    print ("run at: %s" % (UTCDateTime().strftime("%Y-%m-%dT%H:%M:%S")))


    # quit()
    #
    #
    for event_id in event_ids:
        break_flag = 0
        # define the event directory
        #
        print ("\nDOING EVENT: %s" % (event_id))
        EVENT_DIR = os.path.join(DATA_DIR, event_id)
        EVENT_DIR_CURRENT = os.path.join(EVENT_DIR,'current')
        # define the files that have been possibly downloaded from the ws
        RRSM_datXML_file = os.path.join(EVENT_DIR_CURRENT,event_id + '_RRSM_dat.xml')
        ESM_datXML_file = os.path.join(EVENT_DIR_CURRENT,event_id + '_ESM_dat.xml')
        #
        # THESE ARE OPERATIONS BEFORE DOWNLOAD TO CHECK FOR EXISTING EVENT DATA
        # ---- verify if the files exists and if their creation time is less than a given time
        #
        timestamp = int(time.time())
        #  ESM first
        # do the following only if the the <event_id>_ESM_dat.xml file exists
        if os.path.isfile(ESM_datXML_file):
            print ("   ESM: input %s file exist" % (ESM_datXML_file))
            # some cleaning in case that <event_id>_RRSM_dat.xml still exists
            if os.path.isfile(RRSM_datXML_file):
                os.remove(RRSM_datXML_file)
            #
            # check the creation time of the <event_id>_ESM_dat.xml
            ESM_unix_time = os.path.getctime(ESM_datXML_file)
            # calculate the difference in seconds between the ESM_dat.xml file and the
            # current timestamp
            ESM_time_from_creation = timestamp - ESM_unix_time
            # if the call is made less than the time_span, no need to download
            # and calculate shakemap
            if ESM_time_from_creation < check_time_bckwd:
                print ("   ESM: input %s file has been generated %.2f days earlier" % (ESM_datXML_file, ESM_time_from_creation/(3600*24.)))
                continue
        # RRSM
        # if the RRSM_datXML_file exists already skip the event
        # if os.path.isfile(RRSM_datXML_file):
        #     print ("   RRSM: input %s file exist" % (RRSM_datXML_file))
        #     # continue
        #     RRSM_unix_time = os.path.getctime(RRSM_datXML_file)
        #     RRSM_time_from_creation = timestamp - RRSM_unix_time
        #
        #     if RRSM_time_from_creation < check_time_bckwd:
        #         print ("   RRSM: input %s file has been generated %.2f days earlier" % (ESM_datXML_file, ESM_time_from_creation/(3600*24.)))
        #         continue

        # ------ END INITIAL CHECKING OF EVENT DATA
        #
        # IF NEW EVENT -------
        # generate the directories if they are not already present
        if not os.path.isdir(EVENT_DIR):
            os.mkdir(EVENT_DIR)

        if not os.path.isdir(EVENT_DIR_CURRENT):
            os.mkdir(EVENT_DIR_CURRENT)
        #
        # get the data from esm
        CATALOG = fdsn_client
        #
        # DOWNLOAD THE DATA ----
        # the procedure attempts to download only the data from one webservice
        # if it finds the data in ESM, it skips downloading data from RRSM
		# ---------------------------------------------
        # ADDED THE TRY TO HANDLE ESM WEB SERVICES PROBLEM
        # try:
        #     status_dat, status_ev, status_fault = get_IMs_ESM(event_id, CATALOG, EVENT_DIR_CURRENT)
        # except:
        #     print ('PROBLEMS WITH ESM WEB SERVICES: STATUS VALUES SET ALL TO 204')
        #     status_ev = 204; status_dat = 204; status_fault = 204
		# --------------------------------------------
        status_dat, status_ev, status_fault = get_IMs_ESM(event_id, CATALOG, EVENT_DIR_CURRENT)

        print ('   ESM: results of the ws query for _dat, event and fault: %d %d %d' % (status_dat, status_ev, status_fault))
        if (status_ev == 204) and (status_dat == 204):
            print ("   ESM: no event_dat.xml and no %s found!" % (ESM_datXML_file))
            print ("   --- Now try the RRSM webservice")
            break_flag = 1
        # except:
        #     print ("problems with downloading data of %s event of ESM DB" % (event_id))
        #     break_flag = 1
        # the download of the RRSM data is done only if the ESM data are not available
        if break_flag == 1:
            # try:
            status_dat, status_ev = get_IMs_RRSM(event_id, CATALOG, EVENT_DIR_CURRENT)
            # print (status_dat, status_ev)
            print ('   RRSM: results of the ws query for _dat, event: %d %d' % (status_dat, status_ev))

            if (status_dat == 204) and  (status_ev == 204):
                print ("   RRSM: no event_dat.xml and no %s found!" % (RRSM_datXML_file))
                os.rmdir(EVENT_DIR_CURRENT)
                os.rmdir(EVENT_DIR)
                print ("   --- Removed event directory with empty files  %s" % EVENT_DIR)
                continue
            # except:
            #     print ("problems with downloading data of %s event of RRSM DB" % (event_id))
            #     continue
        #
        # the following does some cleaning since the web service provides empty files
        # this removes empty  files

        # onlyfiles = [f for f in os.listdir(EVENT_DIR_CURRENT) if os.path.isfile(os.path.join(EVENT_DIR_CURRENT, f))]
        # for f in onlyfiles:
        #     fname = os.path.join(EVENT_DIR_CURRENT,f)
        #     # print ("filename: %s  size: %d" % (fname, os.path.getsize(fname)))
        #     if os.path.getsize(fname) == 0:
        #         os.remove(fname)
        #         print ("removing empty file  %s" % fname)

        # cleaning: this removes a directory if there are empty files
        # if os.path.getsize(EVENT_DIR_CURRENT) <= 128:
        #     # print ("skip to next event since this does not have data and removes the event directory")
        #     # list the files inside EVENT_DIR_CURRENT
        #     onlyfiles = [f for f in os.listdir(EVENT_DIR_CURRENT) if os.path.isfile(os.path.join(EVENT_DIR_CURRENT, f))]
        #     for f in onlyfiles:
        #         os.remove(os.path.join(EVENT_DIR_CURRENT,f))
        #     #
        #     os.rmdir(EVENT_DIR_CURRENT)
        #     os.rmdir(EVENT_DIR)
        #     print ("removed event directory with empty files  %s" % EVENT_DIR)
        #     continue

        # define the install configuration directory
        INSTALL_DIR = os.path.join(SHAKE_HOME_DIR,'install')
        CONFIG_DIR = os.path.join(INSTALL_DIR,'config')
        #
        # ------ extract the coordinates -----
        event_fname = os.path.join(EVENT_DIR_CURRENT,'event.xml')
        lon, lat = read_event_coords(event_fname)
        #
        country = get_country_from_geonames_ws(lon, lat)
        print (country[0])
        if country[0] == False:
            country_code = 'IT'
        else:
            country_code = country[0]

        #
        # ---------
        # define the configuration files to be copied
        conf_file_list = ['model','select','products','gmpe_sets','modules']
        target_conf_files = init_confs(conf_file_list, CONFIG_DIR)

        if country_code == 'CH':
            src_conf_files = src_confs(conf_file_list, CONFIG_DIR,country_code)
            for f,g in zip(src_conf_files,target_conf_files):
                cp_command = "cp -p %s %s" % (f,g)
                print (cp_command)
                os.system(cp_command)
        else:
            # country_code = 'IT'
            conf_type = 'INGV'
            src_conf_files = src_confs(conf_file_list, CONFIG_DIR,conf_type)
            for f,g in zip(src_conf_files,target_conf_files):
                cp_command = "cp -p %s %s" % (f,g)
                print (cp_command)
                os.system(cp_command)
        #
        # run ShakeMap
        print ("Copy input event.xml, _dat.xml, CH or IT configurations and push to a GitHub project (shuld be created) like https://gitlab.rm.ingv.it/shakemap/shakemap-input-it ");
        #command = ("shake %s select assemble -c 'run shakemap4' model  contour shape info stations raster rupture gridxml history plotregr mapping" % (event_id))
        # select assemble -c \"SM4 run\" model contour shape info stations raster rupture gridxml history plotregr mapping
        #os.system(command)
