PKG_A=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/energy_uj`
CORE_A=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/intel-rapl\:0\:0/energy_uj`
TIME_A=`date +%s%3N`

echo $1 $2 $3 $4 $5 $6 $7 
eval $1 $2 $3 $4 $5 $6 $7 

PKG_B=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/energy_uj`
CORE_B=`cat /sys/class/powercap/intel-rapl/intel-rapl\:0/intel-rapl\:0\:0/energy_uj`
TIME_B=`date +%s%3N`

PKG_DELTA=$((PKG_B-PKG_A))
CORE_DELTA=$((CORE_B-CORE_A))
TIME_DELTA=$((TIME_B-TIME_A))

PKG_JOULES=`bc -l <<< $PKG_DELTA/1000000`
CORE_JOULES=`bc -l <<< $CORE_DELTA/1000000`
TIME_SECONDS=`bc -l <<< $TIME_DELTA/1000`

PKG_WATTS=`bc -l <<< $PKG_JOULES/$TIME_SECONDS`
CORE_WATTS=`bc -l <<< $CORE_JOULES/$TIME_SECONDS`

echo "- - - - - - R A P L r e a d e r - - - - - -"
printf "Time taken (s): %8.4f\n" "$TIME_SECONDS"

if [ $PKG_DELTA -lt 0 ]; then
 echo "WARNING: Negative value for package delta" 
fi

if [ $CORE_DELTA -lt 0 ]; then
 echo "WARNING: Negative value for core delta" 
fi

printf "Package energy consumption (j): %8.4f\n" "$PKG_JOULES"
printf "Core energy consumption (j): %8.4f\n" "$CORE_JOULES"

printf "Package avg. power consumption (W): %8.4f\n" "$PKG_WATTS"
printf "Core avg. power consumption (W): %8.4f\n" "$CORE_WATTS"
