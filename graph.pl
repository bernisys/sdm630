#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;

$| = 1;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent = 1;

use lib "lib";
use sdm630;

my $file = shift || 'sdm630.conf';
my $ref_config = SDM630::read_config($file);

my $now = qx/date/;
chomp $now;

printf("@%s\n", $now);

foreach my $ref_device (@{$ref_config->{'DEVICE'}}) {
  SDM630::generate_indexes($ref_config->{'WEBDIR'}, $ref_device->{'TYPE'}, $ref_device->{'NAME'});
  SDM630::generate_diagrams($ref_config->{'WEBDIR'}, $ref_device->{'TYPE'}, $ref_device->{'NAME'}, 1, @ARGV);
}

