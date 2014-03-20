#!/usr/bin/perl -w

use lib '.';

use strict;
use utf8;

use Getopt::Std;
# use Data::Dumper;
use YAML::XS;
use POSIX qw(strftime);
use Kinetic::Raise;

use constant DEFAULT_CONFIG_FILE => './test_config.yml';
use constant DEFAULT_RULES_ENGINE => 'kibdev.kobj.net';


# global options
use vars qw/ %clopt /;
my $opt_string = 'c:?hvd';
getopts( "$opt_string", \%clopt ) or usage();

usage() if $clopt{'h'} || $clopt{'?'};

print "No test file specified. Using " . DEFAULT_CONFIG_FILE . "\n" unless $clopt{'c'};
my $config = read_config($clopt{'c'});
my $eci = $config->{'eci'};
my $server = $config->{'rules_engine'} || DEFAULT_RULES_ENGINE;

# find tests
my @config_keys = keys %{ $config };
my @tests = sort(grep(/^test_/, @config_keys));

#my %spec_tests = map { $_ => 1 } split(/;/, $clopt{"t"});



my $global_succ = 0;
my $global_fail = 0;
my $global_diag = 0;

foreach my $test_key (@tests) {
  my $test = $config->{$test_key};

  my $options =  {'eci' => $eci,
		  'host' => $server,
		 };

  $options->{"rids"} = $config->{"rids"} if $config->{'rids'};
  $options->{'rids'} = $test->{'rids'} if $test->{'rids'};

#  print Dump $test;
#  print Dump $options;

  my $event = Kinetic::Raise->new($test->{'domain'},
  				  $test->{'type'},
  				  $options
  				 );

  my $eid = $test_key."_".time;
  my $response = $event->raise($test->{'attributes'}, {"eid" => $eid, "esl" => 1});

  my $succ = 0;
  my $fail = 0;
  my $diag = 0;

  my $ran = 0;
  if ($clopt{"v"}) {
      print "Test ESL: ", $response->{"_esl"}, "\n\n";
  }
  foreach my $d (@{$response->{'directives'}}) {

    my $opt = $d->{'options'};
    if ($opt->{'status'} eq 'success') {
      $succ++;
      $ran++;
    } elsif (($opt->{'status'} eq 'failure')) {
      $fail++;
      $ran++;
    } else {
      $diag++;
    }

    if ($clopt{'v'}) {

      my $content_str = "";

      if ( $opt->{'status'} eq 'success' ||
	   $opt->{'status'} eq 'failure' ||
	   $clopt{'d'}
	 ) {
	print ">> " if $opt->{'status'} eq 'failure';
	print $opt->{'status'}, " ";	
	print "<< " if $opt->{'status'} eq 'failure';
	print $opt->{'rule'}, ": " if $opt->{'rule'};
	print $d->{'name'};
	print $opt->{"msg"} if $opt->{"msg"};
	print "\n";
      }

      if ($clopt{'d'}) { # print diagnositcs too
	my $content = JSON::XS->new->decode($d->{'options'}->{'details'});
	$content_str = JSON::XS->new->ascii->pretty->encode($content) . "\n";
      }
      print $content_str;
      
    }
  }
  $global_succ += $succ;
  $global_fail += $fail;
  $global_diag += $diag;

  if ($ran != $test->{'expect'}) {
      print ">> WARNING << Expected ", $test->{"expect"}, " test but ran $ran\n";
  }
  print $test_key, " ", $test->{'desc'}, " ($eid): ", $succ , " succeeded, ", $fail, " failed, ", $diag, " diagnostic messages\n---------------------------------- $eid ---------------------------------\n\n";
}

print "Summary: ", $global_succ , " succeeded, ", $global_fail, " failed, ", $global_diag, " diagnostic messages\n";

if ($global_fail) {
  exit 1
} else {
  exit 0
}
1;

sub read_config {
    my ($filename) = @_;

    $filename ||= DEFAULT_CONFIG_FILE;

#    print "File ", $filename;
    my $config;
    if ( -e $filename ) {
      $config = YAML::XS::LoadFile($filename) ||
	warn "Can't open configuration file $filename: $!";
    }

    return $config;
}


#
# Message about this program and how to use it
#
sub usage {
    print STDERR << "EOF";

Test harness for running KRL tests 

usage: $0 [-h?] -c config_file.yml

 -h|?      : this (help) message
 -c file   : configuration file
 -v        : vebose, print diagnostic messges
 -d        : print details accompanying diagnostics. 
 -t        : test to run as a semicolon separated list of names

example: $0 -c test_AWS.yml -vd

EOF
    exit;
}
