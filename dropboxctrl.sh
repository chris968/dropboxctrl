#!/bin/bash
#
#

version=1.0

# User account that run the Dropbox service, you need sudo privileges
user=dropbox
# log file path
logFile=/tmp/dropbox_status.log
# Alerte message body path
msg=/tmp/dropbox_status.msg
# counter file path
countFile=/tmp/dropbox_status.cnt
# Instance or customer name (subject) for alerts messages
instanceName="TEST"
# Mail to for alerts messages
mailTo="support@stuxnet.il"
# Mail from for alerts messages
mailFrom="dropbox@stuxnet.il"
# Maximum age of the log file in days
logDays=7
# Maximum count for starting and synchronisation state
maxCount=5

# Environment configuration
envConfig="env LANG=en_US.UTF8 LANGUAGE=en_US:en"

# Initialize timeout counter
SECONDS=0
timeout=$((SECONDS+120))

function version () {
	echo "Dropbox Control Script Version: $version"
}

function usage () {
	echo "Please choose and action to perform"
	echo "$0 status"
	echo "$0 start"
	echo "$0 stop"
	echo "$0 restart"
	echo "$0 logrotate"
	echo "$0 version"
}

function procstate () {
	if (ps -alx | grep -v grep | grep -iq "dropbox-lnx.") 2> /dev/null ; then
		return 0
	else
		return 1
	fi
}

function dropboxstart () {
	if procstate; then
		echo "$(date +%Y-%m-%d) - ERROR: dropbox already running"
		return 1
	else
		while (( SECONDS < $timeout )); do
			sudo -H -u $user $envConfig dropbox start &> /dev/null
			if procstate; then
				return 0
			fi
		done
		echo "$(date +%Y-%m-%d) - ERROR: Timeout while starting Dropbox"
		return 1
	fi
}


function dropboxstop () {
	if ! procstate; then
		echo "$(date +%Y-%m-%d) - ERROR: dropbox already stopped"
		return 1
	else
		while (( SECONDS < $timeout )); do
			sudo -H -u $user $envConfig dropbox stop &> /dev/null
			if ! procstate; then
				return 0
			fi
		done
		echo "$(date +%Y-%m-%d) - ERROR: Timeout while stopping Dropbox"
		return 1
	fi
}


function dropboxrestart () {
	if dropboxstop; then
		if dropboxstart; then
			return 0
		else
			return 1
		fi
	else
		return 1
	fi
}

function dropboxstatus () {
	statusMsg=$(sudo -H -u $user dropbox status)
	echo $statusMsg
	if echo $statusMsg | grep -q "Up to date"
	then
		echo "$(date +%Y-%m-%d): Dropbox Status OK" >> $logFile
		return 0
	elif echo $statusMsg | egrep -q "Starting|Indexing"
	then
	 	if [ ! -e $countFile ]
		then
			echo "$(date +%Y-%m-%d): Dropbox Status Warning" >> $logFile
			echo "1" > $countFile
		else
			count=$(cat $countFile)
			if [ $count -eq $maxCount ]
			then
				rm -rf $countFile
				mailalert
			else
				count=$((count+1))
				echo $count > $countFile
			fi
		fi
	else
		echo "$(date +%Y-%m-%d): Dropbox Status Error" >> $logFile
		echo "$(date +%Y-%m-%d): $statusMsg" >> $logFile
		mailalert
		return 1
	fi
}

function logrotate () {
	curDate=$(date +%y%m%d)
	logDate=$(awk -F '=' '/LOGDATE/{print $2}' $logFile)
	if [ ! -z $logFileDate ]
	then
		echo "$(date +%Y-%m-%d): Log date stamp is present" >> $logFile
		if [ $curDate -ge $(date --date=$logFileDate'+'$logFileDays' days' +%y%m%d) ]
		then
			echo "$(date: ): Time to rotate the log !" >> $logFile
			mv $logFile $logFile.0
			echo "LOGDATE=$curDate" > $logFile
			echo "$(date +%Y-%m-%d): New log files created" >> $logFile
		fi
	else
		echo "$(date +%Y-%m-%d): Log date stamp is not present, create new log file with stamp" >> $logFile
		mv $logFile $logFile.0
		echo "LOGDATE=$curDate" > $logFile
		echo "$(date +%Y-%m-%d): New log files created" >> $logFile
	fi
}

function prereq () {
	if ! which sudo 2>&1 > /dev/null || ! which mail 2>&1 > /dev/null  || ! mail --version | grep -q "GNU Mailutils"; then
		echo "sudo or GNU Mail is not installed !"
		exit 1
	elif [ ! -f $logFile ]; then
		echo "LOGDATE=$curDate" > $logFile
	fi
}

function mailalert () {
	 mail -s "$instanceName Dropbox Alert" $mailTo -a "From: $mailFrom" -A $logFile < $msg
}

#
# MAIN
#

# Verify prerequired softwares (sudo, GNU Mail)
prereq

case $1 in
	status)
	dropboxstatus
	;;
	restart)
	if dropboxrestart; then
		exit 0
	else
		exit 1
	fi
	;;
	start)
	if dropboxstart; then
		exit 0
	else
		exit 1
	fi
	;;
	stop)
	if dropboxstop; then
		exit 0
	else
		exit 1
	fi
	;;
	logrotate)
	logrotate
	;;
	version)
	version
	;;
	*)
	usage
	;;
esac
