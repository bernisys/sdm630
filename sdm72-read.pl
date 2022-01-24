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
my $address = shift || 1;

my $ref_config = SDM630::read_config($file);

my $ref_client = Device::Modbus::TCP::Client->new(host => $ref_config->{'IP_ADDRESS'}, timeout => $ref_config->{'TIMEOUT'});
while (1==1) {
  foreach my $ref_device (@{$ref_config->{'DEVICE'}}) {
    printf("%s (%s)\n", $ref_device->{'NAME'}, $ref_device->{'TYPE'});
    my $ref_values = SDM630::retrieve_all($ref_client, $ref_device->{'UNIT'}, $ref_device->{'TYPE'});
    SDM630::output_values($ref_values);
    SDM630::feed_rrds($ref_values, $ref_device->{'NAME'});
    if ($ref_device->{'TYPE'} eq 'SDM630') {
      SDM630::feed_rrds($ref_values);
    }

    print "\n";
  }
  my $now = time;
  my $sleeptime = $now - int($now/10)*10;
  print "$sleeptime\n";
  sleep $sleeptime;
}
$ref_client->disconnect;

