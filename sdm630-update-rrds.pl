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

 
my $count = 21;
my $start = 0;
 
my $ref_client = Device::Modbus::TCP::Client->new(host => "192.168.178.16", timeout => 2);
my $ref_values = SDM630::retrieve_all($ref_client);
$ref_client->disconnect;

SDM630::output_values($ref_values);
SDM630::feed_rrds($ref_values);
#print Dumper($ref_values);

