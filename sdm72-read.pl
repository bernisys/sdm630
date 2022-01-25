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

while (1==1) {
  my $now = qx/date/;
  my %values;
  my @output = ();
  my $ref_client = Device::Modbus::TCP::Client->new(host => $ref_config->{'IP_ADDRESS'}, timeout => $ref_config->{'TIMEOUT'});
  foreach my $ref_device (@{$ref_config->{'DEVICE'}}) {
    my $ref_values = SDM630::retrieve_all($ref_client, $ref_device->{'UNIT'}, $ref_device->{'TYPE'});
    $values{$ref_device->{'UNIT'}} = {
      'type' => $ref_device->{'TYPE'},
      'data' => $ref_values,
    };

    push @output, sprintf("%s (%s)\n", $ref_device->{'NAME'}, $ref_device->{'TYPE'}), SDM630::output_values($ref_values), "\n";

    SDM630::feed_rrds($ref_values, $ref_device->{'NAME'});
    if ($ref_device->{'TYPE'} eq 'SDM630') {
      SDM630::feed_rrds($ref_values, 'test');
    }
  }
  $ref_client->disconnect;

  my $sleeptime = 10 - time % 10;
  print join('', $now, "\n", @output, $sleeptime, "\n");

  if ((time % 300) < 10) {
    open(my $h_file, '>', 'web/readings.txt');
    print $h_file $now, "\n", @output;
    close($h_file);
  }
  sleep $sleeptime;
}



