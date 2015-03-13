#!/usr/bin/perl 
#
# gps2hotspot
# license BSD 3 
#

use strict;
use warnings;
use Net::FTP;
use GPS::NMEA;

##########|[variables]|#########


#------------------=[ FTP edit block ]=------------------------
my $ftp_host_ip; # = 'x.x.x.x';  # only use this if you have a diff ftp server other than your phone
my $ftp_port     = '4444';
my $ftp_usr      = 'anon';
my $ftp_pass     = 'anon';
#------------------------=[ end ]=-----------------------------

#---------=[ gps device log location edit block  ]=------------
my $log     = '/root/location-data';
#------------------------=[ end ]=-----------------------------


# do not modify the variables below unless you 
# know what your are doing.

# general from FTP GPS and wlan
my $gps;
my $device;
my $bauds;
my $ftp;
my $ftp_host;
my $ssid;
my $aps;
my $wlan;
# configuration files
my $wpasup      = 'wpa_supplicant.conf';
my $dhclient    = 'dhclient.conf';
# permission variables 
my $user        = $>;
# loop control variables
my $counter     = '0';
# GPS format conversion variables
my $latones;
my $lonones;
my $lattenths;
my $lontenths;
my $latpol;
my $lonpol;
my $latdeccoor;
my $londeccoor;
my $latdiv;
my $latdecraw;
my $latdec;
my $londiv;
my $londecraw;
my $londec;
# For logs/General
my $time;
my $proc;
# Networking connection variables
my $ping;
my $net;

#------------------------------------------
#----------=[ subroutines ]=---------------

sub chk_exist{

    my $conf = $_[0];
    print "[*] checking for config file $conf\n";  

    if (open(my $fhandle, '<', $conf )) {
          close $fhandle;
          print "[+] config file $conf found.\n";
       }else { 
            die "[!] $conf not found, cannot continue.\n";
     }   
    undef $conf
}

sub unset_wlan{
    system("dhclient", "-r", "$wlan");
    system("ifconfig", "$wlan", "down");
}

sub set_wlan{
    system("ifconfig", "$wlan", "up");
}

sub scan_wlan{

   undef $aps;
   unless ($aps = qx(iwlist $wlan scan)) {

            print "[!] ap scan failed... retrying in 5 secs\n";
            system("ifconfig", "$wlan", "up" );
            sleep(7);
   }
   else {
       $aps = qx(iwlist $wlan scan) || die "[!] retry failed, does this interface exist?\n";
   }


}

sub end_proc{

     # checking if theres an wpa_supplicant orphan proc, if then kill it. 
     undef $proc;
     $proc = qx(ps aux);

     if ( $proc =~ /wpa_supplicant / ) {
          print "[!] killing wpa_supplicant\n";
          system("killall", "wpa_supplicant");   
     }

}

# subroutine handling GPS device data and coordinate format conversion from DMM to DDD
sub log_gps{

  undef $gps;
  print "[+] GPS device set to $device with a speed of $bauds\n";
  $gps = new GPS::NMEA(  'Port'      => $device,
                          'Baud'      => $bauds,
                     );

  while( $counter < 1 ) {

        my($ns,$lat,$ew,$lon) = $gps->get_position;

        # just in case        
        chomp($lon); chomp($lat); chomp($ns); chomp($ew);

        my ($latdeg, $latmin) = split("\\.", $lat);
        my ($londeg, $lonmin) = split("\\.", $lon);

        # decimal calculation
        # Splitting up decimals into places

        $latones   = substr($latmin, 0, 2);
        $lonones   = substr($lonmin, 0, 2);

        $lattenths = substr($latmin, 2, 6);
        $lontenths = substr($lonmin, 2, 6);

        # doing some math to convert the minutes to decimals

        $latdiv    = join(".", $latones, $lattenths);
        $latdecraw = $latdiv / 60;
        $latdec    = substr($latdecraw, 2, 5);

        $londiv    = join(".", $lonones, $lontenths);
        $londecraw = $londiv / 60;
        $londec    = substr($londecraw, 2, 5);

        # the calculations above are to decimal degrees and are stored in 
        # the latdec / londec variables 

        $latdeccoor = join(".", $latdeg, $latdec);
        $londeccoor = join(".", $londeg, $londec);

        # calculating polarity
        # positive will be blank since in Google maps only negative is visible

        if ($ns eq "N") { $latpol = ' '; }
        if ($ns eq "S") { $latpol = '-'; }
        
        if ($ew eq "E") { $lonpol = ' '; }
        if ($ew eq "W") { $lonpol = '-'; }

        open(my $fhandler, '+>>', "$log" ) or die "Could not open file $!";
        print $fhandler "[DMM: $ns,$lat,$ew,$lon ][DDD:$latpol$latdeccoor,$lonpol$londeccoor ]\n";
        close $fhandler;
        $counter += 1;
        print "[+] dumping GPS coordinates to $log...\n";
   }
   $counter = 0;

}

# handles uploading of gps coordinate log file via FTP
sub upload_logs{

   if ( $ftp = Net::FTP->new( "$ftp_host",
                    Port     => $ftp_port,
                    timeout  => 20,
                    Debug    => 0,) )  {

           $ftp->login("$ftp_usr","$ftp_pass")
                      or print "[!] cannot login ", $ftp->message;

           $ftp->put("$log")
                 or print "[!] cannot upload file", $ftp->message;

           print "[+] uploaded file!\n";

    } else{ print "[!] cannot connect to $ftp_host\n"; }

}

sub wlan_connect_upload{

  if ( system("wpa_supplicant", "-D", "nl80211,wext", "-i", "$wlan", "-c", "$wpasup", "-B") == 0 ) {

       # force perl script to wait until dhclient is done 
       $net = system("dhclient", "$wlan");

       undef $ftp_host;

       if ( not defined($ftp_host_ip)) {
               $ftp_host = qx(netstat -r | grep ^default | awk '{print \$2}');
        } else{ $ftp_host = $ftp_host_ip;}

       if ("$ftp_host" =~ /[0-9]/ ) 
       {
            print "[+] got gateway $ftp_host\n";
            $ping = qx(ping -c 2 $ftp_host);
            if ( "$ping" =~ /ttl=/ ) 
             {
                 print "[+] associated to hotspot\n";
                 print "[+] gateway is alive\n";
                 print "[*] attempting to upload logs via FTP\n";
                 upload_logs();
             } else { print "[!] link cannot be established!\n"; }
             
       } else { print "[!] gateway could not be established\n"; }

   } else { print"[!] could not associate to hotspot at $time\n"; }

}

#---------------------------------------
#------------=[ main ]=-----------------

# check if user is root
if ( $user ne 0 ) { 
   die "You must run this as root \n";
}

# test arguments 
if ( @ARGV < 4 || @ARGV > 4 ) {
   die "Usage: gps2hotspot.pl [gps device] [baud rate] [wlan iface] [hotspot-name (ssid)]\n";
}

# set arguments to specific variables

if (not defined($ARGV[0])) {
     die "[!] you need to specify a gps device as the first arg\n";
   }else { $device = $ARGV[0]; }

if (not defined($ARGV[1])) {
     die "[!] you need to specify the baud rate of the gps device as the second arg\n";
   }else { $bauds = $ARGV[1]; }

if (not defined($ARGV[2])) {
     die "[!] you need to specify the iface of an wireless adapter as the third arg\n";
   }else { $wlan = $ARGV[2]; }

if ( not defined($ARGV[3])) {
     die "[!] you need to specify a hotspotname (ssid) as the fourth arg\n";
   }else { $ssid = $ARGV[3]; }

# check if wpa_supplicant.conf exists 
chk_exist($wpasup);

if ( not defined($ftp_host)) {
  print "[!] since you have not assigned an ip to the ftp_host\n it will use the ip of the default gateway\n";
}

# check if dhclient.conf exists
# chk_exist($dhclient);

# Starting infinite loop
while (1) {

   print "[!] sleeping for 120 secs\n";
   sleep(120);

   $time = qx(date +"%D":"%r");
           chomp($time);
           $time =~ s/\r|\n//g;

   # get gps data and convert to DDD from DMM
   log_gps();

  # checking if theres an wpa_supplicant orphan proc, if then kill it. 
   end_proc();

  # starting code block for wireless ap search 
   print "[*] scanning for hotspot to upload coordinate log\n";

   set_wlan();
   scan_wlan();

   if ("$aps" =~ /$ssid/ ) {

        print "[+] found hotspot\n";
        print "[*] attempting association\n";
        
        wlan_connect_upload();
       
    } else{ print "[!] hotspot not detected...\n"; }

   unset_wlan();
   end_proc();

   print "[+] finished at $time\n";

}
