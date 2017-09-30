#!/bin/bash

for PKG in Device-Modbus-0.021 Net-Server-2.009 Device-Modbus-TCP-0.026 ; do
  tar -xzf "$PKG".tar.gz
  cd $PKG
  perl Makefile.PL
  make
  cp -r lib ../../
  cd ..
done

