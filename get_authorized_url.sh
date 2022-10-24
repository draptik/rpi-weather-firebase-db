#!/bin/bash

## https://stackoverflow.com/a/246128
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)

CONFIG_FILE="$SCRIPT_DIR/credentials.json"

WEB_API_KEY=$(jq -r '.user.WEB_API_KEY' "$CONFIG_FILE")
EMAIL=$(jq -r '.user.EMAIL' "$CONFIG_FILE")
PASSWORD=$(jq -r '.user.PASSWORD' "$CONFIG_FILE")
BASE_URL=$(jq -r '.user.BASE_URL' "$CONFIG_FILE")

URL="$BASE_URL$WEB_API_KEY"

ID_TOKEN=$(curl "$URL" \
    -H 'Content-Type: application/json' \
    --data-binary '{"email":"'"$EMAIL"'","password":"'"$PASSWORD"'","returnSecureToken":true}' \
    | jq -r '.idToken')

ENCODED_TOKEN=$(echo "$ID_TOKEN" | sed 's/\//%2F/g' | sed 's/\./%2E/g')

DB_URL=$(jq -r '.db.DB_URL' "$CONFIG_FILE")
COLLECTION=$(jq -r '.db.COLLECTION' "$CONFIG_FILE")

REMOTE_URL="$DB_URL/$COLLECTION"
CURL_URL=$REMOTE_URL'.json?auth='"$ENCODED_TOKEN"''

echo "$CURL_URL"
