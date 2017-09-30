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

1;
