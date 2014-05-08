#!/bin/sh

# set -x

# Program name: nmon_start_for_aix.sh
# Purpose - nmon sample script to start collecting data with a 1mn interval refresh
# Author - Guilhem Marchand
# Disclaimer:  this provided "as is".  
# Date - April 2014
# Modified for AIX by Barak Griffis 03052014
# Unified for Solaris/Linux/AIX by Barak Griffis 03072014

#################################################
## 	Your Customizations Go Here            ##
#################################################

[ -z ${SPLUNK_HOME} ] && { echo "`date`, ERROR, SPLUNK_HOME variable is not defined"; exit 1; }

# Splunk Home variable: This should automatically defined when this script is being launched by Splunk
# If you intend to run this script out of Splunk, please set your custom value here
SPL_HOME=${SPLUNK_HOME}

# Check SPL_HOME variable is defined, this should be the case when launched by Splunk scheduler
[ -z ${SPL_HOME} ] && { echo "`date`, ERROR, SPL_HOME (SPLUNK_HOME) variable is not defined"; exit 1; }

if [ ! $(echo $SPLUNK_HOME|grep -q forwarder) ];then
        APP=$SPLUNK_HOME/etc/apps/TA-nmon
elif [ -d $SPLUNK_HOME/etc/slave-apps/_cluster ];then
        APP=$SPLUNK_HOME/etc/slave-apps/PA-nmon
else
        APP=$SPLUNK_HOME/etc/apps/nmon
fi


# Nmon BIN full path (including bin name), please update this value to reflect your Nmon installation
NMON=$(which nmon 2>&1)
if [ ! -x $NMON ];then
	# No nmon found in env, so using prepackaged version
	case $(uname) in 
		Linux)
			NMON="$APP/bin/nmon_$(arch)_$(uname|tr '[:upper:]' '[:lower:]')"
			;;
		*)
			echo "No nmon installed here"
			;;	
	esac
fi


# Nmon working directory, Nmon will produce the nmon csv file here
# Default to spool directory of Nmon Splunk App
WORKDIR=${APP}/var/nmon_temp
[ ! -d $WORKDIR ] && { mkdir -p $WORKDIR; }

# Nmon file final destination
# Default to nmon_repository of Nmon Splunk App
NMON_REPOSITORY=${APP}/var/nmon_repository
[ ! -d $NMON_REPOSITORY ] && { mkdir -p $NMON_REPOSITORY; }

#also needed - 
[ -d ${APP}/var/csv_repository ] || { mkdir -p ${APP}/var/csv_repository; }
[ -d ${APP}/var/config_repository ] || { mkdir -p ${APP}/var/config_repository; }

# Refresh interval in seconds, Nmon will this value to refresh data each X seconds
# Default to 30 seconds
interval="30"

# Number of Data refresh occurences, Nmon will refresh data X times
# Default to 3
occurence="3"

####################################################################
#############		Main Program 			############
####################################################################

# Set Nmon command line
nmon_command="${NMON} -ft -s ${interval} -c ${occurence}"

# Initialize PID variable
PIDs="" 


# Check nmon binary exists and is executable
if [ ! -x ${NMON} ]; then
	
	echo "`date`, ERROR, could not find Nmon binary (${NMON}) or execution is unauthorized"
	exit 2
fi	

# Search for any running Nmon instance, stop it if exist and start it, start it if does not
cd ${WORKDIR}
PIDs=$(ps -ef| grep "${nmon_command}" | grep -v grep |grep splunk| awk '{print $2}')

case ${PIDs} in

	"" )
    		# Start NMON
		mv *.nmon ${NMON_REPOSITORY}/ >/dev/null 2>&1
		echo "starting nmon : ${nmon_command} in ${WORKDIR}"
		${nmon_command}
	;;
	
	* )
		# Soft kill
		kill ${PIDs}
		sleep 2
	
		mv *.nmon ${NMON_REPOSITORY}/ >/dev/null 2>&1
		# Start Nmon
		# echo "starting nmon : ${nmon_command} in ${WORKDIR}"
		${nmon_command}
	;;
	
esac
