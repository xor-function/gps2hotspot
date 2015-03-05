# gps2hotspot 

This Perl script is another gps logger with a twist.
It dumps coordinate logs only to a specified mobile hotspot 
via an FTP server.

The FTP server used successfully is the android app 
ES File Explorer.

## Get it working

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

### * dhclient
To prevent dhclient from hanging up too long use a dhclient.conf
file that specifies a timeout limt.

for more details information use man
```
pi@raspberry:~$ man man dhclient.conf
```

### * FTP

Set the variables in gps2hotspot.pl file
under FTP session.

input your user/pass and port number.

If you do not specify an IP for the ftp 
server, it will use the default gateway.


## TODO 

Create setup shell script, that will automate
the steps under "Get it working".



xor-function = null
@ nightowlconsulting.com
