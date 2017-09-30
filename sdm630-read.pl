#!/usr/bin/perl
 
use strict;
use warnings;
use diagnostics;
 
$| = 1;
 
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent = 1;
 
use Device::Modbus::TCP::Client;
 
my $count = 21;
my $start = 0;
 
my $ref_client = Device::Modbus::TCP::Client->new(host => "192.168.178.16", timeout => 2);
 
my $ref_values = {};
 
retrieve($ref_client, 0, 3, ["Voltage", "Current", "Power_W", "Power_VA", "Power_Var", "PF", "phi"], $ref_values);
retrieve($ref_client, 21, 1, ["Voltage_avg", "_23", "Current_avg", "Current_sum", "_26", "Power_W_sum", "_28", "Power_VA_sum", "_30", "Power_Var_sum", "PF_sum", "_33", "phi_sum", "_35", "Frequency", "Energy_kWh_in", "Energy_kWh_out", "Energy_kVarh_in", "Energy_kVarh_out", "Energy_kVAh", "Charge_Ah", "Power_W_demand_tot", "Power_W_demand_max", ], $ref_values);
 
foreach my $item (sort keys %{$ref_values})
{
        if ($item =~ /_L(\d)$/)
        {
                my $num = $1;
                (my $legend = $item) =~ s/_L\d$//;
                if ($num == 1)
                {
                        printf("%-20s %9.2f", $legend, $ref_values->{$item});
                }
                else
                {
                        printf("  %9.2f", $ref_values->{$item});
                }
                if ($num == 3)
                {
                        print "\n";
                }
        }
        else
        {
                printf("%-20s %9.2f\n", $item, $ref_values->{$item});
        }
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
                my $hex = sprintf("%x", $b32);
                my $float = unpack("f", reverse pack("H*", $hex));
                $float = 0 if !defined $float;
 
                my $item = $ref_prefixes->[int($index/$grouping)].(($grouping > 1) ? "_L".(($index % $grouping) + 1) : "");
                next if $item =~ /^_/;
 
                $ref_readings->{$item} = $float;
                #printf("%d  %s  %5.2f\n", ($start + $index + 1), $item, $float);
        }
}

