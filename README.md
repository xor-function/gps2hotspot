# gps2hotspot 

This Perl script is another gps logger with a twist.
It depends on a mobile hotspot, the android hotspot 
to be runing an FTP server.

The FTP server is compatible with the android app 
ES File Explorer.

## Required Perl Modules

For this Perl script to work it requires
the following modules to be installed in the 
specified order.

be sure to install libdevice-serialport-perl first
otherwise when installing GPS::NMEA through
cpanminus it will attempt to aquire the module itself
through cpan.

cpan's version of the module will fail to install.

## TODO 

Create setup shell script.



xor-function = null
@ nightowlconsulting.com
