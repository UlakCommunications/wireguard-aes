#!/bin/bash
howmany=25
# run processes and store pids in array
mkdir -p sums
echo "" > receive_totals.txt
echo "" > send_totals.txt
echo "" > sums/output_receive_sum_all.txt
echo "" > sums/output_send_sum_all.txt
for ((i=0; i < $howmany; i++)); do
    cat output_receive_${i}.txt |tr -s  '[:blank:]' | grep '^\[SUM\].*sec $' | sed 's/\[SUM\] //g' | sed 's/ sec//g' | sed 's/-/ /g'  > sums/output_receive_${i}_sum.txt
    cat output_receive_${i}.txt |tr -s  '[:blank:]' | grep '^\[SUM\].*sec $' | sed 's/\[SUM\] //g' | sed 's/ sec//g' | sed 's/-/ /g'   >> sums/output_receive_sum_all.txt
    cat output_receive_${i}.txt |tr -s  '[:blank:]' | grep 'receiver'  | sed 's/\[SUM\] //g' | sed 's/ sec//g' | sed 's/-/ /g'  >> receive_totals.txt

    cat output_send_${i}.txt |tr -s  '[:blank:]' | grep '^\[SUM\].*sec ' | sed 's/\[SUM\] //g' | sed 's/ sec//g'  | sed 's/-/ /g'  > sums/output_send_${i}_sum.txt
    cat output_send_${i}.txt |tr -s  '[:blank:]' | grep '^\[SUM\].*sec ' | sed 's/\[SUM\] //g' | sed 's/ sec//g' | sed 's/-/ /g'   >> sums/output_send_sum_all.txt
    cat output_send_${i}.txt |tr -s  '[:blank:]' | grep '\[SUM\].*sendr' | sed 's/\[SUM\] //g' | sed 's/ sec//g' | sed 's/-/ /g' >> send_totals.txt
done
