#!/usr/bin/perl -w

use lib '.';

use strict;
use utf8;

use Getopt::Std;
use Data::Dumper;
use YAML::XS;
use POSIX qw(strftime);
use Kinetic::Raise;

use constant DEFAULT_CONFIG_FILE => './test_config.yml';
use constant DEFAULT_RULES_ENGINE => 'kibdev.kobj.net';


# global options
use vars qw/ %opt /;
my $opt_string = 'c:?hvd';
getopts( "$opt_string", \%opt ) or usage();

usage() if $opt{'h'} || $opt{'?'};


print "No test file specified. Using " . DEFAULT_CONFIG_FILE . "\n" unless $opt{'c'};

my $config = read_config($opt{'c'});
my $eci = $config->{'eci'};
my $server = $config->{'rules_engine'} || DEFAULT_RULES_ENGINE;

# find tests
my @config_keys = keys %{ $config };
my @tests = grep(/^test_/, @config_keys);

foreach my $test_key (@tests) {
  my $test = $config->{$test_key};
#  print Dumper $test;

  my $options =  {'eci' => $eci,
		  'host' => $server,
		 };

  $options->{'rids'} = $test->{'rids'} if $test->{'rids'};

#  print Dump $options;

  my $event = Kinetic::Raise->new($test->{'domain'},
  				  $test->{'type'},
  				  $options
  				 );

  my $response = $event->raise($test->{'attributes'});

  my $succ = 0;
  my $fail = 0;
  my $diag = 0;
  foreach my $d (@{$response->{'directives'}}) {

    my $opt = $d->{'options'};
    if ($opt->{'status'} eq 'success') {
      $succ++;
    } elsif (($opt->{'status'} eq 'failure')) {
      $fail++;
    } else {
      $diag++;
    }

    if ($opt{'v'}) {

      my $content_str = "";

      if ( $opt->{'status'} eq 'success' ||
	   $opt->{'status'} eq 'failure' ||
	   $opt{'d'}
	 ) {
	print $opt->{'status'}, ": ";
	print $opt->{'rule'}, ": " if $opt->{'rule'};
	print $d->{'name'}, "\n";
      }

      if ($opt{'d'}) { # print diagnositcs too
	my $content = JSON::XS->new->decode($d->{'options'}->{'details'});
	$content_str = JSON::XS->new->ascii->pretty->encode($content) . "\n";
      }
      print $content_str;
      
    }
  }
  print $test->{'desc'}, ": ", $succ , " suceeded, ", $fail, " failed, ", $diag, " diagnostic messages\n";
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

example: $0 -c test_AWS.yml

EOF
    exit;
}
