#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;

$| = 1;

use RRDs;

use lib "lib";
use sdm630;

SDM630::create_all_rrds();


