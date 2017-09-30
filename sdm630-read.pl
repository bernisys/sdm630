#!/usr/bin/perl
 
use strict;
use warnings;
use diagnostics;
 
$| = 1;
 
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent = 1;
 
use lib "lib";

use Device::Modbus::TCP::Client;
 
my $count = 21;
my $start = 0;
 
my $ref_client = Device::Modbus::TCP::Client->new(host => "192.168.178.16", timeout => 2);
 
my $ref_values = {};
 
retrieve($ref_client, 0, 3, ["Voltage", "Current", "Power_W", "Power_VA", "Power_Var", "PowerFactor", "phi"], $ref_values);
retrieve($ref_client, 21, 1, ["Voltage_avg", "_23", "Current_avg", "Current_sum", "_26", "Power_W_sum", "_28", "Power_VA_sum", "_30", "Power_Var_sum", "PF_sum", "_33", "phi_sum", "_35", "Frequency_Hz", "Energy_kWh_in", "Energy_kWh_out", "Energy_kVarh_in", "Energy_kVarh_out", "Energy_kVAh", "Charge_Ah", "Power_W_demand_tot", "Power_W_demand_max", ], $ref_values);
output_values($ref_values);

print Dumper($ref_values);
exit 0;


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
    my $hex = sprintf("%x", $b32);
    my $float = unpack("f", reverse pack("H*", $hex));
    $float = 0 if !defined $float;

    my $item = $ref_prefixes->[int($index/$grouping)].(($grouping > 1) ? "_L".(($index % $grouping) + 1) : "");
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

  my $string = "";
  foreach my $key (sort keys %{$ref_values})
  {
    if (ref $ref_values->{$key} eq "HASH")
    {
      output_values($ref_values->{$key}, $path.' '.$key);
    }
    else
    {
      $string .= sprintf("%5s: %9.2f   ", $key, $ref_values->{$key});
    }
  }
  printf("%-20s %s\n", $path, $string);
}

