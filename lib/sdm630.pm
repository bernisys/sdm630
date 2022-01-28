#!/usr/bin/perl
 
package SDM630;

use strict;
use warnings;
use diagnostics;
 
$| = 1;
 
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent = 1;
 
use Device::Modbus::TCP::Client;
use RRDs;

my $DEBUG = 0;

my @RRD_RESOLUTIONS = ( '12H@10S', '14d@1M', '4w@10M', '6m@1H', '5y@12H', );
my $RRD_STEP = 10; # 10 seconds per primary data point


# TODO:  find best brown value for L1
# CD853F - seems okay for now, could be slightly darker though
# 720239 - a bit dark, hardly distinguishable from black in graphs

my %COLORS = (
  'L1'  => 'CD853F', # EU convention: L1 insulation color is brown
  'L2'  => '000000', # EU convention: L2 insulation color is black
  'L3'  => '808080', # EU convention: L3 insulation color is gray
  'N'   => '0000ff', # EU convention: N insulation color is blue
  'avg' => '00ff00',
  'max' => 'a00000',
  'sum' => '00a0a0',
  'in'  => 'a00000', # red for input from public grid
  'out' => '00a000', # green for output to public grid
  'default' => '000000', # default color black
  'normal'  => '0000ff', # default color for normal values
);


my %GRAPHS = (
  'base' => {
    'width' => 600,
    'height' => 200,
  },
  'time_order' => [ 'hour', '6h', 'day', 'week', 'month', '3month', '6month', 'year', '5year', ],
  'times' => {
    'hour'    => { 'heading' => '1 hour',   'start' => -3600,        'step' =>    10, 'func' => ['avg'] },
    '6h'      => { 'heading' => '6 hours',  'start' => -6*3600,      'step' =>    10, 'func' => ['min', 'avg', 'max'] },
    'day'     => { 'heading' => '1 day',    'start' => -86400,       'step' =>    60, 'func' => ['min', 'avg', 'max'] },
    'week'    => { 'heading' => '1 week',   'start' => -7*86400,     'step' =>   600, 'func' => ['min', 'avg', 'max'] },
    'month'   => { 'heading' => '1 month',  'start' => -31*86400,    'step' =>  3600, 'func' => ['min', 'avg', 'max'] },
    '3month'  => { 'heading' => '3 months', 'start' => -93*86400,    'step' =>  3600, 'func' => ['min', 'avg', 'max'] },
    '6month'  => { 'heading' => '6 months', 'start' => -186*86400,   'step' =>  3600, 'func' => ['min', 'avg', 'max'] },
    'year'    => { 'heading' => '1 year',   'start' => -366*86400,   'step' => 43200, 'func' => ['min', 'avg', 'max'] },
    '5year'   => { 'heading' => '5 years',  'start' => -5*366*86400, 'step' => 43200, 'func' => ['min', 'avg', 'max'] },
  },
  'sections' => [
    { 'heading' => 'Phase parameters', 'graphs' => [ 'frequency', 'voltage_ln', 'voltage_ll', 'current', 'current_demand', 'current_demandmax', 'phi', ], },
    { 'heading' => 'Power',            'graphs' => [ 'power_w', 'power_var', 'power_va', 'power_w_demand', 'power_va_demand', 'powerfactor', ], },
    { 'heading' => 'Energy',           'graphs' => [ 'energy_kwh_import', 'energy_kwh_export', 'energy_kwh_total', 'energy_kvah_total', 'energy_kvarh_import', 'energy_kvarh_export', 'energy_kvarh_total', ], },
  ],
  'registers' => {
    'holding' => {
      '40003', => { 'name' => 'Demand period', 'default' =>   60,
        'availability' => {
          'all'    => { 'values' => { '0'  => 'immediate', '5'  => '5 minutes', '8'  => '8 minutes', '10' => '10 minutes', '15' => '15 minutes', '20' => '20 minutes', '30' => '30 minutes', '60' => '60 minutes', }, },
        },
      },
      '40011', => { 'name' => 'System type', 'default' =>    3,
        'availability' => {
          'all'    => { 'values' => { '3' => '3p4w', '2' => '3p3w', '1' => '1p2w', }, },
        },
      },
      '40013', => { 'name' => 'Pulse 1 width', 'default' =>  100,
        'availability' => {
          'all'    => { 'values' => { '60'  => '60 ms', '100' => '100 ms', '200' => '200 ms', }, },
        },
      },
      '40015' => { 'name' => 'password lock', 'default' => '1',
        'availability' => {
          'SDM630' => { 'values' => { '0' => 'locked', '1' => 'unlocked', }, },
        },
      },
      '40019', => { 'name' => 'Parity / Stop', 'default' =>    0,
        'availability' => {
          'all'    => { 'values' => { '0' => 'no parity, 1 stop', '1' => 'even parity, 1 stop', '2' => 'odd parity, 1 stop', '3' => 'no parity, 2 stop', }, },
        },
      },
      '40021', => { 'name' => 'Modbus address', 'default' =>    1,
        'availability' => {
          'all'    => { 'range'  => { 'min' => 1, 'max' => 247, }, },
        },
      },
      '40023', => { 'name' => 'Pulse 1 rate', 'default' =>    0,
        'availability' => {
          'SDM630' => { 'values' => { '0' => '2.5Wh (400/kWh)', '1' => '10Wh  (100/kWh)', '2' => '100Wh (10/kWh)', '3' => '1kWh  (1/kWh)', '4' => '10kWh', '5' => '100kWh', }, },
          'SDM72'  => { 'values' => { '0' => '1Wh (1000/kWh)',  '1' => '10Wh  (100/kWh)', '2' => '100Wh (10/kWh)', '3' => '1kWh  (1/kWh)', }, },
        },
      },
      '40025', => { 'name' => 'Password', 'default' => 1000,
        'availability' => {
          'all'    => { 'range'  => { 'min' => '0000', 'max' => '9999', }, },
        },
      },
      '40029', => { 'name' => 'Baud rate', 'default' =>    2,
        'availability' => {
          'SDM630' => { 'values' => { '0' => '2400', '1' => '4800', '2' => '9600', '3' => '19200', '4' => '38400', }, },
          'SDM72'  => { 'values' => { '0' => '2400', '1' => '4800', '2' => '9600', '5' => '1200', }, },
        },
      },
      '40059', => { 'name' => 'Scroll time', 'default' =>    3,
        'availability' => {
          'SDM72'  => { 'range'  => { 'min' => 0, 'max' => 60, }, 'values' => { '0' => 'static display' }, },
        },
      },
      '40061', => { 'name' => 'backlight time', 'default' =>    0,
        'availability' => {
          'SDM72'  => { 'range'  => { 'min' => 0, 'max' => '120', }, },
        },
      },
      '40087', => { 'name' => 'Pulse 1 energy type', 'default' =>    0,
        'availability' => {
          'SDM630' => { 'values' =>{ '1' => 'import active', '2' => 'total active', '4' => 'export active', '5' => 'import reactive', '6' => 'total reactive', '8' => 'export reactive', }, },
        },
      },
      '46157', => { 'name' => 'reset', 'default' =>    0,
        'availability' => {
          'all' => { 'values' =>{ '0' => 'reset MAX demand', }, },
        },
      },
    },
  },
  'diagrams' => {
    'voltage_ln' => {
      'type' => 'GAUGE',
      'unit' => 'V', 'title' => 'Voltage L-N',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:270', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:270', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:270', 'minmax' => 'no', },
        { 'row' => 'avg', 'color' => $COLORS{'avg'}, 'style' => 'LINE1', 'data_range' => '0:270', 'minmax' => 'yes', },
      ],
      'lines' => [
        { 'height' => 230, 'color' => $COLORS{'normal'} },
      ],
      'availability' => {
        'SDM72' => 1,
        'SDM630' => 1,
      }
    },
    'voltage_ll' => {
      'type' => 'GAUGE',
      'unit' => 'V', 'title' => 'Voltage L-L',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1L2', 'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:430', 'minmax' => 'no', },
        { 'row' => 'L2L3', 'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:430', 'minmax' => 'no', },
        { 'row' => 'L3L1', 'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:430', 'minmax' => 'no', },
        { 'row' => 'avg',  'color' => $COLORS{'avg'}, 'style' => 'LINE1', 'data_range' => '0:430', 'minmax' => 'yes', },
      ],
      'lines' => [
        { 'height' => 400, 'color' => $COLORS{'normal'} },
      ],
      'availability' => {
        'SDM72' => 1,
        'SDM630' => 1,
      }
    },
    'current' => {
      'type' => 'GAUGE',
      'unit' => 'A', 'title' => 'Current',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'N',   'color' => $COLORS{'N'},   'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'avg', 'color' => $COLORS{'avg'}, 'style' => 'LINE1', 'data_range' => '0:100', 'minmax' => 'yes', },
        { 'row' => 'sum', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '0:100', 'minmax' => 'yes', },
      ],
      'availability' => {
        'SDM72' => 1,
        'SDM630' => 1,
      }
    },
    'current_demand' => {
      'type' => 'GAUGE',
      'unit' => 'A', 'title' => 'Current demand',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',   'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'L2',   'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        { 'row' => 'L3',   'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        ## TODO: test
        #{ 'row' => 'N',    'color' => $COLORS{'N'},   'style' => 'LINE2', 'data_range' => '0:100', 'minmax' => 'no', },
        #{ 'row' => 'Nmax', 'color' => $COLORS{'N'},   'style' => 'LINE1', 'data_range' => '0:100', 'minmax' => 'no', },
      ],
      'availability' => {
        'SDM630' => 1,
      }
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
      'availability' => {
        'SDM630' => 1,
      }
    },
    'frequency' => {
      'type' => 'GAUGE',
      'unit' => 'Hz', 'title' => 'Frequency',
      'min' => 49.9, 'max' => 50.1,
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'Hz',  'color' => $COLORS{'default'}, 'style' => 'LINE1', 'data_range' => '30:70', 'minmax' => 'yes', },
      ],
      'lines' => [
        { 'height' => 51.5,  'color' => '0000f0', 'legend' => 'solar power total disablement\n' },
        { 'height' => 50.2,  'color' => 'e0e000', 'legend' => 'frequency control range\n' },
        { 'height' => 50.18, 'color' => '00a000', 'legend' => 'normal range\n' },
        { 'height' => 50.02, 'color' => '00ff00', 'legend' => 'no frequency control necessary\n' },
        { 'height' => 50,    'color' => '0000ff', },
        { 'height' => 49.98, 'color' => '00ff00', },
        { 'height' => 49.82, 'color' => '00a000', },
        { 'height' => 49.8,  'color' => 'e0e000', 'legend' => 'activate power reserves, disable storage pumps\n', },
        { 'height' => 49.2,  'color' => 'e0e000', 'legend' => 'immediate disablement of storage pumps\n', },
        { 'height' => 49.0,  'color' => 'a04000', 'legend' => 'load reduction 10..15%\n', },
        { 'height' => 48.7,  'color' => 'd0d0d0', 'legend' => 'load reduction 20..30%\n', },
        { 'height' => 48.4,  'color' => 'a0a0a0', 'legend' => 'load reduction 35..50%\n', },
        { 'height' => 48.1,  'color' => '707070', 'legend' => 'load reduction 50..70%\n', },
        { 'height' => 47.5,  'color' => '000000', 'legend' => 'blackout\n', },
      ],
      'availability' => {
        'SDM72' => 1,
        'SDM630' => 1,
      }
    },
    'power_w' => {
      'type' => 'GAUGE',
      'unit' => 'W', 'title' => 'Power',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'sum', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-60000:60000', 'minmax' => 'yes', },
        { 'row' => 'imp', 'color' => $COLORS{'in'},  'Style' => 'LINE1', 'data_range' => '-60000:60000', 'minmax' => 'no', 'hide' => 'true', },
        { 'row' => 'exp', 'color' => $COLORS{'out'}, 'style' => 'LINE1', 'data_range' => '-60000:60000', 'minmax' => 'no', 'hide' => 'true', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => $COLORS{'normal'} },
      ],
      'availability' => {
        'SDM72' => 1,
        'SDM630' => 1,
      }
    },
    'power_w_demand' => {
      'type' => 'GAUGE',
      'unit' => 'W', 'title' => 'Power Demand',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'max', 'color' => $COLORS{'max'},     'style' => 'LINE2', 'data_range' => '0:60000', 'minmax' => 'no', 'hide' => 'true', },
        { 'row' => 'tot', 'color' => $COLORS{'default'}, 'style' => 'LINE1', 'data_range' => '0:60000', 'minmax' => 'yes', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => $COLORS{'normal'} },
      ],
      'availability' => {
        'SDM630' => 1,
      }
    },
    'power_va_demand' => {
      'type' => 'GAUGE',
      'unit' => 'VA', 'title' => 'Power Demand',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'max', 'color' => $COLORS{'max'},     'style' => 'LINE2', 'data_range' => '0:60000', 'minmax' => 'no', 'hide' => 'true', },
        { 'row' => 'tot', 'color' => $COLORS{'default'}, 'style' => 'LINE1', 'data_range' => '0:60000', 'minmax' => 'yes', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => $COLORS{'normal'} },
      ],
      'availability' => {
        'SDM630' => 1,
      }
    },
    'power_var' => {
      'type' => 'GAUGE',
      'unit' => 'Var', 'title' => 'Reactive Power',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'sum', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-60000:60000', 'minmax' => 'yes', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => $COLORS{'normal'} },
      ],
      'availability' => {
        'SDM72' => 1,
        'SDM630' => 1,
      }
    },
    'power_va' => {
      'type' => 'GAUGE',
      'unit' => 'VA', 'title' => 'Apparent Power',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-20000:20000', 'minmax' => 'no', },
        { 'row' => 'sum', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-60000:60000', 'minmax' => 'yes', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => $COLORS{'normal'} },
      ],
      'availability' => {
        'SDM72' => 1,
        'SDM630' => 1,
      }
    },
    'powerfactor' => {
      'type' => 'GAUGE',
      'unit' => '', 'title' => 'Power Factor',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-1:1', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-1:1', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-1:1', 'minmax' => 'no', },
        { 'row' => 'sum', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-1:1', 'minmax' => 'yes', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => $COLORS{'normal'} },
      ],
      'availability' => {
        'SDM72' => 1,
        'SDM630' => 1,
      }
    },
    'phi' => {
      'type' => 'GAUGE',
      'unit' => '°', 'title' => 'Phase Angle',
      'times' => ['hour', '6h', 'day', 'week', 'month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '-360:360', 'minmax' => 'no', },
        { 'row' => 'sum', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '-360:360', 'minmax' => 'yes', },
      ],
      'lines' => [
        { 'height' => 0, 'color' => $COLORS{'normal'} },
      ],
      'availability' => {
        'SDM630' => 1,
      }
    },
    'energy_kvah_total' => {
      'type' => 'GAUGE',
      'unit' => 'kVAh', 'title' => 'Apparent Energy Total',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'tot',  'color' => $COLORS{'default'}, 'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
      ],
      'availability' => {
        'SDM630' => 1,
      }
    },
    'energy_kwh_import' => {
      'type' => 'GAUGE',
      'unit' => 'kWh', 'title' => 'Energy Import',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'tot', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '0:U', 'minmax' => 'yes', },
      ],
      'availability' => {
        'SDM72' => { 'tot' => 1, },
        'SDM630' => { 'tot' => 1, 'L1' => 1, 'L2' => 1, 'L3' => 1, },
      }
    },
    'energy_kwh_export' => {
      'type' => 'GAUGE',
      'unit' => 'kWh', 'title' => 'Energy Export',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'tot', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '0:U', 'minmax' => 'yes', },
      ],
      'availability' => {
        'SDM72' => { 'tot' => 1, },
        'SDM630' => { 'tot' => 1, 'L1' => 1, 'L2' => 1, 'L3' => 1, },
      }
    },
    'energy_kwh_total' => {
      'type' => 'GAUGE',
      'unit' => 'kWh', 'title' => 'Energy Total',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'tot', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '0:U', 'minmax' => 'yes', },
      ],
      'availability' => {
        'SDM72' => { 'tot' => 1, },
        'SDM630' => { 'tot' => 1, 'L1' => 1, 'L2' => 1, 'L3' => 1, },
      }
    },
    'energy_kwh_periodic' => {
      'type' => 'GAUGE',
      'unit' => 'kWh', 'title' => 'Energy Total',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'imp', 'color' => $COLORS{'in'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'exp', 'color' => $COLORS{'out'}, 'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'tot', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '0:U', 'minmax' => 'yes', },
      ],
      'availability' => {
        'SDM72' => { 'tot' => 1, },
        'SDM630' => { 'tot' => 1, 'imp' => 1, 'exp' => 1, },
      }
    },
    'energy_kvarh_import' => {
      'type' => 'GAUGE',
      'unit' => 'kVarh', 'title' => 'Reactive Energy Import',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'tot', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '0:U', 'minmax' => 'yes', },
      ],
      'availability' => {
        'SDM630' => 1,
      }
    },
    'energy_kvarh_export' => {
      'type' => 'GAUGE',
      'unit' => 'kVarh', 'title' => 'Reactive Energy Export',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'tot', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '0:U', 'minmax' => 'yes', },
      ],
      'availability' => {
        'SDM630' => 1,
      }
    },
    'energy_kvarh_total' => {
      'type' => 'GAUGE',
      'unit' => 'kVarh', 'title' => 'Reactive Energy Total',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
        { 'row' => 'tot', 'color' => $COLORS{'sum'}, 'style' => 'LINE1', 'data_range' => '0:U', 'minmax' => 'yes', },
      ],
      'availability' => {
        'SDM72' => { 'tot' => 1, },
        'SDM630' => { 'tot' => 1, 'L1' => 1, 'L2' => 1, 'L3' => 1, },
      }
    },
    'thd_voltage_ln' => {
      'type' => 'GAUGE',
      'unit' => '%', 'title' => 'Voltage distortion',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:110', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:110', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:110', 'minmax' => 'no', },
        { 'row' => 'avg', 'color' => $COLORS{'avg'}, 'style' => 'LINE1', 'data_range' => '0:110', 'minmax' => 'yes', },
      ],
      'availability' => {
        'SDM630' => 1,
      }
    },
    'thd_current' => {
      'type' => 'GAUGE',
      'unit' => '%', 'title' => 'Current distortion',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'L1',  'color' => $COLORS{'L1'},  'style' => 'LINE2', 'data_range' => '0:110', 'minmax' => 'no', },
        { 'row' => 'L2',  'color' => $COLORS{'L2'},  'style' => 'LINE2', 'data_range' => '0:110', 'minmax' => 'no', },
        { 'row' => 'L3',  'color' => $COLORS{'L3'},  'style' => 'LINE2', 'data_range' => '0:110', 'minmax' => 'no', },
        { 'row' => 'avg', 'color' => $COLORS{'avg'}, 'style' => 'LINE1', 'data_range' => '0:110', 'minmax' => 'yes', },
      ],
      'availability' => {
        'SDM630' => 1,
      }
    },
    'charge' => {
      'type' => 'GAUGE',
      'unit' => 'Ah', 'title' => 'Charge',
      'times' => ['day', 'week', 'month', '3month', '6month', 'year', '5year', ],
      'graphs' => [
        { 'row' => 'Ah',  'color' => $COLORS{'default'}, 'style' => 'LINE2', 'data_range' => '0:U', 'minmax' => 'no', },
      ],
      'availability' => {
        'SDM630' => 1,
      }
    },
  },
);



sub retrieve_all {
  my $ref_client = shift;
  my $unit = shift;
  my $type = shift;

  $unit = 1 if !defined $unit;
  $type = "SDM630" if !defined $type;

  my $ref_values = {};

  if ($type eq "SDM630") {
    # retrieve all 3-phase reated values
    SDM630::retrieve($ref_client, $unit,   0, 3, [
        'Voltage_LN', 'Current', 'Power_W', 'Power_VA', 'Power_Var', 'PowerFactor', 'phi'
      ], $ref_values);

    SDM630::retrieve($ref_client, $unit, 117, 3, [
        'THD_Voltage_LN', 'THD_Current',
      ], $ref_values);

    SDM630::retrieve($ref_client, $unit, 129, 3, [
        'Current_demand', 'Current_demandmax',
      ], $ref_values);

    SDM630::retrieve($ref_client, $unit, 173, 3, [
        'Energy_kWh_Import', 'Energy_kWh_Export', 'Energy_kWh_Total', 'Energy_kVarh_Import', 'Energy_kVarh_Export', 'Energy_kVarh_Total',
      ], $ref_values);

    # add inter-phase voltages
    SDM630::retrieve($ref_client, $unit, 100, 1, [
        'Voltage_LL_L1L2', 'Voltage_LL_L2L3', 'Voltage_LL_L3L1', 'Voltage_LL_avg',
      ], $ref_values);

    # then add all single values (sums, averages, energies, ... not phase-related)
    SDM630::retrieve($ref_client, $unit,  21, 1, [
        'Voltage_LN_avg', '_22', 'Current_avg', 'Current_sum', '_25', 'Power_W_sum', '_27', 'Power_VA_sum', '_29',
        'Power_Var_sum', 'PowerFactor_sum', '_32', 'phi_sum', '_34', 'Frequency_Hz', 'Energy_kWh_Import_tot', 'Energy_kWh_Export_tot', 'Energy_kVarh_Import_tot', 'Energy_kVarh_Export_tot',
        'Energy_kVAh_Total_tot', 'Charge_Ah', 'Power_W_demand_tot', 'Power_W_demand_max',
      ], $ref_values);

    SDM630::retrieve($ref_client, $unit,  50, 1, [
        'Power_VA_demand_tot', 'Power_VA_demand_max', # TODO: 'Current_demand_N', 'Curent_demand_Nmax',
      ], $ref_values);

    SDM630::retrieve($ref_client, $unit, 112, 1, [
        'Current_N',
      ], $ref_values);

    SDM630::retrieve($ref_client, $unit, 124, 1, [
        'THD_Voltage_LN_avg', 'THD_Current_avg',
      ], $ref_values);

# TODO: this value seems to be unknown by my SDM630 ...
#    SDM630::retrieve($ref_client, $unit, 167, 1, [
#        'THD_Voltage_LL_L1L2', 'THD_Voltage_LL_L2L3', 'THD_Voltage_LL_L3L1', 'THD_Voltage_LL_avg',
#      ], $ref_values);

    SDM630::retrieve($ref_client, $unit, 171, 1, [
        'Energy_kWh_Total_tot', 'Energy_kVarh_Total_tot',
      ], $ref_values);

  } elsif ($type eq "SDM72") {
    # retrieve all 3-phase reated values
    SDM630::retrieve($ref_client, $unit,   0, 3, [
        'Voltage_LN', 'Current', 'Power_W', 'Power_VA', 'Power_Var', 'PowerFactor',
      ], $ref_values);

    # then add all single values
    SDM630::retrieve($ref_client, $unit,  21, 1, [
        'Voltage_LN_avg', '_22', 'Current_avg', 'Current_sum', '_25', 'Power_W_sum', '_27', 'Power_VA_sum', '_29',
        'Power_Var_sum', 'PowerFactor_sum', '_32', '_33', '_34', 'Frequency_Hz', 'Energy_kWh_Import_tot', 'Energy_kWh_Export_tot',
      ], $ref_values);
    SDM630::retrieve($ref_client, $unit, 100, 1, [
        'Voltage_LL_L1L2', 'Voltage_LL_L2L3', 'Voltage_LL_L3L1', 'Voltage_LL_avg',
      ], $ref_values);

    SDM630::retrieve($ref_client, $unit, 112, 1, [
        'Current_N',
      ], $ref_values);

    SDM630::retrieve($ref_client, $unit, 171, 1, [
        'Energy_kWh_Total_tot', 'Energy_kVarh_Total_tot',
      ], $ref_values);

    # preiodical counters (resettable)
    SDM630::retrieve($ref_client, $unit, 192, 1, [
        'Energy_kWh_periodic_tot', '_193', 'Energy_kWh_periodic_imp', 'Energy_kWh_periodic_exp',
      ], $ref_values);

    SDM630::retrieve($ref_client, $unit, 640, 1, [
        'Power_W_imp',
        'Power_W_exp',
      ], $ref_values);

  }

#  189 L1 total kvarh (3) kvarh
  return $ref_values;
}


sub retrieve_all_dummy {

  return {
    'Charge'      => { 'Ah'   => '124819.89', },
    'Frequency'   => { 'Hz'   =>    '50.01', },

    'phi'         => { 'L1'   =>   '-25.37', 'L2'   =>   '-10.00', 'L3'   =>   '-22.53', 'sum' =>    '-14.27', },
    'PowerFactor' => { 'L1'   =>     '0.90', 'L2'   =>     '0.98', 'L3'   =>     '0.92', 'sum' =>     '0.96', },

    'Voltage'     => {
      'L'         => { 'L1'   =>   '233.38', 'L2'   =>   '231.02', 'L3'   =>   '234.39', 'avg' =>    '232.93', },
      'LL'        => { 'L1L2' =>   '402.19', 'L2L3' =>   '403.06', 'L3L1' =>   '405.11', 'avg' =>    '403.45', },
    },

    'Current'     => { 'L1'   =>     '0.83', 'L2'   =>     '4.49', 'L3'   =>     '1.18', 'N'   =>     '3.52', 'avg' => '2.29', 'sum' => '6.89',
      'demand'    => { 'L1'   =>     '0.85', 'L2'   =>     '4.40', 'L3'   =>     '1.25', },
      'demandmax' => { 'L1'   =>  '8761.48', 'L2'   =>    '49.67', 'L3'   =>   '988.22', },
    },

    'Energy'      => {
      'kVAh'      => {
        'Total'   => { 'tot'  => '52404.85', },
      },
      'kVarh'     => {
        'Export'  => { 'L1'   =>  '1599.09', 'L2'   =>  '3550.82', 'L3'   =>  '3244.10', 'tot' =>  '8394.02', },
        'Import'  => { 'L1'   =>   '561.52', 'L2'   =>  '1722.45', 'L3'   =>   '369.44', 'tot' =>  '2653.42', },
        'Total'   => { 'L1'   =>  '2160.61', 'L2'   =>  '5273.27', 'L3'   =>  '3613.55', 'tot' => '11047.44', },
      },
      'kWh'       => {
        'Export'  => { 'L1'   =>  '4848.65', 'L2'   =>  '2779.63', 'L3'   =>  '4963.93', 'tot' => '12592.22', },
        'Import'  => { 'L1'   =>  '8847.36', 'L2'   => '20972.09', 'L3'   =>  '8815.47', 'tot' => '38634.93', },
        'Total'   => { 'L1'   => '13696.02', 'L2'   => '23751.73', 'L3'   => '13779.41', 'tot' => '51227.16', },
      },
    },

    'Power'       => {
      'VA'        => { 'L1'   =>   '195.33', 'L2'   =>  '1039.31', 'L3'   =>   '277.97', 'sum' =>  '1512.62',
        'demand'  => { 'max'  => '11836.64', 'tot'  =>  '1512.20', },
      },
      'Var'       => { 'L1'   =>   '-83.69', 'L2'   =>  '-180.48', 'L3'   =>  '-106.53', 'sum' =>  '-370.71', },
      'W'         => { 'L1'   =>   '176.50', 'L2'   =>  '1023.52', 'L3'   =>   '256.74', 'sum' =>  '1456.77',
        'demand'  => { 'max'  => '11795.17', 'tot'  =>  '1439.35', },
      },
    },

    'THD'         => {
      'Current'   => { 'L1'   =>    '45.18', 'L2'   =>    '27.25', 'L3'   =>    '44.21', 'avg' =>    '38.88', },
      'Voltage'   => {
        'L'       => { 'L1'   =>     '4.41', 'L2'   =>     '3.42', 'L3'   =>     '3.42', 'avg' =>     '3.92', },
        'LL'      => { 'L1L2' =>     '0.00', 'L2L3' =>     '0.00', 'L3L1' =>     '0.00', 'avg' =>     '0.00', },
      },
    },
  };
}


sub retrieve {
  my $ref_client = shift;
  my $unit = shift;
  my $start = shift;
  my $grouping = shift;
  my $ref_prefixes = shift;
  my $ref_readings = shift;

  my $count = scalar(@{$ref_prefixes}) * $grouping;

  my $ref_req = $ref_client->read_input_registers(unit => $unit, address => 2 * $start, quantity => 2 * $count);
  $ref_client->send_request($ref_req);
  my $ref_response = $ref_client->receive_response;
  if ($DEBUG > 3) {
    print Dumper($ref_response);
  }
  return undef if ! $ref_response->success;

  my $ref_values = $ref_response->values;
  if ($DEBUG > 2) {
    foreach my $value (@{$ref_values}) {
      printf("  %08x %d\n", $value, $value);
    }
  }

  for (my $index = 0; $index < $count ; $index++)
  {
    my $b32 = ($ref_values->[2*$index])*65536 + $ref_values->[2*$index+1];
    my $hex = sprintf('%x', $b32);
    my $float = unpack('f', reverse pack('H*', $hex));
    $float = 0 if !defined $float;

    my $item = $ref_prefixes->[int($index/$grouping)].(($grouping > 1) ? '_L'.(($index % $grouping) + 1) : '');
    next if $item =~ /^_/;

    my @subitems = split(/_/, $item);
    add_to_hash($ref_readings, $float, \@subitems);
  }
  if ($DEBUG > 0) {
    print Dumper($ref_readings);
  }
}

sub add_to_hash {
  my $ref_hash = shift;
  my $value = shift;
  my $ref_path = shift;

  my $ref_insert = $ref_hash;
  my $count = 0;
  foreach my $subitem (@{$ref_path})
  {
    $count++;
    if ($count == scalar(@{$ref_path}))
    {
        $ref_insert->{$subitem} = $value;
    }
    else
    {
      if (!exists $ref_insert->{$subitem})
      {
        $ref_insert->{$subitem} = {};
      }
    }
    $ref_insert = $ref_insert->{$subitem};
  }
}



sub output_values {
  my $ref_values = shift;
  my $path = shift || '';

  my @lines;
  my $string = '';
  foreach my $key (sort keys %{$ref_values})
  {
    if (ref $ref_values->{$key} eq 'HASH')
    {
      # descend into sub hash
      push @lines, output_values($ref_values->{$key}, $path.' '.$key);
    }
    else
    {
      # only append a value
      $string .= sprintf('%5s: %9.2f   ', $key, $ref_values->{$key});
    }
  }
  push @lines, sprintf("%-20s %s\n", $path, $string) if ($string ne '');
  return join('', @lines);
}


sub feed_rrds {
  my $ref_values = shift;
  my $subdir = shift;
  my $hierarchy = shift || '';

  my @result;
  my %values = ();
  foreach my $key (sort keys %{$ref_values})
  {
    if (ref $ref_values->{$key} eq 'HASH')
    {
      feed_rrds($ref_values->{$key}, $subdir, $hierarchy.'_'.lc($key));
    }
    else
    {
      $values{$key} = $ref_values->{$key};
    }
  }

  if (keys %values)
  {

    if (! -d "rrd") {
      mkdir "rrd";
    }

    if ( (defined $subdir) and (! -d "rrd/".$subdir)) {
      mkdir "rrd/".$subdir;
    }

    my $update_pattern = '';
    my $update_values = '';
    foreach my $key (sort keys %values)
    {
      $update_pattern .= ':'.$key;
      $update_values .= ':'.$values{$key};
    }

    $hierarchy =~ s/^_//;
    my $name = $hierarchy;
    my $fullpath = 'rrd/'.(defined $subdir ? $subdir.'/' : '').$hierarchy.'.rrd';
    $update_pattern =~ s/^://;
    $update_values =~ s/^://;
    #print "updating $fullpath with: $update_pattern / $update_values\n";

    if (! -f $fullpath) {
      push @result, "RRD create: $fullpath";
      my $ref_param = $GRAPHS{'diagrams'}{$name};
      $ref_param->{'name'} = $name;
      my $result = create_rrd($subdir, $ref_param);
      if (defined $result) {
        push @result, $result;
      }
    }

    RRDs::update($fullpath, '--template', $update_pattern, "N:".$update_values);
    my $error = RRDs::error();
    if ($error) {
      push @result, ("RRDs error: $name / $error");
    }
  }
  return @result;
}


sub create_rrd {
  my $subdir = shift;
  my $ref_params = shift;

  my $base_step = $RRD_STEP;
  my $type = $ref_params->{'type'};
  my $ref_rows = $ref_params->{'rows'};
  my $ref_resolutions = \@RRD_RESOLUTIONS;

  my @rows;
  foreach my $ref_graph (@{$ref_params->{'graphs'}})
  {
    push @rows, sprintf('DS:%s:%s:%d:%s', $ref_graph->{'row'}, $type, 6*$base_step, $ref_graph->{'data_range'});
  }
  #print join(" - ", @rows), "\n";

  my @resolutions;
  my $count = 0;
  foreach my $resolution (@{$ref_resolutions})
  {
    my ($span, $step) = split(/@/, $resolution);
    my $step_seconds = time_to_seconds($step);
    my $span_seconds = time_to_seconds($span);
    my $factor = 0.3;
    my $num_steps = $span_seconds/$step_seconds;
    my $num_base_steps = $step_seconds/$base_step;
    #printf("Span: %5s %9ds Step: %5s %9ds = %9d\n", $span, $span_seconds, $step, $step_seconds, $num_steps);

    foreach my $consolidation ('AVERAGE', 'MIN', 'MAX')
    {
      push @resolutions, sprintf('RRA:%s:%s:%d:%s', $consolidation, $factor, $num_base_steps, $num_steps);
      last if ($count == 0);
    }
    $count++;
  }

  my $name = $ref_params->{'name'};
  my $fullpath = 'rrd/'.(defined $subdir ? $subdir.'/' : '').$name.'.rrd';
  if (! -f $fullpath)
  {
    RRDs::create($fullpath, '--step', $base_step, @rows, @resolutions);
    my $error = RRDs::error();
    if ($error) {
      return "RRDs error: $error";
    }
  }
  return undef;
}


sub get_graph_list {
  return %GRAPHS;
}


sub generate_indexes {
  my $subdir = shift;
  my $type = shift;
  my $name = shift;

  if (! -d $subdir) {
    mkdir $subdir or warn "WARNING: Failed to create output folder: $subdir\n";
  }
  $subdir .= '/'.$name;
  if (! -d $subdir) {
    mkdir $subdir or warn "WARNING: Failed to create output folder: $subdir\n";
  }

  my @times = sort { length($b) <=> length($a) } (keys %{$GRAPHS{'times'}});
  my $maxlen_timespan = $times[0];

  my %indexdata;

  # prepare main index data for all timespans and for main index and summary
  foreach my $timespan ('all', '', @times) {
    push @{$indexdata{$name}{$timespan}{'header'}}, (
      '<html>',
      '<head>',
      '  <title>'.$name.' ('.$type.') </title>',
      '  <!meta name="" content="">',
      '  <meta charset="utf-8"> '
    );
    if ($timespan ne '') {
      push @{$indexdata{$name}{$timespan}{'header'}}, (
        '  <meta http-equiv="refresh" content="30; URL=index-'.$timespan.'.html">',
      );
    }
    push @{$indexdata{$name}{$timespan}{'header'}}, (
      '</head>',
      '<body>',
    );
    push @{$indexdata{$name}{$timespan}{'footer'}}, (
      '</body>',
      '</html>',
    );
  }

  foreach my $ref_section (@{$GRAPHS{'sections'}}) {
    my $heading = '<h1>'.$ref_section->{'heading'}.'</h1>';
    foreach my $graph (@{$ref_section->{'graphs'}}) {
      my $ref_diagram = $GRAPHS{'diagrams'}{$graph};
      next if (!exists $ref_diagram->{'availability'}{$type});
      foreach my $timespan (@{$ref_diagram->{'times'}}) {
        if (defined $heading) {
          push @{$indexdata{$name}{$timespan}{'body'}}, $heading;
        }
      }
      if (defined $heading) {
        push @{$indexdata{$name}{'all'}{'body'}}, $heading;
      }
      $heading = undef;
      foreach my $timespan (@{$ref_diagram->{'times'}}) {
        push @{$indexdata{$name}{$timespan}{'body'}}, '<img src="'.$graph.'-'.$timespan.'.png">';
        push @{$indexdata{$name}{'all'}{'body'}}, '<img src="'.$graph.'-'.$timespan.'.png">';
      }
      push @{$indexdata{$name}{'all'}{'body'}}, '<br>';
    }
  }

  push @{$indexdata{$name}{''}{'body'}}, (
    '  <table>',
    '    <tr>',
  );
  foreach my $timespan (@{$GRAPHS{'time_order'}}) {
    push @{$indexdata{$name}{''}{'body'}}, (
      '      <td>',
      '        <a href="index-'.$timespan.'.html"><h1>'.$GRAPHS{'times'}{$timespan}{'heading'}.'</h1></a>',
      '        <iframe width="710px" height="970px" src="index-'.$timespan.'.html"></iframe>',
      '      </td>',
    );
  }
  push @{$indexdata{$name}{''}{'body'}}, (
    '    </tr>',
    '  </table>',
  );

  #print Dumper(\%indexdata);

  foreach my $unit (sort keys %indexdata) {
    print "$unit\n";
    foreach my $timespan (sort keys %{$indexdata{$unit}}) {
      my $ref_sections = $indexdata{$unit}{$timespan};

      if ($timespan ne '') {
        $timespan = '-'.$timespan;
      }
      my $file = $subdir.'/index'.$timespan.'.html';
      print "  creating: ".$file,"\n";
      open my $h_file, '>', $file;
      foreach my $section ('header', 'body', 'footer') {
        print $h_file join('', @{$ref_sections->{$section}});
      }
      close $h_file;
    }
  }
}


sub generate_diagrams {
  my $subdir = shift;
  my $type = shift;
  my $name = shift;
  my @which = @_;

  @which = sort keys %{$GRAPHS{'diagrams'}} if (! @which);

  my $maxlen_diagram = length((sort { length($b) <=> length($a) } @which)[0]);
  my $maxlen_timespan = length((sort { length($b) <=> length($a) } (keys %{$GRAPHS{'times'}}))[0]);

  if (! -d $subdir) {
    mkdir $subdir or warn "WARNING: Failed to create output folder: $subdir\n";
  }
  $subdir .= '/'.$name;
  if (! -d $subdir) {
    mkdir $subdir or warn "WARNING: Failed to create output folder: $subdir\n";
  }

  foreach my $diagram (@which)
  { 
    my $ref_diagram = $GRAPHS{'diagrams'}{$diagram};
    next if (!exists $ref_diagram->{'availability'}{$type});

    print "generating: $name ($type) $diagram\n";

    foreach my $timespan (@{$ref_diagram->{'times'}})
    { 
      printf("  graph %s %".$maxlen_timespan."s ", $diagram, $timespan);
      my $ref_timespan = $GRAPHS{'times'}{$timespan};
      my $basename = $subdir.'/'.$diagram.'-'.$timespan;

      # TODO: add color scheme using: '--color', 'COLORTAG#rrggbb[aa]',
      my @params = (
        $basename.'.png',
        '--start', $ref_timespan->{'start'},
        '--width', $GRAPHS{'base'}{'width'},
        '--height', $GRAPHS{'base'}{'height'},
        '--lazy',
        '--slope-mode',
        '--alt-autoscale',
        '--alt-y-grid',
        #'--vertical-label', '', # TODO: add unit here
        '--font', 'TITLE:13',
        '--force-rules-legend', # make sure all HRULE/VRULE are described in the legend, even if they are invisible due to graph scaling
        '--title', $ref_diagram->{'title'}.' ('.$ref_diagram->{'unit'}.') '.$name.' last '.$timespan,
      );

      push @params, ('--lower-limit', $ref_diagram->{'min'}) if exists ($ref_diagram->{'min'});
      push @params, ('--upper-limit', $ref_diagram->{'max'}) if exists ($ref_diagram->{'max'});

      my @localtime = localtime();
      $localtime[4]++;
      $localtime[5] += 1900;
      my $time = sprintf("%02d\\:%02d\\:%02d", $localtime[2], $localtime[1], $localtime[0]);
      my $date = sprintf("%02d-%02d-%02d", $localtime[5], $localtime[4], $localtime[3]);
      my $date_time = $date.' '.$time;

      my @def;
      my @vdef;
      my @legend_top = (
        'TEXTALIGN:left',
        'COMMENT:'.$date_time."\\n",
      );
      my $maxlen_row = length((sort { length($b->{'row'}) <=> length($a->{'row'}) } (@{$ref_diagram->{'graphs'}}))[0]{'row'});

      my $headings;
      my %consolidation = (
        'cur' => { 'heading' => '      Last', 'func' => 'LAST',    'func-vdef' => "LAST", },
        'min' => { 'heading' => '   Minimum', 'func' => "MIN",     'func-vdef' => "MINIMUM", },
        'avg' => { 'heading' => '   Average', 'func' => "AVERAGE", 'func-vdef' => "AVERAGE", },
        'max' => { 'heading' => '   Maximum', 'func' => "MAX",     'func-vdef' => "MAXIMUM", },
      );
      for my $consol (@{$ref_timespan->{'func'}})
      {
        $headings .= $consolidation{$consol}{'heading'};
      }
      push @legend_top, 'COMMENT:'.(' ' x $maxlen_row).$headings.'\n';

      my @graph;
      my $first_row = '';
      foreach my $ref_graph (@{$ref_diagram->{'graphs'}})
      {
        my @this_graph;
        next if (exists $ref_graph->{'hide'});
        my $ref_typeinfo = $ref_diagram->{'availability'}{$type};
        if (ref $ref_typeinfo eq "HASH") {
          next if (!exists $ref_typeinfo->{$ref_graph->{'row'}});
        }
        my $row = $ref_graph->{'row'};
        $first_row = $row.'_avg' if ($first_row eq '');
        my @gprint;
        my $con = 0;
        for my $consol (@{$ref_timespan->{'func'}})
        {
          push @vdef, sprintf('VDEF:%s=%s,%s', $row.'_'.$consol.$consol, $row.'_'.$consol, $consolidation{$consol}{'func-vdef'});
          push @def, sprintf('DEF:%s=rrd/%s/%s.rrd:%s:%s', $row.'_'.$consol, $name, $diagram, $row, $consolidation{$consol}{'func'});
          push @gprint, sprintf('GPRINT:%s:%s', $row.'_'.$consol.$consol, '%6.2lf%S');
          $con++ if (($consol eq "min") or ($consol eq "max"));
        }
        
        if (($ref_graph->{'minmax'} eq 'yes') and ($con >= 2))
        {
          # min/max area: draw an invisible "*_min" and stack "*_max - *_min" onto it
          push @def, sprintf('CDEF:%s_diff=%s_max,%s_min,-', $row, $row, $row);
          push @this_graph, 'AREA:'.$row.'_min#ffffff';
          push @this_graph, 'AREA:'.$row.'_diff#'.brighten($ref_graph->{'color'}, 0.7).'::STACK';
        }
        push @this_graph, sprintf('%s:%s_avg#%s:%-'.$maxlen_row.'s', $ref_graph->{'style'}, $row, $ref_graph->{'color'}, $row);
        push @this_graph, @gprint, 'COMMENT:\n';

        if ((exists $ref_graph->{'minmax'}) and ($ref_graph->{'minmax'} eq 'yes')) {
          unshift @graph, @this_graph;
        } else {
          push @graph, @this_graph;
        }
      }

      # BEPI
      #push @def, "TICK:$first_row#00ff0010:1.0:Nonzero Data";
      push @def, (
        'CDEF:un='.$first_row.',0,*,0,EQ,0,1,IF',
        'TICK:un#ffe8e8:1.0',
      );

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

      #print join("\n", '', @def, @vdef, @legend_top, @graph, '');
      my ($result_arr, $xsize, $ysize) = RRDs::graph(@params, @def, @vdef, @legend_top, @graph, @lines);
      my $error = RRDs::error();
      if ($error) {
        warn "ERROR: ".$error;
      } else {
        printf("  (%4dx%4d) => %s.png\n", $xsize, $ysize, $basename);
      }
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


sub time_to_seconds {
  my $timestring = shift;

  my %factors = ( 'S' => 1, 'M' => 60, 'H' => 3600, 'd' => 86400, 'w' => 86400*7, 'm' => 86400*31, 'y' => 86400*366, );

  $timestring =~ /^(\d+)(\w)$/;
  my ($num, $unit) = ($1, $2);
  return 0 if (!exists $factors{$unit});
  return $num * $factors{$unit};
}


sub read_config {
  my $file = shift;

  if (! -f $file) {
    print "ERROR: no such file ($file)\n";
    exit 1;
  }

  my %config;

  open(my $h_conf, '<', $file);
  while (my $line = <$h_conf>) {

    chomp $line;
    if ($line =~ /^\s*([_\w]+?)\s*=\s*(.*)$/) {
      my ($key, $value) = ($1, $2);
        if ($key eq "DEVICE") {
          my @values = split(/,/, $value);
          push @{$config{$key}}, {
            'NAME' => $values[0],
            'TYPE' => $values[1],
            'UNIT' => $values[2],
          };
        } else {
          $config{$key} = $value;
        }
      }
  } 

  close $h_conf;

  return \%config;
}


sub set_debug_level {
  $DEBUG = shift;
}

1;
