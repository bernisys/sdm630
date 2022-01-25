#!/usr/bin/perl
 
use strict;
use warnings;
use diagnostics;
 
$| = 1;
 
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent = 1;
 
use lib "lib";

use Device::Modbus::TCP::Client;
use sdm630;

my $file = shift || 'sdm630.conf';
my $ref_config = SDM630::read_config($file);

my $ref_client = Device::Modbus::TCP::Client->new(host => $ref_config->{'IP_ADDRESS'}, timeout => $ref_config->{'TIMEOUT'});
while (1==1) {
  my %values;
  foreach my $ref_device (@{$ref_config->{'DEVICE'}}) {
    printf("%s (%s)\n", $ref_device->{'NAME'}, $ref_device->{'TYPE'});
    my $ref_values = SDM630::retrieve_all($ref_client, $ref_device->{'UNIT'}, $ref_device->{'TYPE'});
    print SDM630::output_values($ref_values);
    $values{$ref_device->{'UNIT'}} = {
      'type' => $ref_device->{'TYPE'},
      'data' => $ref_values,
    };
    SDM630::feed_rrds($ref_values, $ref_device->{'NAME'});
    if ($ref_device->{'TYPE'} eq 'SDM630') {
      SDM630::feed_rrds($ref_values);
    }

    print "\n";
  }
  my $sleeptime = 10 - time % 10;
  print "$sleeptime\n";
  sleep $sleeptime;
}

$ref_client->disconnect;


