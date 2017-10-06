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

# TODO:  find best brown value
# CD853F - seems okay for now, could be slightly darker though
# 720239 - a bit dark, hardly distinguishable from black in graphs
#
my %graphs = (
  'base' => {
    'width' => 600,
    'height' => 200,
  },
  'times' => {
    'hour'    => { 'start' => -3600,      'step' =>    10, 'func' => ['avg'] },
    '6h'      => { 'start' => -6*3600,    'step' =>    10, 'func' => ['min', 'avg', 'max'] },
    'day'     => { 'start' => -86400,     'step' =>    60, 'func' => ['min', 'avg', 'max'] },
    'week'    => { 'start' => -7*86400,   'step' =>   600, 'func' => ['min', 'avg', 'max'] },
    'month'   => { 'start' => -31*86400,  'step' =>  3600, 'func' => ['min', 'avg', 'max'] },
    '3month'  => { 'start' => -93*86400,  'step' =>  3600, 'func' => ['min', 'avg', 'max'] },
    '6month'  => { 'start' => -186*86400, 'step' =>  3600, 'func' => ['min', 'avg', 'max'] },
    'year'    => { 'start' => -366*86400, 'step' => 43200, 'func' => ['min', 'avg', 'max'] },
  },
  'consolidation' => {
    'cur' => 'LAST',
    'min' => 'MINIMUM',
    'avg' => 'AVERAGE',
    'max' => 'MAXIMUM',
  },
#  'rrd_param' => { 'charge'         => { 'type' => 'COUNTER', 'rows' => ['Ah:0:U', ], }, },
  'diagrams' => {
    'voltage' => {
      'type' => 'GAUGE',
      'unit' => 'V', 'title' => 'Voltage',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
      'graphs' => [
        { 'row' => 'avg', 'color' => 'ffff00', 'style' => 'LINE1', 'data_range' => '0:270', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => 'CD853F', 'style' => 'LINE2', 'data_range' => '0:270', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2', 'data_range' => '0:270', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2', 'data_range' => '0:270', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 230, 'color' => '0000ff' },
      ],
    },
    'current' => {
      'type' => 'GAUGE',
      'unit' => 'A', 'title' => 'Current',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
      'graphs' => [
        { 'row' => 'sum', 'color' => 'ff00ff', 'style' => 'LINE1', 'data_range' => '0:100', 'minmax' => 'yes', },
        { 'row' => 'avg', 'color' => 'ffff00', 'style' => 'LINE1', 'data_range' => '0:100', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => '720239', 'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
      ],
    },
    'frequency' => {
      'type' => 'GAUGE',
      'unit' => 'Hz', 'title' => 'Frequency',
      'min' => 49.5, 'max' => 50.5,
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
      'graphs' => [
        { 'row' => 'Hz',  'color' => '000000', 'style' => 'LINE1', 'data_range' => '45:55', 'minmax' => 'yes', },
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
      'type' => 'GAUGE',
      'unit' => 'W', 'title' => 'Power',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
      'graphs' => [
        { 'row' => 'sum', 'color' => 'ff00ff', 'style' => 'LINE1', 'data_range' => '-60000:60000', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => '720239', 'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'power_w_demand' => {
      'type' => 'GAUGE',
      'unit' => 'W', 'title' => 'Power Demand',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
      'graphs' => [
        { 'row' => 'tot', 'color' => '000000', 'style' => 'LINE1', 'data_range' => '0:60000', 'minmax' => 'yes', },
        { 'row' => 'max', 'color' => 'a00000', 'style' => 'LINE2', 'data_range' => '0:60000', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'power_var' => {
      'type' => 'GAUGE',
      'unit' => 'Var', 'title' => 'Reactive Power',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
      'graphs' => [
        { 'row' => 'sum', 'color' => 'ff00ff', 'style' => 'LINE1', 'data_range' => '-60000:60000', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => '720239', 'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'power_va' => {
      'type' => 'GAUGE',
      'unit' => 'VA', 'title' => 'Apparent Power',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
      'graphs' => [
        { 'row' => 'sum', 'color' => 'ff00ff', 'style' => 'LINE1', 'data_range' => '-60000:60000', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => '720239', 'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'powerfactor' => {
      'type' => 'GAUGE',
      'unit' => '', 'title' => 'Power Factor',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
      'graphs' => [
        { 'row' => 'sum', 'color' => 'ff00ff', 'style' => 'LINE1', 'data_range' => '-1:1', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => '720239', 'style' => 'LINE2', 'data_range' => '-1:1', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2', 'data_range' => '-1:1', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2', 'data_range' => '-1:1', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'phi' => {
      'type' => 'GAUGE',
      'unit' => '°', 'title' => 'Phase Angle',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year'],
      'graphs' => [
        { 'row' => 'sum', 'color' => 'ff00ff', 'style' => 'LINE1', 'data_range' => '-360:360', 'minmax' => 'yes', },
        { 'row' => 'L1',  'color' => '720239', 'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => '000000', 'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => '808080', 'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => '0000ff' },
      ],
    },
    'energy' => {
      'type' => 'GAUGE',
      'unit' => 'kVAh', 'title' => 'Apparent Energy',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year'],
      'graphs' => [
        { 'row' => 'kVAh',  'color' => '000000', 'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
      ],
    },
    'energy_kwh' => {
      'type' => 'GAUGE',
      'unit' => 'kWh', 'title' => 'Energy',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year'],
      'graphs' => [
        { 'row' => 'in',  'color' => 'a00000', 'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'out', 'color' => '00a000', 'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
      ],
    },
    'energy_kvarh' => {
      'type' => 'GAUGE',
      'unit' => 'kVarh', 'title' => 'Reactive Energy',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year'],
      'graphs' => [
        { 'row' => 'in',  'color' => 'a00000', 'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'out', 'color' => '00a000', 'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
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


      my @def;
      my @vdef;
      my $maxlen_row = length((sort { length($b->{'row'}) <=> length($a->{'row'}) } (@{$ref_diagram->{'graphs'}}))[0]{'row'});
      my @graph = ( 'TEXTALIGN:left', 'COMMENT:'.(' ' x $maxlen_row).'     Last    Minimum   Average   Maximum\n');
      foreach my $ref_graph (@{$ref_diagram->{'graphs'}})
      {
        my $row = $ref_graph->{'row'};
        my @gprint;
        my $con = 0;
        for my $consol (@{$ref_timespan->{'func'}})
        {
          my $function = $ref_graphs->{'consolidation'}{$consol};
          push @vdef, sprintf('VDEF:%s=%s,%s', $row.'_'.$consol.$consol, $row.'_'.$consol, $function);
          $function ='MIN' if ($function eq "MINIMUM");
          $function ='MAX' if ($function eq "MAXIMUM");
          push @def, sprintf('DEF:%s=rrd/%s.rrd:%s:%s', $row.'_'.$consol, $diagram, $row, $function);
          push @gprint, sprintf('GPRINT:%s:%s', $row.'_'.$consol.$consol, '%6.2lf%S');
          $con++ if (($consol eq "min") or ($consol eq "max"));
        }
        if (($ref_graph->{'minmax'} eq 'yes') and ($con >= 2))
        {
          # min/max area: draw an invisible "*_min" and stack "*_max - *_min" onto it
          push @def, sprintf('CDEF:%s_diff=%s_max,%s_min,-', $row, $row, $row);
          push @graph, 'AREA:'.$row.'_min#ffffff';
          push @graph, 'STACK:'.$row.'_diff#'.brighten($ref_graph->{'color'}, 0.7);
        }
        push @graph, sprintf('%s:%s_avg#%s:%-'.$maxlen_row.'s', $ref_graph->{'style'}, $row, $ref_graph->{'color'}, $row);
        push @graph, @gprint, 'COMMENT:\n';
      }

      my @lines;
      foreach my $ref_line (@{$ref_diagram->{'lines'}})
      {
        push @lines, 'HRULE:'.$ref_line->{'height'}.'#'.$ref_line->{'color'};
      }

      print join("\n", @def, @vdef, @graph, "", "");
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
        printf('%'.$maxlen_timespan.'s = %8dx%4d  ', $timespan, $xsize, $ysize);
      }
    }
    print "\n";
  }
}


sub brighten {
  my $color = shift;
  my $factor = shift;

  $color =~ /([\da-fA-F]{2})([\da-fA-F]{2})([\da-fA-F]{2})/;
  my ($r, $g, $b) = (hex($1), hex($2), hex($3));
  print join(", ", $r, $g, $b),"\n";
  $color = sprintf("%02x%02x%02x", ($r + (255-$r) * $factor ), ($g + (255-$g) * $factor), ($b + (255-$b) * $factor));

  return $color;
}
