#!/bin/bash

while true ; do
  SEC=$(($(date +%s) % 10))
  if [ "$SEC" = "0" ] ; then
    ./sdm630-update-rrds.pl
  fi
  sleep 1;
done
