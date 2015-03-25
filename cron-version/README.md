# Cron Version (gps2hotspot)

This is a lite version set to be run periodically by cron and does not perform a infinite while loop.
It here is an example cron job and shell script wrapper that's pretty verbose and giving you greater
control options over it's execution.

## Example cron job in cron.d

```
PATH=/sbin:/usr/sbin:/bin:/usr/bin
*/2 * * * * root if [[ -z $( ps aux | grep -F "start.sh" | grep -v 'grep') ]]; then /bin/sh -c /root/gps/start.sh >> /root/script-log; fi
```


## Example cron job bash script wrapper

```
#!/bin/bash
# checking if perl script is already running

# program folder location
dir='/root/gps/'

chk_proc() {
  proc=""
  proc=$( ps aux | grep -F -i "gpshs.pl" | grep -v "grep" )
}

cd $dir
echo '*=----------------------------------------=*'
echo "[+] the working directory is now /root/gps/"

chk_proc
killall wpa_supplicant

if [ -z "$proc" ]; then

    echo "[+] kicking off the ghs binary..."
    timeout 60 ./gpshs.pl /dev/ttyAMA0 9600 wlan0 box01 >> /root/performance
    if [ $? -ne 0 ]; then
         echo "[!] cron failed to run the perl binary"
         killall wpa_supplicant
         ifconfig wlan0 down
         echo "[+] completed with errors..."
         echo '*=----------------------------------------=*'
         exit
    fi

    echo "[+] completed successfully..."
    echo '*=----------------------------------------=*'
    exit

 else

    sleep 20
    pkill gpshs
    killall wpa_supplicant
    ifconfig wlan0 down
    echo "[+] completed with errors..."
    echo '*=----------------------------------------=*'
    exit

fi
```

