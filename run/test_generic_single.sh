#!/bin/bash

set -x

./clean.sh

howmany=$1

pids=()

# run processes and store pids in array
for ((i=1; i <= $howmany; i++)); do
    ./test_generic.sh $((${i} * 3))  2>&1  | tee out/output_${i}.txt &
    pids+=($!)
done

# wait for all pids
for pid in ${pids[*]}; do
    wait $pid
done
