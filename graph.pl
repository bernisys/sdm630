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
    { 'name' => 'hour',   'start' => -3600,      'step' =>    10, 'func' => ['AVG'] },
    { 'name' => '6h',     'start' => -6*3600,    'step' =>    10, 'func' => ['MAX', 'MIN', 'AVG'] },
    { 'name' => 'day',    'start' => -86400,     'step' =>    60, 'func' => ['MAX', 'MIN', 'AVG'] },
    { 'name' => 'week',   'start' => -7*86400,   'step' =>   600, 'func' => ['MAX', 'MIN', 'AVG'] },
    { 'name' => 'month',  'start' => -31*86400,  'step' =>  3600, 'func' => ['MAX', 'MIN', 'AVG'] },
    { 'name' => '3month', 'start' => -93*86400,  'step' =>  3600, 'func' => ['MAX', 'MIN', 'AVG'] },
    { 'name' => '6month', 'start' => -186*86400, 'step' =>  3600, 'func' => ['MAX', 'MIN', 'AVG'] },
    { 'name' => 'year',   'start' => -366*86400, 'step' => 43200, 'func' => ['MAX', 'MIN', 'AVG'] },
  ],
  'consolidation' => [
    { 'name' => 'cur', 'function' => 'LAST' },
    { 'name' => 'min', 'function' => 'MINIMUM' },
    { 'name' => 'avg', 'function' => 'AVERAGE' },
    { 'name' => 'max', 'function' => 'MAXIMUM' },
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
      'min' => 49.5, 'max' => 50.5,
      'graphs' => [
        { 'row' => 'Hz',  'color' => '000000', 'style' => 'LINE2' },
      ],
      'lines' => [
        { 'height' => 51.5,  'color' => '0000a0:solar power total disablement\n' },
        { 'height' => 50.2,  'color' => 'e0e000:frequency control range\n' },
        { 'height' => 50.18, 'color' => '00a000:normal range\n' },
        { 'height' => 50.02, 'color' => '00ff00:no frequency control necessary\n' },
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


sub generate_diagrams {
  my $ref_graphs = shift;

}


my $maxlen_diagram = length((sort { length($b) <=> length($a) } (keys %{$graphs{'diagrams'}}))[0]);
my $maxlen_timespan = length((sort { length($b->{'name'}) <=> length($a->{'name'}) } (@{$graphs{'times'}}))[0]->{'name'});

foreach my $diagram (sort keys %{$graphs{'diagrams'}})
{
  printf('%-'.$maxlen_diagram.'s  ', $diagram);

  my $ref_diagram = $graphs{'diagrams'}{$diagram};

  foreach my $ref_timespan (@{$graphs{'times'}})
  {
    my $timespan = $ref_timespan->{'name'};
    my $basename = $OUTPUT.'/'.$diagram.'-'.$timespan;

    my @params = (
      $OUTPUT.'/'.$diagram.'-'.$timespan.'.tmp.png',
      '--start', $ref_timespan->{'start'},
      '--width', $graphs{'base'}{'width'},
      '--height', $graphs{'base'}{'height'},
      '--lazy',
      '--alt-autoscale',
      '--font', 'TITLE:13',
      '--title', $ref_diagram->{'title'}.' ('.$ref_diagram->{'unit'}.') last '.$timespan,
      );

    push @params, ('--lower-limit', $ref_diagram->{'min'}) if exists ($ref_diagram->{'min'});
    push @params, ('--upper-limit', $ref_diagram->{'max'}) if exists ($ref_diagram->{'max'});

    my @graph = ( 'TEXTALIGN:left', 'COMMENT:                 Minimum   Average   Maximum\n');

    my @def;
    my @lines;
    foreach my $ref_graph (@{$ref_diagram->{'graphs'}})
    {
      my $row = $ref_graph->{'row'};
      push @def, sprintf('DEF:%s=rrd/%s.rrd:%s:%s', $row, $diagram, $row, 'AVERAGE');
      #
      # TODO: add definition for min/max values
      #
      push @graph, 'LINE2:'.$row.'#'.$ref_graph->{'color'}.':'.$row;
      for my $consol (@{$graphs{'consolidation'}})
      {
        my $name = $consol->{'name'};
        push @def, sprintf('VDEF:%s=%s,%s', $row.'_'.$name, $row, $consol->{'function'});
        push @graph, sprintf('GPRINT:%s:%s', $row.'_'.$name, '%6.2lf%S');
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
      printf('%'.$maxlen_timespan.'s = %8dx%4d  ', $timespan, $xsize, $ysize);
    }
  }
  print "\n";
}
