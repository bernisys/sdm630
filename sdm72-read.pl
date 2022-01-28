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

my $file = shift || 'sdm630.conf';
my $ref_config = SDM630::read_config($file);

$SIG{CHLD} = \&REAPER;

# TODO: catch connection timeout error and retry the connection
while (1==1) {
  my $now = qx/date/;
  chomp $now;
  my %values;
  my $ref_client = Device::Modbus::TCP::Client->new(host => $ref_config->{'IP_ADDRESS'}, timeout => $ref_config->{'TIMEOUT'});

  printf('@%s', $now);
  my @output = ();
  foreach my $ref_device (@{$ref_config->{'DEVICE'}}) {
    my $ref_values = SDM630::retrieve_all($ref_client, $ref_device->{'UNIT'}, $ref_device->{'TYPE'});
    $values{$ref_device->{'UNIT'}} = {
      'type' => $ref_device->{'TYPE'},
      'data' => $ref_values,
    };

    printf(" - %s (%s)", $ref_device->{'NAME'}, $ref_device->{'TYPE'});
    my $prefix = sprintf("%s - %-6s (%-6s) - ", $now, $ref_device->{'NAME'}, $ref_device->{'TYPE'});
    push @output, prefix_lines($prefix, SDM630::output_values($ref_values));
    push @output, prefix_lines($prefix, SDM630::feed_rrds($ref_values, $ref_device->{'NAME'}));
    if ($ref_device->{'TYPE'} eq 'SDM630') {
      push @output, prefix_lines($prefix, SDM630::feed_rrds($ref_values, 'test'));
    }
  }
  $ref_client->disconnect;
  print "\n";

  foreach my $ref_device (@{$ref_config->{'DEVICE'}}) {
    if (! -f $ref_config->{'WEBDIR'}.'/'.$ref_device->{'NAME'}.'/index.html') {
      SDM630::generate_indexes($ref_config->{'WEBDIR'}, $ref_device->{'TYPE'}, $ref_device->{'NAME'});
    }
  }

  # TODO: every 900 seconds / integrate into the "5-min-section"
    if ((time % 900) < 10) {
      my $pid = fork();
      if ($pid == 0) {
        print "Forked - starting diagram generator...\n";
        foreach my $ref_device (@{$ref_config->{'DEVICE'}}) {
          SDM630::generate_diagrams($ref_config->{'WEBDIR'}, $ref_device->{'TYPE'}, $ref_device->{'NAME'});
        }
        exit 0;
      } else {
        print "Forked graph creation (PID=$pid)\n";
      }
    }
  # every 5 minutes, generate a new summary file with all current readings
  if ((time % 300) < 10) {
    open(my $h_file, '>', 'web/readings.txt');
    print $h_file $now, "\n", @output;
    close($h_file);
  }
  my $sleeptime = 10 - time % 10;
  print join('', $now, "\n", @output, $sleeptime, "\n");

  sleep $sleeptime;
}


use POSIX ":sys_wait_h";

sub REAPER {
  local $!;   # don't let waitpid() overwrite current error
  while ((my $pid = waitpid(-1, WNOHANG)) > 0 && WIFEXITED($?)) {
    print "reaped $pid" . ($? ? " with exit $?" : "");
  }
  $SIG{CHLD} = \&REAPER;  # loathe SysV
}



sub prefix_lines {
  my $prefix = shift;

  my @output;
  foreach my $line (@_) {
    push @output, $prefix.$line;
  }
  return @output;
}

    

