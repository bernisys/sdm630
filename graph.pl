#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;

$| = 1;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent = 1;

use RRDs;

my $OUTPUT='/home/user/berni/public_html/powermeter';

# TODO:  find best brown value for L1
# CD853F - seems okay for now, could be slightly darker though
# 720239 - a bit dark, hardly distinguishable from black in graphs

my %COLORS = (
  'L1'  => 'CD853F',
  'L2'  => '000000',
  'L3'  => '808080',
  'N'   => '0000ff',
  'avg' => '00ff00',
  'sum' => '00a0a0',
  'in'  => 'a00000',
  'out' => '00a000',
);

my %graphs = (
  'base' => {
    'width' => 600,
    'height' => 200,
  },
  'times' => {
    'hour'    => { 'start' => -3600,        'step' =>    10, 'func' => ['avg'] },
    '6h'      => { 'start' => -6*3600,      'step' =>    10, 'func' => ['min', 'avg', 'max'] },
    'day'     => { 'start' => -86400,       'step' =>    60, 'func' => ['min', 'avg', 'max'] },
    'week'    => { 'start' => -7*86400,     'step' =>   600, 'func' => ['min', 'avg', 'max'] },
    'month'   => { 'start' => -31*86400,    'step' =>  3600, 'func' => ['min', 'avg', 'max'] },
    '3month'  => { 'start' => -93*86400,    'step' =>  3600, 'func' => ['min', 'avg', 'max'] },
    '6month'  => { 'start' => -186*86400,   'step' =>  3600, 'func' => ['min', 'avg', 'max'] },
    'year'    => { 'start' => -366*86400,   'step' => 43200, 'func' => ['min', 'avg', 'max'] },
    '5year'   => { 'start' => -5*366*86400, 'step' => 43200, 'func' => ['min', 'avg', 'max'] },
  },
#  'rrd_param' => { 'charge'         => { 'type' => 'COUNTER', 'rows' => ['Ah:0:U', ], }, },
  'html' => {
    'sections' => [
      { 'heading' => 'Phase parameters', 'graphs' => [ 'frequency', 'voltage', 'current', 'phi', ], },
      { 'heading' => 'Power',            'graphs' => [ 'power_w', 'power_var', 'power_va', 'power_w_demand', 'powerfactor', ], },
      { 'heading' => 'Energy',           'graphs' => [ 'energy', 'energy_kwh', 'energy_kvarh', ], },
    ],
  },
  'diagrams' => {
    'voltage_l' => {
      'type' => 'GAUGE',
      'unit' => 'V', 'title' => 'Voltage L-N',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'avg', 'color' => $COLORS{'avg'}, 'style' => 'LINE1', 'data_range' => '0:270', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:270', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:270', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:270', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 230, 'color' => '0000ff' },
      ],
    },
    'voltage_ll' => {
      'type' => 'GAUGE',
      'unit' => 'V', 'title' => 'Voltage L-L',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'avg',  'color' => $COLORS{'avg'}, 'style' => 'LINE1', 'data_range' => '0:270', 'minmax' => 'yes', },
        { 'row' => 'L1L2', 'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:270', 'minmax' => 'no', },
        { 'row' => 'L2L3', 'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:270', 'minmax' => 'no', },
        { 'row' => 'L3L1', 'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:270', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 230, 'color' => '0000ff' },
      ],
    },
    'current' => {
      'type' => 'GAUGE',
      'unit' => 'A', 'title' => 'Current',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'sum', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '0:100', 'minmax' => 'yes', },
        { 'row' => 'avg', 'color' => $COLORS{'avg'}, 'style' => 'LINE1', 'data_range' => '0:100', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'N',   'color' => $COLORS{'N'},   'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
      ],
    },
    'current_demand' => {
      'type' => 'GAUGE',
      'unit' => 'A', 'title' => 'Current demand',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
      ],
    },
    'current_demandmax' => {
      'type' => 'GAUGE',
      'unit' => 'A', 'title' => 'Current demand max',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
      ],
    },
    'frequency' => {
      'type' => 'GAUGE',
      'unit' => 'Hz', 'title' => 'Frequency',
      'min' => 49.9, 'max' => 50.1,
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'Hz',  'color' => '000000', 'style' => 'LINE1', 'data_range' => '30:70', 'minmax' => 'yes', },
      ],
      'lines' => [
        { 'height' => 51.5,  'color' => '0000a0', 'legend' => 'solar power total disablement\n' },
        { 'height' => 50.2,  'color' => 'e0e000', 'legend' => 'frequency control range\n' },
        { 'height' => 50.18, 'color' => '00a000', 'legend' => 'normal range\n' },
        { 'height' => 50.02, 'color' => '00ff00', 'legend' => 'no frequency control necessary\n' },
        { 'height' => 50,    'color' => '0000ff' },
        { 'height' => 49.98, 'color' => '00ff00' },
        { 'height' => 49.82, 'color' => '00a000' },
        { 'height' => 49.8,  'color' => 'e0e000' },
        { 'height' => 49.0,  'color' => 'a04000' },
        { 'height' => 48.7,  'color' => 'd0d0d0' },
        { 'height' => 48.4,  'color' => 'a0a0a0' },
        { 'height' => 48.1,  'color' => '707070' },
        { 'height' => 47.5,  'color' => '000000' },
      ],
    },
    'power_w' => {
      'type' => 'GAUGE',
      'unit' => 'W', 'title' => 'Power',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'sum', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-60000:60000', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'power_w_demand' => {
      'type' => 'GAUGE',
      'unit' => 'W', 'title' => 'Power Demand',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'tot', 'color' => '000000', 'style' => 'LINE1', 'data_range' => '-60000:60000', 'minmax' => 'yes', },
        { 'row' => 'max', 'color' => 'a00000', 'style' => 'LINE2', 'data_range' => '-60000:60000', 'minmax' => 'no', 'hide' => 'true', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'power_va_demand' => {
      'type' => 'GAUGE',
      'unit' => 'VA', 'title' => 'Power Demand',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'tot', 'color' => '000000', 'style' => 'LINE1', 'data_range' => '-60000:60000', 'minmax' => 'yes', },
        { 'row' => 'max', 'color' => 'a00000', 'style' => 'LINE2', 'data_range' => '-60000:60000', 'minmax' => 'no', 'hide' => 'true', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'power_var' => {
      'type' => 'GAUGE',
      'unit' => 'Var', 'title' => 'Reactive Power',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'sum', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-60000:60000', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'power_va' => {
      'type' => 'GAUGE',
      'unit' => 'VA', 'title' => 'Apparent Power',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'sum', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-60000:60000', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'powerfactor' => {
      'type' => 'GAUGE',
      'unit' => '', 'title' => 'Power Factor',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'sum', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-1:1', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-1:1', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-1:1', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-1:1', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'phi' => {
      'type' => 'GAUGE',
      'unit' => '°', 'title' => 'Phase Angle',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'sum', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-360:360', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'energy_kvah_total' => {
      'type' => 'GAUGE',
      'unit' => 'kVAh', 'title' => 'Apparent Energy Total',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'tot',  'color' => '000000', 'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
      ],
    },
    'energy_kwh_import' => {
      'type' => 'GAUGE',
      'unit' => 'kWh', 'title' => 'Energy Import',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'tot', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-360:360', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
      ],
    },
    'energy_kwh_export' => {
      'type' => 'GAUGE',
      'unit' => 'kWh', 'title' => 'Energy Export',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'tot', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-360:360', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
      ],
    },
    'energy_kwh_total' => {
      'type' => 'GAUGE',
      'unit' => 'kWh', 'title' => 'Energy Total',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'tot', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-360:360', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
      ],
    },
    'energy_kvarh_import' => {
      'type' => 'GAUGE',
      'unit' => 'kVarh', 'title' => 'Reactive Energy Import',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'tot', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-360:360', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
      ],
    },
    'energy_kvarh_export' => {
      'type' => 'GAUGE',
      'unit' => 'kVarh', 'title' => 'Reactive Energy Export',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'tot', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-360:360', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
      ],
    },
    'energy_kvarh_total' => {
      'type' => 'GAUGE',
      'unit' => 'kVarh', 'title' => 'Reactive Energy Total',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'tot', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-360:360', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
      ],
    },
  },
);

generate_diagrams(\%graphs, @ARGV);

exit 0;



sub generate_diagrams {
  my $ref_graphs = shift;
  my @which = @_;

  @which = sort keys %{$ref_graphs->{'diagrams'}} if (! @which);

  my $maxlen_diagram = length((sort { length($b) <=> length($a) } @which)[0]);
  my $maxlen_timespan = length((sort { length($b) <=> length($a) } (keys %{$ref_graphs->{'times'}}))[0]);

  foreach my $diagram (@which)
  {
    print "generating: $diagram\n";

    my $ref_diagram = $ref_graphs->{'diagrams'}{$diagram};

    foreach my $timespan (@{$ref_diagram->{'times'}})
    {
      print "$diagram / $timespan\n";
      my $ref_timespan = $ref_graphs->{'times'}{$timespan};
      my $basename = $OUTPUT.'/'.$diagram.'-'.$timespan;

      my @params = (
        $OUTPUT.'/'.$diagram.'-'.$timespan.'.tmp.png',
        '--start', $ref_timespan->{'start'},
        '--width', $ref_graphs->{'base'}{'width'},
        '--height', $ref_graphs->{'base'}{'height'},
        '--lazy',
        '--slope-mode',
        '--alt-autoscale',
        '--alt-y-grid',
        '--font', 'TITLE:13',
        '--title', $ref_diagram->{'title'}.' ('.$ref_diagram->{'unit'}.') last '.$timespan,
      );

      push @params, ('--lower-limit', $ref_diagram->{'min'}) if exists ($ref_diagram->{'min'});
      push @params, ('--upper-limit', $ref_diagram->{'max'}) if exists ($ref_diagram->{'max'});


      my @def;
      my @vdef;
      my @graph = ( 'TEXTALIGN:left' );
      my $maxlen_row = length((sort { length($b->{'row'}) <=> length($a->{'row'}) } (@{$ref_diagram->{'graphs'}}))[0]{'row'});

      my $headings;
      my %consolidation = (
        'cur' => { 'heading' => '      Last', 'func' => 'LAST',    'func-vdef' => "LAST", },
        'min' => { 'heading' => '   Minimum', 'func' => "MIN",     'func-vdef' => "MINIMUM", },
        'avg' => { 'heading' => '   Average', 'func' => "AVERAGE", 'func-vdef' => "AVERAGE", },
        'max' => { 'heading' => '   Maximum', 'func' => "MAX",     'func-vdef' => "MAXIMUM", },
      );
      # 'consolidation' => { 'cur' => 'LAST', 'min' => 'MINIMUM', 'avg' => 'AVERAGE', 'max' => 'MAXIMUM', },
      for my $consol (@{$ref_timespan->{'func'}})
      {
        $headings .= $consolidation{$consol}{'heading'};
      }
      push @graph, 'COMMENT:'.(' ' x $maxlen_row).$headings.'\n';
      foreach my $ref_graph (@{$ref_diagram->{'graphs'}})
      {
        next if (exists $ref_graph->{'hide'});
        my $row = $ref_graph->{'row'};
        my @gprint;
        my $con = 0;
        for my $consol (@{$ref_timespan->{'func'}})
        {
          push @vdef, sprintf('VDEF:%s=%s,%s', $row.'_'.$consol.$consol, $row.'_'.$consol, $consolidation{$consol}{'func-vdef'});
          push @def, sprintf('DEF:%s=rrd/%s.rrd:%s:%s', $row.'_'.$consol, $diagram, $row, $consolidation{$consol}{'func'});
          push @gprint, sprintf('GPRINT:%s:%s', $row.'_'.$consol.$consol, '%6.2lf%S');
          $con++ if (($consol eq "min") or ($consol eq "max"));
        }
        if (($ref_graph->{'minmax'} eq 'yes') and ($con >= 2))
        {
          # min/max area: draw an invisible "*_min" and stack "*_max - *_min" onto it
          push @def, sprintf('CDEF:%s_diff=%s_max,%s_min,-', $row, $row, $row);
          push @graph, 'AREA:'.$row.'_min#ffffff';
          push @graph, 'AREA:'.$row.'_diff#'.brighten($ref_graph->{'color'}, 0.7).'::STACK';
        }
        push @graph, sprintf('%s:%s_avg#%s:%-'.$maxlen_row.'s', $ref_graph->{'style'}, $row, $ref_graph->{'color'}, $row);
        push @graph, @gprint, 'COMMENT:\n';
      }

      my @lines;
      foreach my $ref_line (@{$ref_diagram->{'lines'}})
      {
        my $line = sprintf('HRULE:%s#%s', $ref_line->{'height'}, $ref_line->{'color'});
        if (exists $ref_line->{'legend'})
        {
          $line .= ':'.$ref_line->{'legend'};
        }
        push @lines, $line; ## 'HRULE:'.$ref_line->{'height'}.'#'.$ref_line->{'color'};
      }

      print join("\n", @def, @vdef, @graph, "");
      my ($result_arr, $xsize, $ysize) = RRDs::graph(@params, @def, @vdef, @graph, @lines);
      my $error = RRDs::error();
      if ($error)
      {
        warn "ERROR: ".$error;
      }
      else
      {
        chmod 0644, $basename.'.tmp.png';
        rename $basename.'.tmp.png', $basename.'.png';
        printf("size: %".$maxlen_timespan."s = %8dx%4d\n", $timespan, $xsize, $ysize);
      }
      print "\n";
    }
    print "-----\n";
  }
}


sub brighten {
  my $color = shift;
  my $factor = shift;

  $color =~ /([\da-fA-F]{2})([\da-fA-F]{2})([\da-fA-F]{2})/;
  my ($r, $g, $b) = (hex($1), hex($2), hex($3));
  $color = sprintf("%02x%02x%02x", ($r + (255-$r) * $factor ), ($g + (255-$g) * $factor), ($b + (255-$b) * $factor));

  return $color;
}


#        rrdtool graph filename
#                --start seconds   --end seconds   --step seconds
#                --width pixels   --height pixels
#
#                --title string
#
#                --x-grid x-axis grid and label
#                --y-grid y-axis grid and label
#                --alt-y-grid
#                --vertical-label string
#                --force-rules-legend
#                --right-axis scale:shift
#                --right-axis-label label]
#                --right-axis-format format
#                --lazy
#                --logarithmic
#                --full-size-mode
#                --only-graph
#
#                --upper-limit <n>   --lower-limit <n>   --rigid
#                --alt-autoscale
#                --alt-autoscale-max
#                --no-legend
#                --daemon <address>
#
#                --font FONTTAG:size:font   --font-render-mode {normal,light,mono}   --font-smoothing-threshold size
#
#                --zoom factor
#
#                --graph-render-mode {normal,mono}
#                --tabwidth width
#                --slope-mode
#                --pango-markup
#                --no-gridfit
#                --units-exponent value
#                --units-length value
#                --imginfo printfstr
#                --imgformat PNG
#                --color COLORTAG#rrggbb[aa]
#                --border width
#                --watermark string
#
#                [DEF:vname=rrd:ds-name:CF]
#                [CDEF:vname=rpn-expression]
#
#                [VDEF:vdefname=rpn-expression]
#                [TEXTALIGN:{left|right|justified|center}]
#                [PRINT:vdefname:format]
#                [GPRINT:vdefname:format]
#                [COMMENT:text]
#
#                [SHIFT:vname:offset]
#                [TICK:vname#rrggbb[aa][:[fraction][:legend]]]
#                [HRULE:value#rrggbb[aa][:legend]]
#                [VRULE:value#rrggbb[aa][:legend]]
#
#                [LINE[width]:vname[#rrggbb[aa][:[legend][:STACK]]]]
#                [AREA:vname[#rrggbb[aa][:[legend][:STACK]]]]
#


