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
  chomp $now;
  my %values;
  my $ref_client = Device::Modbus::TCP::Client->new(host => $ref_config->{'IP_ADDRESS'}, timeout => $ref_config->{'TIMEOUT'});

  printf('@%s', $now);
  my @output = ();
  foreach my $ref_device (@{$ref_config->{'DEVICE'}}) {
    my $ref_values = SDM630::retrieve_all($ref_client, $ref_device->{'UNIT'}, $ref_device->{'TYPE'});
    $values{$ref_device->{'UNIT'}} = {
      'type' => $ref_device->{'TYPE'},
      'data' => $ref_values,
    };

    printf(" - %s (%s)", $ref_device->{'NAME'}, $ref_device->{'TYPE'});
    push @output, sprintf("%s (%s)\n", $ref_device->{'NAME'}, $ref_device->{'TYPE'}), SDM630::output_values($ref_values), "\n";

    push @output, SDM630::feed_rrds($ref_values, $ref_device->{'NAME'});
    if ($ref_device->{'TYPE'} eq 'SDM630') {
      push @output, SDM630::feed_rrds($ref_values, 'test');
    }
  }
  $ref_client->disconnect;
  print "\n";

  foreach my $ref_device (@{$ref_config->{'DEVICE'}}) {
    if (! -f $ref_config->{'WEBDIR'}.'/'.$ref_device->{'NAME'}.'/index.html') {
      SDM630::generate_indexes($ref_config->{'WEBDIR'}, $ref_device->{'TYPE'}, $ref_device->{'NAME'});
    }
  }

  if ((time % 300) < 10) {
    open(my $h_file, '>', 'web/readings.txt');
    print $h_file $now, "\n", @output;
    close($h_file);
  }
  my $sleeptime = 10 - time % 10;
  print join('', $now, "\n", @output, $sleeptime, "\n");

  sleep $sleeptime;
}



