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

my %graphs = (
  'base' => {
    'width' => 600,
    'height' => 200,
  },
  'times' => {
    'hour'    => { 'start' => -3600,      'step' =>    10, 'func' => ['avg'] },
    '6h'      => { 'start' => -6*3600,    'step' =>    10, 'func' => ['max', 'min', 'avg'] },
    'day'     => { 'start' => -86400,     'step' =>    60, 'func' => ['max', 'min', 'avg'] },
    'week'    => { 'start' => -7*86400,   'step' =>   600, 'func' => ['max', 'min', 'avg'] },
    'month'   => { 'start' => -31*86400,  'step' =>  3600, 'func' => ['max', 'min', 'avg'] },
    '3month'  => { 'start' => -93*86400,  'step' =>  3600, 'func' => ['max', 'min', 'avg'] },
    '6month'  => { 'start' => -186*86400, 'step' =>  3600, 'func' => ['max', 'min', 'avg'] },
    'year'    => { 'start' => -366*86400, 'step' => 43200, 'func' => ['max', 'min', 'avg'] },
  },
  'consolidation' => {
    'cur' => 'LAST',
    'min' => 'MINIMUM',
    'avg' => 'AVERAGE',
    'max' => 'MAXIMUM',
  },
  'diagrams' => {
    'voltage' => {
      'unit' => 'V', 'title' => 'Voltage',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
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
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
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
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
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
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
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
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
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
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
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
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
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
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
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
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
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
      'times' => ['day', 'week', 'month', '3month', '6month', 'year'],
      'graphs' => [
        { 'row' => 'kVAh',  'color' => '000000', 'style' => 'LINE2' },
      ],
    },
    'energy_kwh' => {
      'unit' => 'kWh', 'title' => 'Energy',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year'],
      'graphs' => [
        { 'row' => 'in',  'color' => 'a00000', 'style' => 'LINE2' },
        { 'row' => 'out', 'color' => '00a000', 'style' => 'LINE2' },
      ],
    },
    'energy_kvarh' => {
      'unit' => 'kVarh', 'title' => 'Reactive Energy',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year'],
      'graphs' => [
        { 'row' => 'in',  'color' => 'a00000', 'style' => 'LINE2' },
        { 'row' => 'out', 'color' => '00a000', 'style' => 'LINE2' },
      ],
    },
  },
);


generate_diagrams(\%graphs);

exit 0;



sub generate_diagrams {
  my $ref_graphs = shift;

  my $maxlen_diagram = length((sort { length($b) <=> length($a) } (keys %{$ref_graphs->{'diagrams'}}))[0]);
  my $maxlen_timespan = length((sort { length($b) <=> length($a) } (keys %{$ref_graphs->{'times'}}))[0]);

  foreach my $diagram (sort keys %{$ref_graphs->{'diagrams'}})
  {
    printf('%-'.$maxlen_diagram.'s  ', $diagram);

    my $ref_diagram = $ref_graphs->{'diagrams'}{$diagram};

    foreach my $timespan (@{$ref_diagram->{'times'}})
    {
      my $ref_timespan = $ref_graphs->{'times'}{$timespan};
      my $basename = $OUTPUT.'/'.$diagram.'-'.$timespan;

      my @params = (
        $OUTPUT.'/'.$diagram.'-'.$timespan.'.tmp.png',
        '--start', $ref_timespan->{'start'},
        '--width', $ref_graphs->{'base'}{'width'},
        '--height', $ref_graphs->{'base'}{'height'},
        '--lazy',
        '--alt-autoscale',
        '--font', 'TITLE:13',
        '--title', $ref_diagram->{'title'}.' ('.$ref_diagram->{'unit'}.') last '.$timespan,
      );

      push @params, ('--lower-limit', $ref_diagram->{'min'}) if exists ($ref_diagram->{'min'});
      push @params, ('--upper-limit', $ref_diagram->{'max'}) if exists ($ref_diagram->{'max'});

      my @graph = ( 'TEXTALIGN:left', 'COMMENT:                 Minimum   Average   Maximum\n');

      my @def;
      my @vdef;
      my @lines;
      foreach my $ref_graph (@{$ref_diagram->{'graphs'}})
      {
        my $row = $ref_graph->{'row'};
        my @gprint;
        for my $consol (@{$ref_timespan->{'func'}})
        {
          my $function = $ref_graphs->{'consolidation'}{$consol};
          push @def, sprintf('DEF:%s=rrd/%s.rrd:%s:%s', $row.'_'.$consol, $diagram, $row, 'AVERAGE');
          push @vdef, sprintf('VDEF:%s=%s,%s', $row.'_'.$consol.$consol, $row.'_'.$consol, $function);
          push @gprint, sprintf('GPRINT:%s:%s', $row.'_'.$consol.$consol, '%6.2lf%S');
        }
        push @graph, 'LINE2:'.$row.'_avg#'.$ref_graph->{'color'}.':'.$row;
        push @graph, @gprint, 'COMMENT:\n';
      }
      foreach my $ref_line (@{$ref_diagram->{'lines'}})
      {
        push @lines, 'HRULE:'.$ref_line->{'height'}.'#'.$ref_line->{'color'};
      }

      print join("\n", @def, @vdef, @graph);
      my ($result_arr, $xsize, $ysize) = RRDs::graph(@params, @def, @vdef, @graph, @lines);
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
}

