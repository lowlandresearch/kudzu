#!/bin/bash

# Start the program in the background
echo "$@"
# exit
exec "$@" &
pid1=$!

ps aux |grep nmap
# Silence warnings from here on
# exec >/dev/null 2>&1

# Read from stdin in the background and
# kill running program when stdin closes
exec 0<&0 $(
    while read; do :; done
    kill -KILL $pid1
) &
pid2=$!
echo here too
echo $pid1
ps aux | grep nmap
# Clean up
wait $pid1
echo herer 3
ret=$?
kill -KILL $pid2
exit $ret
