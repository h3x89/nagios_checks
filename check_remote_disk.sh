#!/bin/bash
##########################################################
#

#define command {
#        command_name    check_remote_disk
#        command_line   /etc/check_mk/plugins/check_disk.sh -l $ARG1$ -d $ARG2$ -H $ARG3$ -w $ARG4$ -c $ARG5$
#                }
                
#( ( "check_remote_disk!administrator!'\/'!172.0.0.1!75!90", "fs_/", True ), [ "server"] ),

                
# Plugin To Check Free Disk Space
# Using Ssh_login
# Copyright (C) 2015 Eduardo Dimas (https://github.com/eddimas/nagios-plugins)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
# COMMAND-LINE FOR CHECK_DISKS
# USAGE $USER1$/check_disk.sh -l username -H $HOSTNAME$ -w 75 -c 90"
#
# COMMAND-LINE FOR SERVICE (EXAMPLE)
# $USER1$/check_disk.sh!$USER1$!$HOSTNAME$!75!90
#
# Output example for OK, warning, critical and (the worst) warning + critical
#
# [eddimas@centos7 ~]$ ./check_disk.sh -l eddimas -H 192.168.1.74 -w 75 -c 90
# OK. DISK STATS: / 14% of 33G, /dev 0% of 956M, /dev/shm 1% of 966M, /run 1% of 966M, /sys/fs/cgroup 0% of 966M, /boot 34% of 521M,
#
# [eddimas@centos7 ~]$ ./check_disk.sh -l eddimas -H 192.168.1.74 -w 30 -c 40
# WARNING. DISK STATS: / 14% of 33G, /dev 0% of 956M, /dev/shm 1% of 966M, /run 1% of 966M, /sys/fs/cgroup 0% of 966M, /boot 34% of 521M,; Warning /boot has 34% of utilization or 175M of 521M,
#
# [eddimas@dhcppc10 ~]$ ./check_disk.sh -l eddimas -H 192.168.1.74 -w 15 -c 30
# CRITICAL. DISK STATS: / 14% of 33G, /dev 0% of 956M, /dev/shm 1% of 966M, /run 1% of 966M, /sys/fs/cgroup 0% of 966M, /boot 34% of 521M,; Critical /boot has 34% of utilization or 175M of 521M,
#
# [eddimas@centos7 ~]$ ./check_disk.sh -l eddimas -H 192.168.1.74 -w 10 -c 30
# CRITICAL. DISK STATS: / 14% of 33G, /dev 0% of 956M, /dev/shm 1% of 966M, /run 1% of 966M, /sys/fs/cgroup 0% of 966M, /boot 34% of 521M,; Warning / has 14% of utilization or 4.3G of 33G,; Critical /boot has 34% of utilization or 175M of 521M,
#
##########################################################
exec 2>&1
j=0; ok=0
warn=0; crit=0
COMMAND='/bin/df -PH'
TEMP_FILE="/tmp/df.$RANDOM.log"

## Help funcion
help() {
cat << END
Usage :
        check_disk.sh -l [STRING] d [STRING] -H [STRING] -w [VALUE] -c [VALUE]

        OPTION          DESCRIPTION
        ----------------------------------
        -h              Help
        -l [STRING]      Remote user
        -d [STRING]      /
        -H [STRING]     Host name
        -w [VALUE]      Warning Threshold
        -c [VALUE]      Critical Threshold

        ----------------------------------
Note : [VALUE] must be an integer.
END
}

## Validating and setting the variables and the input args
if [ $# -ne 10 ]
then
        help;
        exit 3;
fi

while getopts "l:d:H:n:w:c:" OPT
do
        case $OPT in
        l) USERNAME="$OPTARG" ;;
        d) DISK="$OPTARG" ;;
        H) HOSTNAME="$OPTARG" ;;
        w) WARN="$OPTARG" ;;
        c) CRIT="$OPTARG" ;;
        *) help ;;
        esac
done
## Sending the ssh request command and store the result into local log file
SSH_COMMAND=`ssh -o StrictHostKeyChecking=no -i /home/nagios/.ssh/id_rsa -l $USERNAME $HOSTNAME -C $COMMAND`
#SSH_COMMAND="`ssh -i /home/egnytemonitor/.ssh/id_rsa -l $USERNAME $HOSTNAME -C $COMMAND`"
echo "$SSH_COMMAND"  > $TEMP_FILE.tmp
#echo "`cat $TEMP_FILE.tmp |head -n 2 |tail -1 | grep -v Used`" > $TEMP_FILE
echo "`cat $TEMP_FILE.tmp | grep $DISK`" > $TEMP_FILE
#EQP_FS="`cat $TEMP_FILE |head -n 2 |tail -1 | grep -v Used | wc -l`"  # determine how many FS are in the server
EQP_FS="`cat $TEMP_FILE | grep $DISK | wc -l`"  # determine how many FS are in the server


FILE=$TEMP_FILE                 # read $file using file descriptors
exec 3<&0                       # save current stdin
exec 0<"$FILE"                  # change it to read from file.

  while read LINE; do           # use $LINE variable to process each line of file
      j=$((j+1))
                        FULL[$j]=`echo $LINE | awk '{print $2}'`
                        USED[$j]=`echo $LINE | awk '{print $3}'`
                        FREE[$j]=`echo $LINE | awk '{print $4}'`
                        FSNAME[$j]=`echo $LINE | awk '{print $6}'`
                        PERCENT[$j]=`echo $LINE | awk '{print $5}' | sed 's/[%]//g'`
  done
exec 3<&0
rm $TEMP_FILE.tmp $TEMP_FILE

## According with the number of FS determine if the traceholds are reached (one by one)
for (( i=1; i<=$EQP_FS; i++ )); do
        if [ "${PERCENT[$i]}" -lt "${WARN}" ]; then
                ok=$((ok+1))
        elif [ "${PERCENT[$i]}" -eq "${WARN}" -o "${PERCENT[$i]}" -gt "${WARN}" -a "${PERCENT[$i]}" -lt "${CRIT}" ]; then
                warn=$((warn+1))
                WARN_DISKS[$warn]="${FSNAME[$i]} has ${PERCENT[$i]}% of utilization or ${USED[$i]} of ${FULL[$i]},"
        elif [ "${PERCENT[$i]}" -eq "${CRIT}" -o "${PERCENT[$i]}" -gt "${CRIT}" ]; then
                crit=$((crit+1))
                CRIT_DISKS[$crit]="${FSNAME[$i]} has ${PERCENT[$i]}% of utilization or ${USED[$i]} of ${FULL[$i]},"
        fi
done

## Set the data to show in the nagios service status
for (( i=1; i<=$EQP_FS; i++ )); do
        DATA[$i]="${FSNAME[$i]} ${PERCENT[$i]}% of ${FULL[$i]},"
        perf[$i]="${FSNAME[$i]}=${PERCENT[$i]}%;${WARN};${CRIT};0;;"
done

## Just validate and adjust the nagios output
if [ "$ok" -eq "$EQP_FS" -a "$warn" -eq 0 -a "$crit" -eq 0 ]; then
    echo "OK. DISK STATS: ${DATA[@]}| ${perf[@]}"
    exit 0
  elif [ "$warn" -gt 0 -a "$crit" -eq 0 ]; then
    echo "WARNING. DISK STATS: ${DATA[@]}_ Warning ${WARN_DISKS[@]}| ${perf[@]}"
    exit 1
  elif [ "$crit" -gt 0 ]; then
      #Validate if the Warning array is empty if so remove the Warning leyend
      if [ ${#WARN_DISKS[@]} -eq 0 ]; then
          echo "CRITICAL. DISK STATS: ${DATA[@]}_ Critical ${CRIT_DISKS[@]}| ${perf[@]}"
          exit 2
      else
          echo "CRITICAL. DISK STATS: ${DATA[@]}_ Warning ${WARN_DISKS[@]}_ Critical ${CRIT_DISKS[@]}| ${perf[@]}"
          exit 2
      fi
else
      echo "Unknown"
      exit 3
fi