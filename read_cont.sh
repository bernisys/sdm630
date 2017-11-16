#!/bin/bash

while true ; do
  SEC=$(($(date +%s) % 10))
  if [ "$SEC" = "0" ] ; then
    date
    ./sdm630-update-rrds.pl
    echo
  fi
  sleep 1;
done
