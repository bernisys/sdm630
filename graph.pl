#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;

$| = 1;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent = 1;

use RRDs;

use lib "lib";
use sdm630;

my $OUTPUT='/home/user/berni/public_html/powermeter';
my $file = shift || 'sdm630.conf';
my $ref_config = SDM630::read_config($file);

foreach my $ref_device (@{$ref_config->{'DEVICE'}}) {
  if (! -f $OUTPUT.'/'.$ref_device->{'NAME'}.'/index.html') {
    SDM630::generate_indexes($OUTPUT, $ref_device->{'TYPE'}, $ref_device->{'NAME'});
  }
  SDM630::generate_diagrams($OUTPUT, $ref_device->{'TYPE'}, $ref_device->{'NAME'}, @ARGV);
}

exit 0;


