#!/usr/bin/perl
#############################################################
# resource.pl v1.1 :                                        #
# Basic perl wrapper for apis to collect raw system data    #
#############################################################

use warnings;
use strict;
use JSON::XS;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Getopt::Long;

# global variables
my $api_bin = "/usr/local/cpanel/bin/whmapi1";
my $fact_bin = "/usr/bin/facter";
my $jp = "jsonpretty";
my ( $opt, $active, $suspended );
my ( @suspended, @active ); 

# help them if no arg given
if (@ARGV == 0 ) {
help()
}

my ( $diskstats, $inodestats, $bwstats, $domstats, $help );
GetOptions (
    'disk'     => \&diskstats,
    'inode'    => \&inodestats,
    'bw'       => \&bwstats,
    'dom'      => \&domstats,
    'acts'      => \&accstats,
    'serverinfo' => \&serverinfo,
    'user'     => \&usrstats,
    'actlist'  => \&actlist,
    'help'     => \&help,
    'json'     => \$opt,
) or help();

sub help {
    print "$0 accepts following flags:
1. $0 --disk       : list users disk usage in blocks
2. $0 --bw         : list users monthly bandiwtdh usage
3. $0 --inode      : list users inodes usage
4. $0 --dom        : list users domains / subdomains
5. $0 --acts       : cPanel active / suspended counts
6. $0 --serverinfo : server information | add '--json' for json format output
7. $0 --user user  : get user basic information
8. $0 --actlist    : list all cPanel accounts
9. $0 --help       : help section\n";
}

sub diskstats {
my $djson = qx($api_bin get_disk_usage --output=$jp);
my $ddata = decode_json ( $djson );
my $dresult = $ddata->{'data'}{'accounts'};
 
    print "cp_user :: Blocks:\n";
    print "===================\n";
    foreach my $diskstats(@$dresult) {
        print "$diskstats->{'user'} $diskstats->{'blocks_used'}\n";
    }
}

sub inodestats {
my $djson = qx($api_bin get_disk_usage --output=$jp);
my $ddata = decode_json ( $djson );
my $dresult = $ddata->{'data'}{'accounts'};

    print "cp_user :: Inodes:\n";
    print "===================\n";
    foreach my $inodestats(@$dresult) {
        print "$inodestats->{'user'} $inodestats->{'inodes_used'}\n";
   }
}

sub bwstats {
my $bjson = qx($api_bin showbw --output=$jp);
my $bdata = decode_json ( $bjson );
my $bresult = $bdata->{'data'}{'acct'};

    print "cp_user :: Bandwidth:\n";
    print "===================\n";
    foreach my $bwstats(@$bresult) {
        print "$bwstats->{'user'} $bwstats->{'totalbytes'}\n";
    }
}

sub domstats {
my $dojson = qx($api_bin get_domain_info --output=$jp);
my $dodata = decode_json ( $dojson );
my $doresult = $dodata->{'data'}{'domains'};

    print "cp_user :: domains:\n";
    print "===================\n";
    foreach my $domstats(@$doresult) {
        print "$domstats->{'user'} $domstats->{'domain'}\n";
    }
}

sub accstat {
my $acjson = qx($api_bin listaccts --output=$jp);
my $acdata = decode_json ( $acjson );
my $accdata = $acdata->{'data'}{'acct'};

    foreach my $acstats(@$accdata) {
if ( $acstats->{'suspended'} == 1 ) {
     my $user = $acstats->{'user'};
     push(@suspended, $user);
      }
   }

    foreach my $acstats(@$accdata) {
if ( $acstats->{'suspended'} == 0 ) {
     my $user = $acstats->{'user'};
     push(@active, $user);
      }
   }
     $active = scalar @active;
     $suspended = scalar @suspended;
}

sub accstats {
     accstat();
     print "cPanel users: active : $active : ";
     print "suspended: $suspended\n";
}

sub serverinfo {
my $fjson = qx($fact_bin -j);
my $fdata = decode_json ( $fjson );
my $vjson = qx($api_bin version --output=$jp);
my $vdata = decode_json ( $vjson );
my $jformat = $ARGV[0] // '';

if ( $jformat eq "--json" ) {
my $j = JSON::XS->new->utf8->pretty(1);
accstat();
my %serverinfo = (
'Hostname'=>$fdata->{'fqdn'},
'Uptime'=>$fdata->{'system_uptime'}{'uptime'},
'CPU count'=>$fdata->{'physicalprocessorcount'},
'Kernel'=>$fdata->{'kernelrelease'},
'OS'=>$fdata->{'os'}{'name'},
'Version'=>$fdata->{'os'}{'release'}{'full'},
'Memory'=>$fdata->{'memorysize'},
'Type'=>$fdata->{'virtual'},
'cPanel version'=>$vdata->{'data'}{'version'},
'cPanel suspended:'=>$suspended,
'cPanel active:'=>$active,
'Selinux'=>$fdata->{'selinux'},
'IP Address'=>$fdata->{'ipaddress'},
'Mac Address'=>$fdata->{'macaddress'}
);
my $jsonsi = encode_json \%serverinfo;
print "$jsonsi\n";
} else {
    accstat();
    print "Hostname => $fdata->{'fqdn'}\n";
    print "Uptime => $fdata->{'system_uptime'}{'uptime'}\n";
    print "CPU count => $fdata->{'physicalprocessorcount'}\n";
    print "Kernel => $fdata->{'kernelrelease'}\n";
    print "OS => $fdata->{'os'}{'name'} : ";
    print "Version => $fdata->{'os'}{'release'}{'full'}\n";
    print "Memory => $fdata->{'memorysize'}\n";
    print "Type => $fdata->{'virtual'}\n";
    print "cPanel version => $vdata->{'data'}{'version'}\n";
    print "cPanel users: active : $active : ";
    print "suspended: $suspended\n";
    print "Selinux : $fdata->{'selinux'}\n";
    print "IP Address: $fdata->{'ipaddress'}\n";
    print "Mac Address : $fdata->{'macaddress'}\n";
  }
}

sub usrstats {
my $acjson = qx($api_bin listaccts --output=$jp);
my $acdata = decode_json ( $acjson );
my $usrdata = $acdata->{'data'}{'acct'};
my $user = $ARGV[0] // '';

if (defined $user) {
     foreach my $usrstats(@$usrdata) {
if ( $usrstats->{'user'} eq "$user" ) {
    print "user: " . $usrstats->{'user'} . "\n";
    print "uid: " . $usrstats->{'uid'} . "\n";
    print "domain: " . $usrstats->{'domain'} . "\n";
    print "owner: " . $usrstats->{'owner'} . "\n";
    print "email: " . $usrstats->{'email'} . "\n";
    print "diskused: " . $usrstats->{'diskused'} . "\n";
    print "inodesused: " . $usrstats->{'inodesused'} . "\n";
    print "partition: " . $usrstats->{'partition'} . "\n";
    print "ip: " . $usrstats->{'ip'} . "\n";
    print "shell: " . $usrstats->{'shell'} . "\n";
    print "suspended?: " . $usrstats->{'suspendreason'} . "\n";
if ( $usrstats->{'user'} ne $usrstats->{'owner'} && $usrstats->{'owner'} ne "root" ) {
    print "Acct type: Resold\n";
        }
      }
    }
  }
}

sub actlist {
my $acjson = qx($api_bin listaccts --output=$jp);
my $acdata = decode_json ( $acjson );
my $usrdata = $acdata->{'data'}{'acct'};
foreach my $usrstats(@$usrdata) {
     print $usrstats->{'user'} . "\n";
  }  
}
