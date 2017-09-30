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
use sdm630;

 
my $count = 21;
my $start = 0;
 
my $ref_client = Device::Modbus::TCP::Client->new(host => "192.168.178.16", timeout => 2);
 
my $ref_values = {};
 
SDM630::retrieve($ref_client, 0, 3, ["Voltage", "Current", "Power_W", "Power_VA", "Power_Var", "PowerFactor", "phi"], $ref_values);
SDM630::retrieve($ref_client, 21, 1, ["Voltage_avg", "_23", "Current_avg", "Current_sum", "_26", "Power_W_sum", "_28", "Power_VA_sum", "_30", "Power_Var_sum", "PF_sum", "_33", "phi_sum", "_35", "Frequency_Hz", "Energy_kWh_in", "Energy_kWh_out", "Energy_kVarh_in", "Energy_kVarh_out", "Energy_kVAh", "Charge_Ah", "Power_W_demand_tot", "Power_W_demand_max", ], $ref_values);
SDM630::output_values($ref_values);

print Dumper($ref_values);
exit 0;


