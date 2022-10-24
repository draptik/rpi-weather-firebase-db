#!/bin/bash

## https://stackoverflow.com/a/246128
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)

## This info is always needed
CURL_URL=$("$SCRIPT_DIR"/get_authorized_url.sh)
LOG_FILE="$SCRIPT_DIR/sync.log"
DB_DUMP=$SCRIPT_DIR/out.tmp
DB_DUMP_INITIAL=$SCRIPT_DIR/out.initial

## This flag decides between regular import (not 1) and initial import (1)
# IS_INITIAL_IMPORT=1 # initial import
IS_INITIAL_IMPORT=0 # regular import

if [ $IS_INITIAL_IMPORT -eq 1 ]; then
    LAST_UPLOADED_MEASUREMENT_ID=303170
    jq --compact-output --raw-output '. | select(.id > 303170)' "$DB_DUMP_INITIAL" > "$DB_DUMP"
else
    ## Check the previously last uploaded measurement Id
    LAST_UPLOADED_MEASUREMENT_ID=$("$SCRIPT_DIR"/read_log.sh "$LOG_FILE")
    if [ "$LAST_UPLOADED_MEASUREMENT_ID" -eq 0 ]; then
        {
            printf "%(%Y-%m-%d %H:%M:%S)T"
            printf " | | %s" "LAST_UPLOADED_MEASUREMENT_ID returned 0. Exiting..."
        } >> "$LOG_FILE"
        exit 1
    fi
fi

## Regular import
if [ $IS_INITIAL_IMPORT -ne 1 ]; then
    ## Retrieve all entries from SQLite which have a newer (=larger) Id than the last uploaded measurement Id.
    SQLITEDB="/var/www/templog.db"
    QUERY="SELECT * FROM temperatures WHERE id > $LAST_UPLOADED_MEASUREMENT_ID"
    
    ## Note: The `-json` flag export sqlite query result as json.
    sqlite3 -json $SQLITEDB "$QUERY" | jq --compact-output --raw-output '.[]' > "$DB_DUMP"

    ## Check if there is any new data to upload
    LAST_DB_ID=$(tail -1 "$DB_DUMP" | jq '.id')
    REGEX_NUMBER='^[0-9]+$'
    if ! [[ $LAST_DB_ID =~ $REGEX_NUMBER ]]; then
        {
            printf "%(%Y-%m-%d %H:%M:%S)T"
            printf " | NA | %s %s\n" "Error Exiting - LAST_DB_ID is not a number (happens when the DB query returns no results...). The query was: " "$QUERY"
        } >> "$LOG_FILE"
        exit 1
    fi
    if ! [[ $LAST_UPLOADED_MEASUREMENT_ID =~ $REGEX_NUMBER ]]; then
        {
            printf "%(%Y-%m-%d %H:%M:%S)T"
            printf " | NA | %s\n" "Error Exiting - LAST_UPLOADED_MEASUREMENT_ID is not a number"
        } >> "$LOG_FILE"
        exit 1
    fi
    if [ "$LAST_DB_ID" -gt "$LAST_UPLOADED_MEASUREMENT_ID" ]; then
        ## NOOP
        true
    else
        {
            printf "%(%Y-%m-%d %H:%M:%S)T"
            printf " | NA | %s\n" "Error Exiting - there is nothing to do: DB-Id is not newer than last uploaded id (LAST_DB_ID: $LAST_DB_ID, LAST_UPLOADED_MEASUREMENT_ID: $LAST_UPLOADED_MEASUREMENT_ID"
        } >> "$LOG_FILE"
        exit 1
    fi
fi

# iterate over json array from temporary file `$DB_DUMP`
while read -r line; do
    {
        ID=$(echo "$line" | jq '.id')

        printf "%(%Y-%m-%d %H:%M:%S)T"
        printf " | %s" "$ID"

        RESPONSE=$(curl -X POST --data "$line" "$CURL_URL" | jq --compact-output --raw-output '.name')

        if [[ $RESPONSE == *"null"* ]]; then
            printf " | Error\n"
            sleep 100
            break
        else
            printf " | %s\n" "$RESPONSE"
        fi
    } >> "$LOG_FILE"
done < "$DB_DUMP"
