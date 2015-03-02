#!/usr/bin/perl 

use strict;
use warnings;
use Net::FTP;
use GPS::NMEA;

##########|[variables]|#########


# GPS Device variables  
my $gps;
my $device;
#------=[ gps device var edit block  ]=----------
my $bauds    = '9600';
my $log      = 'location-data';
#-----------------=[ end ]=-----------------------


# Wireless access point variables
#--------=[ Hotspot name edit block ]=-----------
my $ssid     = 'hotspot-name';
#----------------=[ end ]=-----------------------
my $aps;
my $wlan;


# FTP session variables
my $ftp; 
#------------=[ FTP var edit block ]=------------
my $ftp_host = '192.168.43.1';
my $ftp_port = '8888';
my $ftp_usr  = 'anon';
my $ftp_pass = 'anon';
#-------------------=[ end ]=--------------------


# configuration files
my $wpasup   = 'wpa_supplicant.conf';
my $dhclient = 'dhclient.conf';
# permission variables 
my $user     = $>;
# loop control variables
my $counter  = '0';
# For logs/General
my $time;
my $proc;
# Networking connection variables
my $ping;
my $tping;
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
            die "[!] $conf not found, run setup.sh to generate.\n";
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

sub end_proc{

     # checking if theres an wpa_supplicant orphan proc, if then kill it. 

     undef $proc;
     $proc = qx(ps aux);

     if ( $proc =~ /wpa_supplicant/ ) {
          print "[!] killing wpa_supplicant\n";
          system("killall", "wpa_supplicant");   
     }

}

#---------------------------------------
#------------=[ main ]=-----------------

# check if user is root
if ( $user ne 0 ) { 
   die "You must run this as root \n";
}

# test arguments 
if ( @ARGV < 2 || @ARGV > 2 ) {
   die "Usage: logger.pl [gps device] [wlan iface] \n";
}

# set arguments to specific variables
$device = $ARGV[0];
$wlan   = $ARGV[1];

# check if wpa_supplicant.conf exists 
chk_exist($wpasup);

# check name of mobile hotspot assigned to variable 
if ( $ssid =~ /hotspot-name/ ) {
  die "[!] you need to change the hotspot name (ssid) to your phone's\n";
}

# check if dhclient.conf exists
# chk_exist($dhclient);

# Starting infinite loop
while (1) {

   print "[!] sleeping for 120 secs\n";
   sleep(120);

   $time = qx(date +"%m""%d""%H""%M""%N");
           chomp($time);
           $time =~ s/\r|\n//g;

  # code block handling GPS device data
   print "[+] GPS device set to $device with a speed of $bauds\n";
   $gps = new GPS::NMEA(  'Port'      => $device,
                          'Baud'      => $bauds,
                     );

   while( $counter < 5 ) {

        my($ns,$lat,$ew,$lon) = $gps->get_position;
        open(my $fhandler, '+>>', "$log" ) or die "Could not open file $!";
        print $fhandler "($ns,$lat,$ew,$lon)\n";
        close $fhandler;
        $counter += 1;
        print "[+] dumping GPS coordinates to $log...\n"
   }
   $counter = 0;


  # checking if theres an wpa_supplicant orphan proc, if then kill it. 
   end_proc();

  # starting code block for wireless ap search 
   print "[*] scanning for hotspot to upload coordinate log\n";

   set_wlan();
   undef $aps;

   unless ( $aps = qx(iwlist $wlan scan)) {
      
        print "[!] ap scan failed... retrying in 5 secs\n";
        system("ifconfig", "$wlan", "up" );
        sleep(5);
        unless ($aps = qx(iwlist $wlan scan)) {
         
            print "[!] ap scan failed... retrying in 5 secs\n";
            system("ifconfig", "$wlan", "up" );
            sleep(5); 
            $aps = qx(iwlist $wlan scan) || die "[!] retry failed, does this interface exist?\n";
        }  

    }


   if ("$aps" =~ /$ssid/ ) {

        print "[+] found hotspot\n";
        print "[*] attempting association\n";
       
        if ( system("wpa_supplicant", "-D", "nl80211,wext", "-i", "$wlan", "-c", "wpa_supplicant.conf", "-B") == 0 ) {    
                  
                 $net = system("dhclient", "$wlan");
             
                 if ( not defined($ftp_host)) {
                    $ftp_host = qx(netstat -r | grep ^default | awk '{print \$2}'); 
                 }

                 chomp($ftp_host);
                 print "[*] got gateway $ftp_host\n";               

                 $ping = qx(ping -c 1 $ftp_host);
                 $tping = $ping =~ /ttl=/;
                 chomp($tping); 
          
                if (defined "$tping") {

                       print "[+] associated to hotspot\n"                  
                       print "[+] gateway is alive\n";
                       print "[*] attempting to upload logs via FTP\n";
             
                       if ( $ftp = Net::FTP->new( "$ftp_host",
                                         Port     => $ftp_port,
                                         timeout  => 20, 
                                         Debug    => 0,) ) {
                      
  
                                   $ftp->login("$ftp_usr","$ftp_pass")
                                         or print "[!] cannot login ", $ftp->message;
 
                                   $ftp->put("$log")
                                        or print "[!] cannot upload file", $ftp->message;
                       
                                   print "[+] uploaded file!\n";

                            } else {
 
                                   print "[!] cannot connect to $ftp_host\n";                     
                        }
                 }
          }

    } else{

        print "[!] access point not detected...\n";
   }

   unset_wlan();
   end_proc();

   print "[+] finished\n";

}
