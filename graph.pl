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

my %GRAPHS = SDM630::get_graph_list();


generate_diagrams(@ARGV);

exit 0;



sub generate_diagrams {
  my @which = @_;

  @which = sort keys %{$GRAPHS{'diagrams'}} if (! @which);

  my $maxlen_diagram = length((sort { length($b) <=> length($a) } @which)[0]);
  my $maxlen_timespan = length((sort { length($b) <=> length($a) } (keys %{$GRAPHS{'times'}}))[0]);

  my $subdir = $OUTPUT;
  if (! -d $subdir) {
    mkdir $subdir or warn "WARNING: Failed to create output folder: $subdir\n";
  }

  foreach my $diagram (@which)
  {
    print "generating: $diagram\n";
    my $ref_diagram = $GRAPHS{'diagrams'}{$diagram};


    foreach my $timespan (@{$ref_diagram->{'times'}})
    {
      print "$diagram / $timespan\n";
      my $ref_timespan = $GRAPHS{'times'}{$timespan};
      my $basename = $subdir.'/'.$diagram.'-'.$timespan;

      my @params = (
        $basename.'.tmp.png',
        '--start', $ref_timespan->{'start'},
        '--width', $GRAPHS{'base'}{'width'},
        '--height', $GRAPHS{'base'}{'height'},
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


