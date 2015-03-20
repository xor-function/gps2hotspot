#!/bin/bash
#
# this script is part of gps2hotspot
# it performs the initial configuration
#
#-------------=[ edit Block ]=-------------#
# gps device
GPSDEV='/dev/ttyAMA0'
#------------------------------------------#
# buad per sercond (bps)
BAUD='9600'
#--------------=[ end block ]=-------------#
#
#
###################################################################
banner() {
echo '------------------------------------------------------------'
echo '          __________  _____    ___                          '
echo '         / ____/ __ \/ ___/   |__ \                         '
echo '        / / __/ /_/ /\__ \    __/ /                         '
echo '       / /_/ / ____/___/ /   / __/                          '
echo '       \____/_/    /____/_  /____/           __             '
echo '           / /_  ____  / /__________  ____  / /_            '
echo '          / __ \/ __ \/ __/ ___/ __ \/ __ \/ __/            '
echo '         / / / / /_/ / /_(__  ) /_/ / /_/ / /_              '
echo '        /_/ /_/\____/\__/____/ .___/\____/\__/              '
echo '                            /_/                             '
echo '                                                            '
echo '    More like "gps logs uploaded to a hotspot via ftp"      '
echo '    but thats not a name, maybe a weird one...              '
echo '                                                            '
echo '------------------------------------------------------------'
}

use() {
cat << EOF
xor-function == null
@nightowlconsulting.com

setup.sh:
A script that configures the gps device and log upload to a
specified hotspot.

the set defaults for gps device are /dev/ttyAMA0 at 9600 bps
to change this edit the start of this script.

usage:
./setup.sh -n my_hotspot -p hotspot-pass

options:
   -n   name of your hotspot (ssid)
   -p   wpa2 password on your hotspot

Your hotspot must have wpa2 encryption enabled.
EOF

}

warning() {
echo "!!!----WARNING-----------WARNING---------WARNING---------!!!"
echo "                                                            "
echo " This will start gps2hotspot on boot dedicating your        "
echo " wireless adapter for this only.                            "
echo "                                                            "
echo "           ftp user is anon                                 "
echo "           ftp pass is anon                                 "
echo "           ftp port is 4444                                 "
echo "                                                            "
echo " to change these you will have to edit the                  "
echo " perl script.                                               "
echo "                                                            "
echo "!!!----WARNING-----------WARNING---------WARNING---------!!!"
echo "                                                            "
echo "     The GPS device is set to /dev/ttyAMA0 at 9600 bps      "
echo "                                                            "
echo "     to change this edit the top of this script             "
echo "     or the cron job generated at                           "
echo "     /etc/cron.d/gps2hotspot                                "
echo "                                                            "
echo "!!!----WARNING-----------WARNING---------WARNING---------!!!"
}

tstamp() {
  date +"%F"_"%H":"%M"
}


get_aptpkg() {

 tpkg=$(dpkg -s $1 | grep "install ok install")
 if [ -z "$tpkg" ]; then

       echo "[!] package not found, fetching...."

       if [ -z $aptup ]; then
           # rm -rf /var/lib/apt/lists/*
           apt-get update
           aptup=1
       fi

       echo "[*] installing $1"
       if ! apt-get -y install $1; then
          echo "[!] APT failed to install "$1", are your repos working? Exiting..."
          exit 1
       fi
    else
       echo "[+] $1 is already installed"
  fi

}

get_permission() {
  while true; do
     read -e answer
     case $answer in
          [Yy] ) break;;
          [Yy][eE][sS] ) break;;
          [nN] ) printf "\nExiting Now \n"; exit;;
          [Nn][oO] ) printf "\nExiting Now \n"; exit;;
            *  ) printf "\nNot Valid, Answer y or n\n";;
     esac
  done
}

# func requires args: username
chk_usr() {
   if [ "$(whoami)" != "$1" ]; then
       echo "[!] you need to be root, exiting..."
       exit
   fi
}

chk_tubes() {
   echo "[*] Checking your tubes..."
   if ! ping -c 1 google.com > /dev/null 2>&1  ; then
      if ! ping -c 1 yahoo.com > /dev/null 2>&1  ; then
         if ! ping -c 1 bing.com > /dev/null 2>&1 ; then
             clear
             echo "[!] Do you have an internet connection???"
             exit 2
         fi
      fi
   fi
   echo "[+] tubes working..."
}

# requires arguments
make_runlog() {
   if [ ! -e /var/log/htspt ]; then
     touch /var/log/htspt
   fi
   printf "\ngps2hotspot setup script run on\n"$(tstamp)"\n" >> /var/log/htspt
}

# you may have to tweak this if your wireless device doesn't start with wlan, for example ath0
chk_wlan() {
   if ! WLAN=$(iwconfig 2>/dev/null | grep -o "^\w*"); then
        echo "[!] wlan device not detected, connot continue..."
        exit
   fi
}

chk_usr root
chk_tubes
chk_wlan

# Getting options and setting variables
if [[ $# -gt 4 || $# -lt 4 ]]; then banner; use; exit; fi

while getopts :hn:hp: option; do
  case "${option}" in
     n ) SSID="${OPTARG}";;
     p ) PASS="${OPTARG}";;
     * ) banner; use; exit;;
   esac
done

if ! wlan=$(iwconfig 2>/dev/null | grep -o "^\w*"); then   # you may have to tweak this if your wireless device doesn't start with wlan
     printf "\nfailed to set wlan variable, wlan device not detected, maybe it's ath0? $(tstamp) \n\n" >> /var/log/tracking-log
     exit
fi


echo "[!] your current date is $(tstamp)"
echo "    attempting to sync with internet time"
echo "    as cpan/curl depends on correct time"
service ntp stop
ntpd -gq
if [ $? -ne 0 ]; then
    echo "[!] Something went wrong syncing time, cannot contine."
    exit
fi
service ntp start


if [ -e /var/log/htspt ]; then

      echo "[!] You have run setup before, to continue"
      echo "      the /root/gps folder along with any logs"
      echo "      will be deleted."
      echo "   do you wish to continue? (yes/no)"
      get_permission

      rm -rf /root/gps

fi

clear
banner
warning
echo "do you wish to continue? (yes/no)"
get_permission
get_aptpkg perl

# have to install the deb package version of the Device::SerialPort perl module since
# installing directly from cpan fails.

get_aptpkg libdevice-serialport-perl

# enabling GPIO UART for use by TTL Serial GPS device
echo "[*] Disabling the serial console, freeing up /dev/ttyAMA0 to use with a GPS device"
if [ -e /boot/cmdline.txt ]; then
        cat > /boot/cmdline.txt <<-EOL
        dwc_otg.lpm_enable=0 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait
        EOL
fi

if [ ! -e /var/log/htspt ]; then

    if [ -e /etc/inittab ]; then
        sed -i 's/T0:23:respawn:\/sbin\/getty -L ttyAMA0/#T0:23:respawn:\/sbin\/getty -L ttyAMA0/' /etc/inittab
    fi

    # Get Perl Script dependancies
    echo "[*] getting cpanminus: Perl module manager"
    curl -L https://cpanmin.us | perl - --sudo App::cpanminus
    if [ $? -ne 0 ] ; then
        echo ""
        echo "[!] Something went wrong fetching cpanminus, cannot continue"
        exit
    fi

    echo "[*] getting the GPS::NMEA perl module"
    cpanm -i GPS::NMEA

    echo "[*] getting the Net::FTP perl module"
    cpanm -i Net::FTP

    echo "[+] done configuring Perl"

fi

echo "[*] setting up hotspot settings"
wpa_passphrase "$SSID" "$PASS" > wpa_supplicant.conf

echo "[+] coping files to /root/gps/ folder"
mkdir /root/gps/
cp {gps2hotspot.pl,wpa_supplicant.conf} /root/gps/

echo "[+] setting up dhclient settings..."
# here the dhclient is set to timeout quickly to prevent hangups
cat > /etc/dhcp/dhclient.conf <<-EOL
# Configuration file for /sbin/dhclient, which is included in Debian's
# dhcp3-client package.
# the file has been modified to work better for gps2hotspot
backoff-cutoff 1;
initial-interval 1;
select-timeout 0;
timeout 25;
option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;
request subnet-mask, broadcast-address, time-offset, routers,
        domain-name, domain-name-servers, domain-search, host-name,
        netbios-name-servers, netbios-scope, interface-mtu,
        rfc3442-classless-static-routes, ntp-servers,
        dhcp6.domain-search, dhcp6.fqdn,
        dhcp6.name-servers, dhcp6.sntp-servers;
EOL

echo "[*] generating cron job..."

cat > /etc/cron.d/gps2hotspot <<-EOL
PATH=/sbin:/usr/sbin:/bin:/usr/bin
@reboot root cd /root/gps && /usr/bin/perl ./gps2hotspot.pl ${GPSDEV} ${BAUD} ${wlan} ${SSID} > /var/log/gps2hotspot.log
EOL

make_runlog
echo "[+] Done setting up..."
echo "[+] Disconnect any ethernet connection and reboot to get up and running."

exit

