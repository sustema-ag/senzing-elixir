#!/usr/bin/env bash

set -x

if psql \
  -h 127.0.0.1 \
  -U postgres \
  -lqt | \
  cut -d \| -f 1 | \
  grep -qw "senzing"; then
  echo "DB senzing exists, skipping"
else
  createdb \
    -h 127.0.0.1 \
    -U postgres \
    "senzing"

  psql \
    -h 127.0.0.1 \
    -U postgres \
    -d "senzing" \
    -f /home/vscode/senzing/schema/g2core-schema-postgresql-create.sql

  /home/vscode/senzing/python/G2SetupConfig.py
fi

