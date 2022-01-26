#!/bin/bash

while true ; do
  SEC=$(($(date +%s) % 10))
  if [ "$SEC" = "0" ] ; then
    echo "Starting script - $(date)"
    ./sdm72-read.pl
    echo
  fi
  sleep 1;
done
