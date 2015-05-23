#!/usr/bin/perl 
#
# gps2hotspot
# license BSD 3 
#

use strict;
use warnings;
use Net::FTP;
use GPS::NMEA;

#------------------=[ FTP edit block ]=------------------------
my $ftp_host_ip; # = 'x.x.x.x';  # only use this if you have a diff ftp server other than your phone
my $ftp_port     = '4444';
my $ftp_usr      = 'anon';
my $ftp_pass     = 'anon';

# configuration files
my $wpasup = 'wpa_supplicant.conf';

# the location of the log file;
my $log = '/var/log/location-data';

#------------------------=[ end ]=-----------------------------




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

}

sub unset_wlan{
    
	my $wlan = $_[0];
	system("dhclient", "-r", "$wlan");
	system("ifconfig", "$wlan", "down");

}

sub set_wlan{

	my $wlan = $_[0];
	system("ifconfig", "$wlan", "up");
}


# Requires variable that specifies wlan interface to be used.
sub scan_wlan{

	my $wlan = $_[0];
	my $aps;
	unless ( $aps = qx(iwlist $wlan scan)) {

        	print "[!] ap scan failed... retrying in 5 secs\n";
        	system("ifconfig", "$wlan", "up" );
        	sleep(7);
   	}
	else {
		$aps = qx(iwlist $wlan scan) || die "[!] retry failed, does this interface exist?\n";
	}

	return $aps;

}


sub end_proc{


	# checking if theres an wpa_supplicant orphan proc, if then kill it. 
	my $proc = qx(ps aux);

	if ( $proc =~ /wpa_supplicant / ) {
        	print "[!] killing wpa_supplicant\n";
        	system("killall", "wpa_supplicant");

	}

}


# subroutine handling GPS device data and coordinate format conversion from DMM to DDD
# requires device name, baud number as parameters
sub log_gps{

	my $de      = $_[0];
	my $ba 	    = $_[1];
	my $gps_log = $_[2];

	print "[+] GPS device set to $de with a speed of $ba\n";
	my $gps = new GPS::NMEA('Port' => $de, 'Baud' => $ba );

	my $counter = 0;
	while( $counter < 1 ) {

        	my($ns,$lat,$ew,$lon) = $gps->get_position;

        	# just in case        
        	chomp($lon); chomp($lat); chomp($ns); chomp($ew);

        	my ($latdeg, $latmin) = split("\\.", $lat);
        	my ($londeg, $lonmin) = split("\\.", $lon);

        	# decimal calculation
        	# Splitting up decimals into places

        	my $latones   = substr($latmin, 0, 2);
        	my $lonones   = substr($lonmin, 0, 2);

        	my $lattenths = substr($latmin, 2, 6);
        	my $lontenths = substr($lonmin, 2, 6);

        	# doing some math to convert the minutes to decimals

        	my $latdiv    = join(".", $latones, $lattenths);
        	my $latdecraw = $latdiv / 60;
        	my $latdec    = substr($latdecraw, 2, 5);

        	my $londiv    = join(".", $lonones, $lontenths);
        	my $londecraw = $londiv / 60;
        	my $londec    = substr($londecraw, 2, 5);

        	# the calculations above are to decimal degrees and are stored in 
       		# the latdec / londec variables 

        	my $latdeccoor = join(".", $latdeg, $latdec);
        	my $londeccoor = join(".", $londeg, $londec);

        	# calculating polarity
        	# positive will be blank since in Google maps only negative is visible

		my $latpol;
        	if ($ns eq "N") { $latpol = ' '; }
        	if ($ns eq "S") { $latpol = '-'; }
        
		my $lonpol;
        	if ($ew eq "E") { $lonpol = ' '; }
        	if ($ew eq "W") { $lonpol = '-'; }


        	open(my $fh, '+>>', "$gps_log" ) or die "Could not open file $!";
        	print $fh "[DMM: $ns,$lat,$ew,$lon ][DDD:$latpol$latdeccoor,$lonpol$londeccoor ]\n";
        	close $fh;
        	$counter += 1;
        	print "[+] dumping GPS coordinates to $gps_log...\n";
	}
	$counter = 0;

}


# Requires ftp server ip, fhost, fport, fusr, $fpass, $time variables as parameters
sub wlan_connect_upload{

	my $wlan      = $_[0];
	my $wpaconf   = $_[1];
	my $server_ip = $_[2];
	my $fport     = $_[3];
	my $fusr      = $_[4];
	my $fpass     = $_[5];
	my $time_of   = $_[6];
	my $gps_log   = $_[7];

	if ( system("wpa_supplicant", "-D", "nl80211,wext", "-i", "$wlan", "-c", "$wpaconf", "-B") == 0 ) {

		# force perl script to wait until dhclient is done 
		my $net = system("dhclient", "$wlan");

		my $fhost;
		if ( not defined($server_ip)) {
              		$fhost = qx(netstat -r | grep ^default | awk '{print \$2}');
               		chomp($fhost);
        	} else { 
			my $fhost = $server_ip; 
		}

       		if ("$fhost" =~ /[0-9]/ ) {

            		print "[+] got gateway $fhost\n";
            		my $ping = qx(ping -c 2 $fhost);

            		if ( "$ping" =~ /ttl=/ ) {

                 		print "[+] associated to hotspot\n";
                 		print "[+] gateway is alive\n";
                 		print "[*] attempting to upload logs via FTP\n";

				# the code below handles the ftp log upload process.
                 		if ( my $ftp = Net::FTP->new( "$fhost", Port => $fport, timeout  => 20, Debug => 0,) )  {

                     			$ftp->login("$fusr","$fpass")
                            			or print "[!] cannot login ", $ftp->message;
           	    			$ftp->put("$gps_log")
         	            			or print "[!] cannot upload file", $ftp->message;

	            			print "[+] uploaded file!\n";

                  		} else { print "[!] cannot connect to $fhost\n"; }
			 } else { print "[!] link cannot be established!\n"; }   
       		} else { print "[!] gateway could not be established\n"; }
	} else { print"[!] could not associate to hotspot at $time_of\n"; }


}

#---------------------------------------
#------------=[ main ]=-----------------


# permission variables 
my $user = $>;

# check if user is root
if ( $user ne 0 ) { die "You must run this as root \n"; }

# test arguments 
if ( @ARGV < 4 || @ARGV > 4 ) {	
	die "Usage: gps2hotspot.pl [gps device] [baud rate] [wlan iface] [hotspot-name (ssid)]\n";
}

# set arguments to specific variables
if (not defined($ARGV[0])) { die "[!] you need to specify a gps device as the first arg\n"; }
my $device = $ARGV[0];

if (not defined($ARGV[1])) { die "[!] you need to specify the baud rate of the gps device as the second arg\n";	}
my $bauds = $ARGV[1]; 

if (not defined($ARGV[2])) { die "[!] you need to specify the iface of an wireless adapter as the third arg\n";	}
my $wlan_iface = $ARGV[2];

if (not defined($ARGV[3])) { die "[!] you need to specify a hotspotname (ssid) as the fourth arg\n"; }
my $ssid = $ARGV[3];

# check if wpa_supplicant.conf exists 
chk_exist($wpasup);

if ( not defined($ftp_host_ip)) {
	print "[!] since you have not assigned an ip to the ftp_host_ip\n it will use the ip of the default gateway\n";
}


# logging location then attempting upload

my $time = qx(date +"%D":"%r");
chomp($time);
$time =~ s/\r|\n//g;

# get gps data and convert to DDD from DMM
log_gps($device, $bauds, $log);

# checking if theres an wpa_supplicant orphan proc, if then kill it. 
end_proc();

# starting code block for wireless ap search 
print "[*] scanning for hotspot to upload coordinate log\n";

set_wlan($wlan_iface);
my $scan = scan_wlan($wlan_iface);

if ("$scan" =~ /$ssid/ ) {

	print "[+] found hotspot\n";
	print "[*] attempting association\n";
    
	wlan_connect_upload($wlan_iface, $wpasup, $ftp_host_ip, $ftp_port, $ftp_usr, $ftp_pass, $time, $log);
       
} else{ print "[!] hotspot not detected...\n"; }

unset_wlan($wlan_iface);
end_proc();

print "[+] finished at $time\n";


