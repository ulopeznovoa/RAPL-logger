
FREQ=0.1 #Seconds between each sample of RAPL registers

#Prepare logfiles
TIMESTAMP=`date +%s`
CORE_LOG=log+core+$TIMESTAMP
PKG_LOG=log+pkg+$TIMESTAMP
touch /tmp/$CORE_LOG
touch /tmp/$PKG_LOG
echo 'LOGFILES: '$CORE_LOG,$PKG_LOG

#Launch app and get first RAPL read 
echo $1 $2 $3 $4 $5 $6 $7 

CORE_READ=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/intel-rapl\:0\:0/energy_uj`
echo $CORE_READ >> /tmp/$CORE_LOG
PKG_READ=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/energy_uj`
echo $PKG_READ >> /tmp/$PKG_LOG

eval $1 $2 $3 $4 $5 $6 $7 & 
PROC_ID=$!

#Collect RAPL measures while app is running
while kill -0 "$PROC_ID" >/dev/null 2>&1; do
    CORE_READ=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/intel-rapl\:0\:0/energy_uj`
    echo $CORE_READ >> /tmp/$CORE_LOG
    PKG_READ=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/energy_uj`
    echo $PKG_READ >> /tmp/$PKG_LOG
    sleep $FREQ
done

echo "PROCESS TERMINATED"

#Compute energy consumption for Core
PREVIOUS=`head /tmp/$CORE_LOG -n 1`
OVERFLOWS=0

while read line; do 
    CURRENT=$line; 
    if [ "$CURRENT" -lt "$PREVIOUS" ]; then
 	OVERFLOWS=$(($OVERFLOWS+1)) 
    fi 
    PREVIOUS=$CURRENT
done < "/tmp/$CORE_LOG"

MAX_CORE_READ=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/intel-rapl\:0\:0/max_energy_range_uj`
FIRST_READ=`head /tmp/$CORE_LOG -n 1`
LAST_READ=`tail /tmp/$CORE_LOG -n 1`

TOTAL_POWER=0
if [ "$OVERFLOWS" -gt 0 ]; then
    TOTAL_POWER=$(((MAX_CORE_READ-FIRST_READ)+(MAX_CORE_READ*OVERFLOWS)+(LAST_READ)))
else
    TOTAL_POWER=$((LAST_READ-FIRST_READ))
fi
echo 'Energy consumption of Core (j): '$TOTAL_POWER

#Compute energy consumption for Package
PREVIOUS=`head /tmp/$PKG_LOG -n 1`
OVERFLOWS=0

while read line; do 
    CURRENT=$line; 
    if [ "$CURRENT" -lt "$PREVIOUS" ]; then
 	OVERFLOWS=$(($OVERFLOWS+1)) 
    fi 
    PREVIOUS=$CURRENT
done < "/tmp/$PKG_LOG"

MAX_CORE_READ=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/max_energy_range_uj`
FIRST_READ=`head /tmp/$PKG_LOG -n 1`
LAST_READ=`tail /tmp/$PKG_LOG -n 1`

TOTAL_POWER=0
if [ "$OVERFLOWS" -gt 0 ]; then
    TOTAL_POWER=$(((MAX_CORE_READ-FIRST_READ)+(MAX_CORE_READ*OVERFLOWS)+(LAST_READ)))
else
    TOTAL_POWER=$((LAST_READ-FIRST_READ))
fi
echo 'Energy consumption of Package (j): '$TOTAL_POWER




