# RAPL logger

A tool to monitor the energy consumption of an application running in an Intel-based system. It reads the RAPL information available in the */sys/class/powercap*. Unlike other ways of reading RAPL registers (like using *perf*), it doesn't require the user to have sudo privileges.

Usage: ./rapl_logger \<your-app\> \<params-of-your-app\>

Edit the following lines of the script file to configure RAPL logger:
- 42: FREQ=0.1 #Seconds between each sample of RAPL registers. 0.1 Seconds == 10 Hz
- 43: PACKAGES=1 #Number of sockets to be analysed. Currently 1 or 2 supported.
- 44: REMOVE_LOGFILES=0 #RAPL logger creates some temp files in /tmp. Remove these after execution Y(1) or N(0).
