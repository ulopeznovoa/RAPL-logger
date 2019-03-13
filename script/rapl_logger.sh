#!/bin/bash

# This function will calculate the Joules for each RAPL tag
# Arguments: Logfile path, RAPL key
function compute_energy_consumption()
{
    PREVIOUS=`head /tmp/$1 -n 1`
    OVERFLOWS=0

    while read line; do 
        CURRENT=$line; 
        if [ "$CURRENT" -lt "$PREVIOUS" ]; then
 	    OVERFLOWS=$(($OVERFLOWS+1)) 
        fi 
        PREVIOUS=$CURRENT
    done < "/tmp/$1"

    MAX_CORE_READ=`cat /sys/class/powercap/intel-rapl/$2/max_energy_range_uj`
    FIRST_READ=`head /tmp/$1 -n 1`
    LAST_READ=`tail /tmp/$1 -n 1`

    TOTAL_POWER=0
    if [ "$OVERFLOWS" -gt 0 ]; then
        TOTAL_POWER=$(((MAX_CORE_READ-FIRST_READ)+(MAX_CORE_READ*(OVERFLOWS-1))+(LAST_READ)))
    else
        TOTAL_POWER=$((LAST_READ-FIRST_READ))
    fi

    JOULES=`bc -l <<< $TOTAL_POWER/1000000`
    echo $JOULES
}

FREQ=0.1 #Seconds between each sample of RAPL registers

#Prepare logfiles
TIMESTAMP=`date +%s`
CORE_LOG=log+core+$TIMESTAMP
PKG_LOG=log+pkg+$TIMESTAMP
touch /tmp/$CORE_LOG
touch /tmp/$PKG_LOG
echo 'LOGFILES: '$CORE_LOG,$PKG_LOG

#Launch app and get first RAPL read 
echo "${@}"

CORE_READ=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/intel-rapl\:0\:0/energy_uj`
echo $CORE_READ >> /tmp/$CORE_LOG
PKG_READ=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/energy_uj`
echo $PKG_READ >> /tmp/$PKG_LOG

TIME_START=`date +%s%3N`

eval "${@}" &
PROC_ID=$!

#Collect RAPL measures while app is running
while kill -0 "$PROC_ID" >/dev/null 2>&1; do
    CORE_READ=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/intel-rapl\:0\:0/energy_uj`
    echo $CORE_READ >> /tmp/$CORE_LOG
    PKG_READ=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/energy_uj`
    echo $PKG_READ >> /tmp/$PKG_LOG
    sleep $FREQ
done

TIME_END=`date +%s%3N`

echo "PROCESS TERMINATED"

#Compute energy and avg. power consumption from logs

TIME_DELTA=$((TIME_END-TIME_START))
TIME_SECONDS=`bc -l <<< $TIME_DELTA/1000`

CORE_JOULES=$(compute_energy_consumption $CORE_LOG intel-rapl\:0/intel-rapl\:0\:0)
CORE_WATTS=`bc -l <<< $CORE_JOULES/$TIME_SECONDS`
printf "Core energy consumption (j): %8.4f\n" "$CORE_JOULES"
printf "Core avg. power consumption (W): %8.4f\n" "$CORE_WATTS"

PKG_JOULES=$(compute_energy_consumption $PKG_LOG intel-rapl\:0)
PKG_WATTS=`bc -l <<< $PKG_JOULES/$TIME_SECONDS`
printf "Package energy consumption (j): %8.4f\n" "$PKG_JOULES"
printf "Package avg. power consumption (W): %8.4f\n" "$PKG_WATTS"

