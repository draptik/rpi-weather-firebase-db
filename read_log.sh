#!/bin/bash

if [ -z "$1" ]; then
    # echo "Please provide a log file. If it doesn't exist, it will be created."
    echo 0
    exit 1
fi

LOG_FILE=$1

if [ ! -f "$LOG_FILE" ]; then
    # echo "Provided log file '$LOG_FILE' does not exist. The absence of the log file will return 0 as the last succesful ID."
    echo 0
    exit 0
fi

## Example input:
##
## 10-20-2022 21:50:30 | 21721 | -NEqwbm51ZKwLz7HcvfD
## 10-20-2022 21:50:31 | 21722 | Error
## 2022-10-24 22:40:29 | NA | Error Exiting - LAST_DB_ID is not a number (happens when the DB query returns no results...). The query was:  SELECT * FROM temperatures WHERE id > 21721
## ^f1                   ^f2     ^f3
##
## Our goal is to get the last id which was successfuly submitted. In the example above: 21721.
##
## Maybe not the most efficient solution, but I understand it...
##
## - First condition (`$3 ~ /Error/`) finds matching lines with "Error" in field $3 (see "f3" in ascii art above). 
##   If this is true, then immediately skip to the `next` line (`next` is a built-in awk command).
## - Second condition (`$3 !~ /Error/`) stores field $2 (see "f2" in ascii art above) of 
##   the current line (could be `next` from above...) "without error" in variable `lastSuccess`
## - Finally, the `END` block outputs the `lastSuccess`. Note: the `gsub` part just trims whitespace.
##
## This also covers the use case where:
##
## - The upload script was interrupted with Ctrl-C
## - There is no Error present
##
awk  -F '|' '$3 ~ /Error/ {next} $3 !~ /Error/ {lastSuccess = $2} END {gsub(/[ \t]/, "", lastSuccess); print lastSuccess}' "$LOG_FILE"
