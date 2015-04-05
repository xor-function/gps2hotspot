# gps2hotspot 

This Perl script is another gps logger with a twist.
It dumps coordinate logs only to a specified mobile hotspot 
via an FTP server.

The FTP server used successfully is the android app 
ES File Explorer.

The GPS coordinates are logged in two formats
* DMM
* DDD

The decimal degree format can be directly input into
a Google/Google maps search.

## Video

Shows the Perl script in action.

[![video on youtube here](http://img.youtube.com/vi/jD6MFCW56rU/hqdefault.jpg)](https://www.youtube.com/embed/jD6MFCW56rU?vq=hd720)

## Get it working

I have added a script to assist in making
setup faster.

```
usage:
./setup.sh -n my_hotspot -p hotspot-pass

options:
   -n   name of your hotspot (ssid)
   -p   wpa2 password on your hotspot
```
This should keep you from having to do the 
below manually.

Tailored for Debian based distros

### * Required Perl Modules

For this Perl script to work it requires
the following modules to be installed in the 
specified order.

Be sure to install libdevice-serialport-perl first

otherwise when installing GPS::NMEA through
cpanminus it will attempt to aquire the module itself
through cpan. this version of the module will 
fail to install.

### * wpa_supplicant
This script uses wpa_supplicant to manage wpa connections and 
requires a config file generated with wpa_passphrase with the
neccessary wpa credentials.

example:
```
pi@raspberry:~$ wpa_passphrase "hotspots-name" "hotspots-passwd" > wpa_supplicant.conf
```

Name it "wpa_supplicant.conf" and place it in the same dir
as the Perl script.

To connect to an open hotspot without encryption you must 
use a wpa_supplicant.conf that enables this

example:
```
network={
        ssid="your-hotspot"
        key_mgmt=NONE
}
```
for more details information use man
```
pi@raspberry:~$ man wpa_supplicant.conf
```

### * Arguments 

The arguments must be in the following order.
```
Usage: gps2hotspot.pl [gps device] [baud rate] [wlan iface] [hotspot-name (ssid)]
```

### * dhclient
To prevent dhclient from hanging up too long use a dhclient.conf
file that specifies a timeout limt.

for more details information use man
```
pi@raspberry:~$ man dhclient.conf
```

### * FTP

Set the variables in gps2hotspot.pl file
under FTP session.

input your user/pass and port number.

If you do not specify an IP for the ftp 
server, it will use the default gateway.

The set defaults are
* FTP user anon
* FTP pass anon
* FTP port 4444


xor-function = null
@ nightowlconsulting.com
