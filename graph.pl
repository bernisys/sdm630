#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;

use RRDs;

my $OUTPUT='/home/user/berni/public_html/powermeter';

my %graphs = (
  'base' => {
    'width' => 600,
    'height' => 200,
  },
  'times' => [
    { 'name' => 'hour',  'start' => -3600,      'step' =>    10, 'func' => ['AVG'] },
    { 'name' => '6h',    'start' => -6*3600,    'step' =>    10, 'func' => ['MAX', 'MIN', 'AVG'] },
    { 'name' => 'day',   'start' => -86400,     'step' =>    60, 'func' => ['MAX', 'MIN', 'AVG'] },
    { 'name' => 'week',  'start' => -7*86400,   'step' =>   600, 'func' => ['MAX', 'MIN', 'AVG'] },
    { 'name' => 'month', 'start' => -31*86400,  'step' =>  3600, 'func' => ['MAX', 'MIN', 'AVG'] },
    { 'name' => 'year',  'start' => -366*86400, 'step' => 43200, 'func' => ['MAX', 'MIN', 'AVG'] },
  ],
  'consolidation' => [
    ['cur', 'LAST'],
    ['min', 'MINIMUM'],
    ['avg', 'AVERAGE'],
    ['max', 'MAXIMUM'],
  ],
  'diagrams' => {
    'voltage' => {
      'unit' => 'V', 'title' => 'Voltage',
      'graphs' => [
        { 'row' => 'L1',  'color' => '720239', 'style' => 'LINE2' },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2' },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2' },
        { 'row' => 'avg', 'color' => 'ffff00', 'style' => 'LINE1' },
      ],
      'lines' => [
        { 'height' => 230, 'color' => '0000ff' },
      ],
    },
    'current' => {
      'unit' => 'A', 'title' => 'Current',
      'graphs' => [
        { 'row' => 'L1',  'color' => '720239', 'style' => 'LINE2' },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2' },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2' },
        { 'row' => 'avg', 'color' => 'ffff00', 'style' => 'LINE1' },
        { 'row' => 'sum', 'color' => 'ff00ff', 'style' => 'LINE2' },
      ],
    },
    'frequency' => {
      'unit' => 'Hz', 'title' => 'Frequency',
      'graphs' => [
        { 'row' => 'Hz',  'color' => '000000', 'style' => 'LINE2' },
      ],
      'lines' => [
        { 'height' => 50, 'color' => '0000ff' },
      ],
    },
    'power_w' => {
      'unit' => 'W', 'title' => 'Power',
      'graphs' => [
        { 'row' => 'L1',  'color' => '720239', 'style' => 'LINE2' },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2' },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2' },
        { 'row' => 'sum', 'color' => 'ff00ff', 'style' => 'LINE2' },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'power_w_demand' => {
      'unit' => 'W', 'title' => 'Power Demand',
      'graphs' => [
        { 'row' => 'max', 'color' => 'a00000', 'style' => 'LINE2' },
        { 'row' => 'tot', 'color' => '000000', 'style' => 'LINE2' },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'power_var' => {
      'unit' => 'Var', 'title' => 'Reactive Power',
      'graphs' => [
        { 'row' => 'L1',  'color' => '720239', 'style' => 'LINE2' },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2' },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2' },
        { 'row' => 'sum', 'color' => 'ff00ff', 'style' => 'LINE2' },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'power_va' => {
      'unit' => 'VA', 'title' => 'Apparent Power',
      'graphs' => [
        { 'row' => 'L1',  'color' => '720239', 'style' => 'LINE2' },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2' },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2' },
        { 'row' => 'sum', 'color' => 'ff00ff', 'style' => 'LINE2' },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'powerfactor' => {
      'unit' => '', 'title' => 'Power Factor',
      'graphs' => [
        { 'row' => 'L1',  'color' => '720239', 'style' => 'LINE2' },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2' },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2' },
        { 'row' => 'sum', 'color' => 'ff00ff', 'style' => 'LINE2' },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'phi' => {
      'unit' => '°', 'title' => 'Phase Angle',
      'graphs' => [
        { 'row' => 'L1',  'color' => '720239', 'style' => 'LINE2' },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2' },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2' },
        { 'row' => 'sum', 'color' => 'ff00ff', 'style' => 'LINE2' },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'energy' => {
      'unit' => 'kVAh', 'title' => 'Apparent Energy',
      'graphs' => [
        { 'row' => 'kVAh',  'color' => '000000', 'style' => 'LINE2' },
      ],
    },
    'energy_kwh' => {
      'unit' => 'kWh', 'title' => 'Energy',
      'graphs' => [
        { 'row' => 'in',  'color' => 'a00000', 'style' => 'LINE2' },
        { 'row' => 'out', 'color' => '00a000', 'style' => 'LINE2' },
      ],
    },
    'energy_kvarh' => {
      'unit' => 'kVarh', 'title' => 'Reactive Energy',
      'graphs' => [
        { 'row' => 'in',  'color' => 'a00000', 'style' => 'LINE2' },
        { 'row' => 'out', 'color' => '00a000', 'style' => 'LINE2' },
      ],
    },
  },
);


my $maxlen_diagram = length((sort { length($b) <=> length($a) } (keys %{$graphs{'diagrams'}}))[0]);
my $maxlen_span = length((sort { length($b->{'name'}) <=> length($a->{'name'}) } (@{$graphs{'times'}}))[0]->{'name'});

foreach my $diagram (sort keys %{$graphs{'diagrams'}})
{
  printf('%-'.$maxlen_diagram.'s  ', $diagram);

  my $ref_diagram = $graphs{'diagrams'}{$diagram};

  foreach my $ref_span (@{$graphs{'times'}})
  {
    my $timespan = $ref_span->{'name'};
    my $basename = $OUTPUT.'/'.$diagram.'-'.$timespan;

    my @params = (
      $OUTPUT.'/'.$diagram.'-'.$timespan.'.tmp.png',
      '--start', $ref_span->{'start'},
      '--width', $graphs{'base'}{'width'},
      '--height', $graphs{'base'}{'height'},
      '--lazy',
      '--alt-autoscale',
      '--font', 'TITLE:13',
      '--title', $ref_diagram->{'title'}.' ('.$ref_diagram->{'unit'}.') last '.$timespan,
      );

    my @graph = ( 'TEXTALIGN:left', 'COMMENT:                 Minimum   Average   Maximum\n');

    my @def;
    my @lines;
    foreach my $ref_graph (@{$ref_diagram->{'graphs'}})
    {
      my $row = $ref_graph->{'row'};
      push @def, sprintf('DEF:%s=rrd/%s.rrd:%s:%s', $row, $diagram, $row, 'AVERAGE');
      push @graph, 'LINE2:'.$row.'#'.$ref_graph->{'color'}.':'.$row;
      for my $consol (@{$graphs{'consolidation'}})
      {
        push @def, sprintf('VDEF:%s=%s,%s', $row.'_'.$consol->[0], $row, $consol->[1]);
        push @graph, sprintf('GPRINT:%s:%s', $row.'_'.$consol->[0], '%6.2lf%S');
      }
      push @graph, 'COMMENT:\n';
    }
    foreach my $ref_line (@{$ref_diagram->{'lines'}})
    {
      push @lines, 'HRULE:'.$ref_line->{'height'}.'#'.$ref_line->{'color'};
    }

    my ($result_arr, $xsize, $ysize) = RRDs::graph(@params, @def, @graph, @lines);
    my $error = RRDs::error();
    if ($error)
    {
      warn $error;
    }
    else
    {
      chmod 0644, $basename.'.tmp.png';
      rename $basename.'.tmp.png', $basename.'.png';
      printf('%'.$maxlen_span.'s = %4dx%4d  ', $timespan, $xsize, $ysize);
    }
  }
  print "\n";
}

