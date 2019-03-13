#!/bin/bash

# This function will calculate the Joules for each RAPL tag
# Arguments: Logfile path, RAPL TAG
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

    TOTAL_UJ=0
    if [ "$OVERFLOWS" -gt 0 ]; then
        TOTAL_UJ=$(((MAX_CORE_READ-FIRST_READ)+(MAX_CORE_READ*(OVERFLOWS-1))+(LAST_READ)))
    else
        TOTAL_UJ=$((LAST_READ-FIRST_READ))
    fi

    JOULES=`bc -l <<< $TOTAL_UJ/1000000`
    echo $JOULES
}

# CONFIGURE HERE RAPL-LOGGER
FREQ=0.1 #Seconds between each sample of RAPL registers
PACKAGES=1 #Number of sockets to be analysed. Currently 1 or 2 supported
RAPL_TAG_0=intel-rapl\:0
RAPL_TAG_1=intel-rapl\:0/intel-rapl\:0\:0
RAPL_TAG_2=intel-rapl\:1
RAPL_TAG_3=intel-rapl\:1/intel-rapl\:1\:0

#Prepare logfiles
TIMESTAMP=`date +%s`
TAG0_LOG=rapllog+$TIMESTAMP+0
TAG1_LOG=rapllog+$TIMESTAMP+1
touch /tmp/$TAG0_LOG
touch /tmp/$TAG1_LOG

if [ "$PACKAGES" -eq 2 ]; then
    TAG2_LOG=rapllog+$TIMESTAMP+2
    TAG3_LOG=rapllog+$TIMESTAMP+3
    touch /tmp/$TAG2_LOG
    touch /tmp/$TAG3_LOG
    echo '** RAPL-logger - 2 packages - Logfiles 0-3: /tmp/rapllog+'$TIMESTAMP
else
    echo '** RAPL-logger - 1 package - Logfiles 0-1: /tmp/rapllog+'$TIMESTAMP
fi

#Launch app and get first RAPL read 
echo "${@}"

TAG0_READ=`cat /sys/class/powercap/intel-rapl/$RAPL_TAG_0/energy_uj`
echo $TAG0_READ >> /tmp/$TAG0_LOG
TAG1_READ=`cat /sys/class/powercap/intel-rapl/$RAPL_TAG_1/energy_uj`
echo $TAG1_READ >> /tmp/$TAG1_LOG

if [ "$PACKAGES" -eq 2 ]; then
    TAG0_READ=`cat /sys/class/powercap/intel-rapl/$RAPL_TAG_2/energy_uj`
    echo $TAG2_READ >> /tmp/$TAG2_LOG
    TAG1_READ=`cat /sys/class/powercap/intel-rapl/$RAPL_TAG_3/energy_uj`
    echo $TAG3_READ >> /tmp/$TAG3_LOG
fi

TIME_START=`date +%s%3N`

eval "${@}" &
PROC_ID=$!

#Collect RAPL measures while app is running
if [ "$PACKAGES" -eq 1 ]; then #Loop for 1 package, 2 readings

while kill -0 "$PROC_ID" >/dev/null 2>&1; do
    TAG0_READ=`cat /sys/class/powercap/intel-rapl/$RAPL_TAG_0/energy_uj`
    echo $TAG0_READ >> /tmp/$TAG0_LOG
    TAG1_READ=`cat /sys/class/powercap/intel-rapl/$RAPL_TAG_1/energy_uj`
    echo $TAG1_READ >> /tmp/$TAG1_LOG
    sleep $FREQ
done

else #Loop for 2 packages, 4 readings

while kill -0 "$PROC_ID" >/dev/null 2>&1; do
    TAG0_READ=`cat /sys/class/powercap/intel-rapl/$RAPL_TAG_0/energy_uj`
    echo $TAG0_READ >> /tmp/$TAG0_LOG
    TAG1_READ=`cat /sys/class/powercap/intel-rapl/$RAPL_TAG_1/energy_uj`
    echo $TAG1_READ >> /tmp/$TAG1_LOG

    TAG2_READ=`cat /sys/class/powercap/intel-rapl/$RAPL_TAG_2/energy_uj`
    echo $TAG2_READ >> /tmp/$TAG2_LOG
    TAG1_READ=`cat /sys/class/powercap/intel-rapl/$RAPL_TAG_3/energy_uj`
    echo $TAG3_READ >> /tmp/$TAG3_LOG

    sleep $FREQ
done

fi

TIME_END=`date +%s%3N`
echo "** RAPL-logger - Process terminated, computing results"

#Compute energy and avg. power consumption from logs

TIME_DELTA=$((TIME_END-TIME_START))
TIME_SECONDS=`bc -l <<< $TIME_DELTA/1000`

TAG0_JOULES=$(compute_energy_consumption $TAG0_LOG $RAPL_TAG_0)
TAG0_WATTS=`bc -l <<< $TAG0_JOULES/$TIME_SECONDS`
printf "TAG0 energy consumption (j): %8.4f\n" "$TAG0_JOULES"
printf "TAG0 avg. power consumption (W): %8.4f\n" "$TAG0_WATTS"

TAG1_JOULES=$(compute_energy_consumption $TAG1_LOG $RAPL_TAG_1)
TAG1_WATTS=`bc -l <<< $TAG1_JOULES/$TIME_SECONDS`
printf "TAG1 energy consumption (j): %8.4f\n" "$TAG1_JOULES"
printf "TAG1 avg. power consumption (W): %8.4f\n" "$TAG1_WATTS"

if [ "$PACKAGES" -eq 2 ]; then #Print additional value for 2nd package

    TAG2_JOULES=$(compute_energy_consumption $TAG2_LOG $RAPL_TAG_2)
    TAG2_WATTS=`bc -l <<< $TAG2_JOULES/$TIME_SECONDS`
    printf "TAG2 energy consumption (j): %8.4f\n" "$TAG2_JOULES"
    printf "TAG2 avg. power consumption (W): %8.4f\n" "$TAG2_WATTS"

    TAG3_JOULES=$(compute_energy_consumption $TAG3_LOG $RAPL_TAG_3)
    TAG3_WATTS=`bc -l <<< $TAG3_JOULES/$TIME_SECONDS`
    printf "TAG3 energy consumption (j): %8.4f\n" "$TAG3_JOULES"
    printf "TAG3 avg. power consumption (W): %8.4f\n" "$TAG3_WATTS"

fi

