#!/usr/bin/perl
# Zabbix friendly parser for HTTP server-status statistics
# Modified from Brandon Davidson's Cacti script
# Alex Harris <aharris8@uoregon.edu> 11-20-2014

# Required Packages:
# perl
# libcurl
# perl-WWW-curl
# +package dependencies

use strict;
use Sys::Hostname;
use Getopt::Std;
use WWW::Curl::Easy;

# Set up command line option flags
my %options=();
getopts ("p:m:", \%options);

my $curl = new WWW::Curl::Easy;
my $HOST = hostname;
my $PORT = $options{p} || 80;
my $METRIC = $options{m} || "BytesPerSec";
my $response_body;
my $fileb;
my $url;
my %legend = (
        '_' => "Waiting",
        'S' => 'Starting',
        'R' => 'Reading',
        'W' => 'Sending',
        'K' => 'Keepalive',
        'D' => 'DNS',
        'C' => 'Closing',
        'L' => 'Logging',
        'G' => 'Graceful',
        'I' => 'Cleanup',
);
my %statValues = (
#	Expected possible keys
	'TotalAccesses'		=> 0,
	'TotalkBytes'		=> 0,
	'CPULoad'		=> 0,
	'Uptime'		=> 0,
	'ReqPerSec'		=> 0,
	'BytesPerSec'		=> 0,
	'BytesPerReq'		=> 0,
	'BusyWorkers'		=> 0,
	'IdleWorkers'		=> 0,
	'WorkersStarting'	=> 0,
	'WorkersSending'	=> 0,
	'WorkersKeepalive'	=> 0,
	'WorkersWaiting'	=> 0,
	'WorkersDNS'		=> 0,
	'WorkersClosing'	=> 0,
	'WorkersCleanup'	=> 0,
	'WorkersReading'	=> 0,
	'WorkersGraceful'	=> 0,
	'WorkersLogging'	=> 0,
);

# Check for known port numbers and format URL correctly
if($PORT =~ m/443/){
  if($PORT != 443){
    $url = "https://$HOST:$PORT/server-status?auto";
  } else {
    $url = "https://$HOST/server-status?auto";
  }
} elsif ($PORT != 80){
  $url = "http://$HOST:$PORT/server-status?auto";
} else {
  $url = "http://$HOST/server-status?auto";
}

# Set libcurl options
$curl->setopt(CURLOPT_URL, $url);
$curl->setopt(CURLOPT_SSL_VERIFYHOST, 0);
$curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);

# Open filehandle for libcurl write operations
open($fileb, ">", \$response_body);
$curl->setopt(CURLOPT_WRITEDATA,$fileb);

# Check libcurl calls for errors, returns 0 if successful
my $retcode = $curl->perform;
if ($retcode == 0) {
	# Check http status code returned to curl, 200 is "Request was fulfilled"
        my $http_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        if ($http_code == 200){
		# Create list of lines returned by http request
                my @lines = split("\n", $response_body);
                foreach my $line (@lines){
			# If at scoreboard status section, use scoreboard subroutine, otherwise take statistic name and value, and insert into hash
                        if ($line =~ m/^Scoreboard: (.*)/){
				# Strip indicators of slots with no current process and send line to scoreboard subroutine
				$line =~ s/[Scoreboard: ^\.]+//g;
				scoreboard($line);
                        } else {
				# Parse Metric and Value from status line and insert into hash
                                (my $stat  = $line) =~ s/([^a-zA-Z]+)//g;
				(my $value = $line) =~ s/([^0-9]+)//g;
				$statValues{$stat} = $value;
                        }
                }
		# Print value of requested metric for use by Zabbix
		print "$statValues{$METRIC}\n";
        } else {
                print("Error - Recieved HTTP response code $http_code\n");
        }
} else {
        print("Error - ".$curl->strerror($retcode)." ($retcode)\n");
}

sub scoreboard {
	# Create hash of characters from scoreboard, increment value by 1 for each instance found
        foreach my $s (split('', shift())){
                $statValues{"Workers$legend{$s}"}++;
        }
}
