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


my $VAR1 = {
  'Charge'      => { 'Ah' => '1251.346' },
  'Frequency'   => { 'Hz' => '50.035' },
  'Current'     => { 'L1' =>   '0.224', 'L2' =>   '1.092', 'L3' => '  2.101', 'avg' =>   '1.183', 'sum' => '3.551' },
  'PowerFactor' => { 'L1' =>   '0.828', 'L2' =>   '0.758', 'L3' =>   '0.904', 'sum' =>   '0.859' },
  'Voltage'     => { 'L1' => '229.636', 'L2' => '229.168', 'L3' => '230.414', 'avg' => '229.739' },
  'phi'         => { 'L1' =>  '34.056', 'L2' =>  '40.713', 'L3' =>  '25.183', 'sum' =>  '30.707' },
  'Power'       => {
    'VA'        => { 'L1' => '51.646', 'L2' => '250.296', 'L3' => '484.298', 'sum' => '786.152' },
    'Var'       => { 'L1' => '29.668', 'L2' => '163.387', 'L3' => '205.682', 'sum' => '398.290' },
    'W'         => { 'L1' => '42.274', 'L2' => '189.613', 'L3' => '438.283', 'sum' => '670.661',
      'demand'  => { 'max' => '7082.617', 'tot' => '670.171' },
    },
  },
  'Energy'      => {
    'kVAh'      => '298.806',
    'kVarh'     => { 'in' =>  '95.153', 'out' =>  '24.565' },
    'kWh'       => { 'in' => '131.457', 'out' => '142.317' },
  },
};


sub retrieve_all {
  my $ref_client = shift;
  my $ref_values = {};

  # retrieve all 3-phase reated values
  SDM630::retrieve($ref_client, 0, 3, ['Voltage', 'Current', 'Power_W', 'Power_VA', 'Power_Var', 'PowerFactor', 'phi'], $ref_values);

  # then add all single values
  SDM630::retrieve($ref_client, 21, 1, ['Voltage_avg', '_23', 'Current_avg', 'Current_sum', '_26', 'Power_W_sum', '_28', 'Power_VA_sum', '_30', 'Power_Var_sum', 'PowerFactor_sum', '_33', 'phi_sum', '_35', 'Frequency_Hz', 'Energy_kWh_in', 'Energy_kWh_out', 'Energy_kVarh_in', 'Energy_kVarh_out', 'Energy_kVAh', 'Charge_Ah', 'Power_W_demand_tot', 'Power_W_demand_max', ], $ref_values);
  return $ref_values;
}


sub retrieve {
  my $ref_client = shift;
  my $start = shift;
  my $grouping = shift;
  my $ref_prefixes = shift;
  my $ref_readings = shift;

  my $count = scalar(@{$ref_prefixes}) * $grouping;

  my $ref_req = $ref_client->read_holding_registers(unit => 1, address => 2 * $start, quantity => 2 * $count);

  $ref_client->send_request($ref_req);
  my $ref_response = $ref_client->receive_response;
  my $ref_values = $ref_response->{'message'}{'values'};

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
    #print Dumper($ref_readings);

    #$ref_readings->{'linear'}{$item} = $float;
    #printf("%d  %s  %5.2f\n", ($start + $index + 1), $item, $float);
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
  printf("%-20s %s\n", $path, $string);
}


sub create_all_rrds {
  my @params = (
    { 'name' => 'charge',         'type' => 'COUNTER', 'rows' => ['Ah:0:U', ], },
    { 'name' => 'current',        'type' => 'GAUGE',   'rows' => ['L1:0:100', 'L2:0:100', 'L3:0:100', 'avg:0:100', 'sum:0:100', ], },
    { 'name' => 'energy_kvah',    'type' => 'GAUGE',   'rows' => ['kVAh:0:U', ], },
    { 'name' => 'energy_kvarh',   'type' => 'GAUGE',   'rows' => ['in:0:U', 'out:0:U', ], },
    { 'name' => 'energy_kwh',     'type' => 'GAUGE',   'rows' => ['in:0:U', 'out:0:U', ], },
    { 'name' => 'frequency',      'type' => 'GAUGE',   'rows' => ['Hz:45:55', ], },
    { 'name' => 'phi',            'type' => 'GAUGE',   'rows' => ['L1:-180:180', 'L2:-180:180', 'L3:-180:180', 'sum:-180:180', ], },
    { 'name' => 'power_va',       'type' => 'GAUGE',   'rows' => ['L1:0:20000', 'L2:0:20000', 'L3:0:20000', 'sum:0:60000', ], },
    { 'name' => 'power_var',      'type' => 'GAUGE',   'rows' => ['L1:0:20000', 'L2:0:20000', 'L3:0:20000', 'sum:0:60000', ], },
    { 'name' => 'power_w',        'type' => 'GAUGE',   'rows' => ['L1:0:20000', 'L2:0:20000', 'L3:0:20000', 'sum:0:60000', ], },
    { 'name' => 'power_w_demand', 'type' => 'GAUGE',   'rows' => ['max:0:60000', 'tot:0:60000', ], },
    { 'name' => 'powerfactor',    'type' => 'GAUGE',   'rows' => ['L1:-1:1', 'L2:-1:1', 'L3:-1:1', 'sum:-1:1', ], },
    { 'name' => 'voltage',        'type' => 'GAUGE',   'rows' => ['L1:0:270', 'L2:0:270', 'L3:0:270', 'avg:0:270', ], },
  );

  foreach my $ref_param (@params)
  {
    $ref_param->{'step'} = 10;
    $ref_param->{'resolutions'} = ['2H@10S', '2d@1M', '2w@10M', '2m@1H', '2y@12H', ];
    create_rrd($ref_param);
  }
}


sub create_rrd {
  my $ref_params = shift;

  my $base_step = $ref_params->{'step'};
  my $type = $ref_params->{'type'};
  my $ref_rows = $ref_params->{'rows'};
  my $ref_resolutions = $ref_params->{'resolutions'};

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

1;
