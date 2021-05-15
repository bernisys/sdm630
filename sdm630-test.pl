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

for (my $start = 0; $start < 400; $start += 10) {
output_values(retrieve_raw(1, $start,  10), $start );
}
exit 0;


sub retrieve_raw {
  my $unit = shift || 1;
  my $address = shift || 0;
  my $quantity = shift || 2;

  my $ref_req = $ref_client->read_input_registers(unit => $unit, address => $address, quantity => $quantity);
  $ref_client->send_request($ref_req);
  my $ref_response = $ref_client->receive_response;

  return $ref_response->{'message'}{'values'};
}


sub output_values {
  my $ref_values = shift;
  my $start = shift || 0;

  my $count = scalar(@{$ref_values});
  for (my $pair = 0; $pair < $count ; $pair += 2) {
    my $hi = $ref_values->[$pair];
    my $lo = $ref_values->[$pair + 1];
    my $b32 = ($hi << 16) + $lo;

    my $float = unpack('f', pack('L*', $b32));
    $float = 0 if !defined $float;

    printf("%2d H=0x%04x L=0x%04x W=0x%08x (%4.8f)\n", $start + $pair, $hi, $lo, $b32, $float);
  }
}

$ref_client->disconnect;

