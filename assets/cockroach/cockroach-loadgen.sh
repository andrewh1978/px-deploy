#!/bin/bash

# 100    warehouses = 20GB
# 1,000  warehouses = 200GB
# 10,000 warehouses = 2TB

# Generate 100 warehouses
until kubectl exec cockroachdb-0 -- ./cockroach workload init tpcc --warehouses=500 --drop --split --scatter; do
  # sometimes the following error occurs
  # "Error: failed insert into customer: pq: result is ambiguous (error=rpc error: code = Unavailable desc = transport is closing"
  # which is related to saturation and there is no max configurations for payload or op rate. 
  # so we simply retry.
  echo Tansfer disrupted, retrying...
  sleep 1
done