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
my $opt_string = 'c:?hv';
getopts( "$opt_string", \%opt ) or usage();

usage() if $opt{'h'} || $opt{'?'};


warn "No configuration file specified. Using " . DEFAULT_CONFIG_FILE unless $opt{'c'};

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

  foreach my $d (@{$response->{'directives'}}) {
    my $content_str = "";
    if ($opt{'v'}) {
      my $content = JSON::XS->new->decode($d->{'options'}->{'content'});
      $content_str = JSON::XS->new->ascii->pretty->encode($content);
    }
    print $d->{'name'}, "\n";
    print $content_str;
  }
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
