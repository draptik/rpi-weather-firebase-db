#!/bin/bash

## https://stackoverflow.com/a/246128
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)

CURL_URL=$("$SCRIPT_DIR"/get_authorized_url.sh)

QUERY="orderBy=\"id\"&limitToLast=3"

curl -X GET "$CURL_URL"'&'"$QUERY"'&print=pretty'
