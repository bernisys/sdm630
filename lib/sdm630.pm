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


my %RRD_PARAMS = (
  'charge'              => { 'type' => 'GAUGE', 'rows' => ['Ah:0:U', ], },
  'current'             => { 'type' => 'GAUGE', 'rows' => ['L1:0:100', 'L2:0:100', 'L3:0:100', 'N:0:100', 'avg:0:100', 'sum:0:100', ], },
  'current_demand'      => { 'type' => 'GAUGE', 'rows' => ['L1:0:100', 'L2:0:100', 'L3:0:100', ], },
  'current_demandmax'   => { 'type' => 'GAUGE', 'rows' => ['L1:0:100', 'L2:0:100', 'L3:0:100', ], },
  'energy'              => { 'type' => 'GAUGE', 'rows' => ['kVAh:0:U', ], },
  'energy_kvarh_export' => { 'type' => 'GAUGE', 'rows' => ['L1:0:U', 'L2:0:U', 'L3:0:U', 'tot:0:U', ], },
  'energy_kvarh_import' => { 'type' => 'GAUGE', 'rows' => ['L1:0:U', 'L2:0:U', 'L3:0:U', 'tot:0:U', ], },
  'energy_kvarh_total'  => { 'type' => 'GAUGE', 'rows' => ['L1:0:U', 'L2:0:U', 'L3:0:U', 'tot:0:U', ], },
  'energy_kwh_export'   => { 'type' => 'GAUGE', 'rows' => ['L1:0:U', 'L2:0:U', 'L3:0:U', 'tot:0:U', ], },
  'energy_kwh_import'   => { 'type' => 'GAUGE', 'rows' => ['L1:0:U', 'L2:0:U', 'L3:0:U', 'tot:0:U', ], },
  'energy_kwh_total'    => { 'type' => 'GAUGE', 'rows' => ['L1:0:U', 'L2:0:U', 'L3:0:U', 'tot:0:U', ], },
  'frequency'           => { 'type' => 'GAUGE', 'rows' => ['Hz:30:70', ], },
  'phi'                 => { 'type' => 'GAUGE', 'rows' => ['L1:-360:360', 'L2:-360:360', 'L3:-360:360', 'sum:-360:360', ], },
  'power_va'            => { 'type' => 'GAUGE', 'rows' => ['L1:-20000:20000', 'L2:-20000:20000', 'L3:-20000:20000', 'sum:-60000:60000', ], },
  'power_var'           => { 'type' => 'GAUGE', 'rows' => ['L1:-20000:20000', 'L2:-20000:20000', 'L3:-20000:20000', 'sum:-60000:60000', ], },
  'power_w'             => { 'type' => 'GAUGE', 'rows' => ['L1:-20000:20000', 'L2:-20000:20000', 'L3:-20000:20000', 'sum:-60000:60000', ], },
  'power_va_demand'     => { 'type' => 'GAUGE', 'rows' => ['max:0:60000', 'tot:0:60000', ], },
  'power_w_demand'      => { 'type' => 'GAUGE', 'rows' => ['max:0:60000', 'tot:0:60000', ], },
  'powerfactor'         => { 'type' => 'GAUGE', 'rows' => ['L1:-1:1', 'L2:-1:1', 'L3:-1:1', 'sum:-1:1', ], },
  'thd_voltage_l'       => { 'type' => 'GAUGE', 'rows' => ['L1:0:110', 'L2:0:110', 'L3:0:110', 'avg:0:110', ], },
  'thd_current'         => { 'type' => 'GAUGE', 'rows' => ['L1:0:110', 'L2:0:110', 'L3:0:110', 'avg:0:110', ], },
  'voltage_l'           => { 'type' => 'GAUGE', 'rows' => ['L1:0:270', 'L2:0:270', 'L3:0:270', 'avg:0:270', ], },
  'voltage_ll'          => { 'type' => 'GAUGE', 'rows' => ['L1L2:0:420', 'L2L3:0:420', 'L3L1:0:420', 'avg:0:420', ], },
);

my @RRD_RESOLUTIONS = ( '12H@10S', '14d@1M', '4w@10M', '6m@1H', '5y@12H', );
my $RRD_STEP = 10;


sub retrieve_all {
  my $ref_client = shift;
  my $ref_values = {};

  # retrieve all 3-phase reated values
  SDM630::retrieve($ref_client,   0, 3, [
      'Voltage_L', 'Current', 'Power_W', 'Power_VA', 'Power_Var', 'PowerFactor', 'phi'
    ], $ref_values);

  # then add all single values
  SDM630::retrieve($ref_client,  21, 1, [
      'Voltage_L_avg', '_23', 'Current_avg', 'Current_sum', '_26', 'Power_W_sum', '_28', 'Power_VA_sum', '_30',
      'Power_Var_sum', 'PowerFactor_sum', '_33', 'phi_sum', '_35', 'Frequency_Hz', 'Energy_kWh_Import_tot', 'Energy_kWh_Export_tot', 'Energy_kVarh_Import_tot', 'Energy_kVarh_Export_tot',
      'Energy_kVAh_Total_tot', 'Charge_Ah', 'Power_W_demand_tot', 'Power_W_demand_max',
    ], $ref_values);

  SDM630::retrieve($ref_client,  50, 1, [
      'Power_VA_demand_tot', 'Power_VA_demand_max',
    ], $ref_values);

  SDM630::retrieve($ref_client, 100, 1, [
      'Voltage_LL_L1L2', 'Voltage_LL_L2L3', 'Voltage_LL_L3L1', 'Voltage_LL_avg',
    ], $ref_values);

  SDM630::retrieve($ref_client, 112, 1, [
      'Current_N',
    ], $ref_values);

  SDM630::retrieve($ref_client, 117, 3, [
      'THD_Voltage_L', 'THD_Current',
    ], $ref_values);

  SDM630::retrieve($ref_client, 124, 1, [
      'THD_Voltage_L_avg', 'THD_Current_avg',
    ], $ref_values);

  SDM630::retrieve($ref_client, 129, 3, [
      'Current_demand', 'Current_demandmax',
    ], $ref_values);

# TODO: this value seems to be unknown by my SDM630 ...
#  SDM630::retrieve($ref_client, 167, 1, [
#      'THD_Voltage_LL_L1L2', 'THD_Voltage_LL_L2L3', 'THD_Voltage_LL_L3L1', 'THD_Voltage_LL_avg',
#    ], $ref_values);

  SDM630::retrieve($ref_client, 171, 1, [
      'Energy_kWh_Total_tot', 'Energy_kVarh_Total_tot',
    ], $ref_values);

  SDM630::retrieve($ref_client, 173, 3, [
      'Energy_kWh_Import', 'Energy_kWh_Export', 'Energy_kWh_Total', 'Energy_kVarh_Import', 'Energy_kVarh_Export', 'Energy_kVarh_Total',
    ], $ref_values);

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
  my $start = shift;
  my $grouping = shift;
  my $ref_prefixes = shift;
  my $ref_readings = shift;

  my $count = scalar(@{$ref_prefixes}) * $grouping;

  my $ref_req = $ref_client->read_input_registers(unit => 1, address => 2 * $start, quantity => 2 * $count);
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

  my $string = '';
  foreach my $key (sort keys %{$ref_values})
  {
    if (ref $ref_values->{$key} eq 'HASH')
    {
      output_values($ref_values->{$key}, $path.' '.$key);
    }
    else
    {
      $string .= sprintf('%5s: %9.2f   ', $key, $ref_values->{$key});
    }
  }
  printf("%-20s %s\n", $path, $string) if ($string ne '');
}


sub create_all_rrds {
  foreach my $key (keys %RRD_PARAMS)
  {
    my $ref_param = $RRD_PARAMS{$key};
    $ref_param->{'name'} = $key;
    create_rrd($ref_param);
  }
}


sub feed_rrds {
  my $ref_values = shift;
  my $path = shift || '';

  my %values = ();
  foreach my $key (sort keys %{$ref_values})
  {
    if (ref $ref_values->{$key} eq 'HASH')
    {
      feed_rrds($ref_values->{$key}, $path.'_'.lc($key));
    }
    else
    {
      $values{$key} = $ref_values->{$key};
    }
  }
  if (keys %values)
  {

    my $update_pattern = '';
    my $update_values = '';
    foreach my $key (sort keys %values)
    {
      $update_pattern .= ':'.$key;
      $update_values .= ':'.$values{$key};
    }

    $path =~ s/^_//;
    my $name = $path;
    $path = 'rrd/'.$path.'.rrd';
    $update_pattern =~ s/^://;
    $update_values =~ s/^://;
    #print "updating $path with: $update_pattern / $update_values\n";

    if (! -f $path) {
      warn("RRD create: $path\n");
      my $ref_param = $RRD_PARAMS{$name};
      $ref_param->{'name'} = $name;
      create_rrd($ref_param);
      return;
    }

    RRDs::update($path, '--template', $update_pattern, "N:".$update_values);
    my $error = RRDs::error();
    if ($error) {
      warn("RRDs error: $name / $error\n");
    }
  }
}


sub create_rrd {
  my $ref_params = shift;

  my $base_step = $RRD_STEP;
  my $type = $ref_params->{'type'};
  my $ref_rows = $ref_params->{'rows'};
  my $ref_resolutions = \@RRD_RESOLUTIONS;

  my @rows;
  foreach my $row (@{$ref_rows})
  {
    my ($name, $min, $max) = split(/:/, $row);
    push @rows, sprintf('DS:%s:%s:%d:%s:%s', $name, $type, 6*$base_step, $min, $max);
  }

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
  if (! -f 'rrd/'.$name.'.rrd')
  {
    RRDs::create('rrd/'.$name.'.rrd', '--step', $base_step, @rows, @resolutions);
    my $error = RRDs::error();
    if ($error) {
      warn("RRDs error: $error\n");
    }
  }
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
      $config{$1} = $2;
    }
  } 

  close $h_conf;

  return \%config;
}


sub set_debug_level {
  $DEBUG = shift;
}

1;
