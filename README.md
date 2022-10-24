# RPi Weather Firebase DB

This repository contains code to sync my IoT weather data with a cloud database.

My IoT weather data is stored in an SQLite3 database on a Raspberry Pi 2 (RPi2).

After some (actually, a lot of) research I finally found a cloud database which I can use for free:
Firebase's Realtime Database.

## Project constraints

- Code must run on my RPi2 (!)
- Code should have minimal dependencies (yes, I chose these constraints deliberately):
    - `bash`
    - `jq`
    - `curl`

## Workflow (Birds-eye view)

- Get id of last successfully submitted measurement (f.ex. from sql query or log file)
- Upload newer ids to firebase (via curl)
- Store last successfully submitted id to log file

The script will be run periodically (f.ex. once every x minutes via cron).

## Workflow (details)

I would love to say that the code describes itself. Spoiler: it doesn't (at least not for non-Bash natives).

There are 3 scripts:

- `sync_with_firebase.sh`: This is the main script
  - "Happy path":
    - Script is invoked from a cron job
    - Get `LAST_UPLOADED_MEASUREMENT_ID` from previous run (from log file)
    - Get `LAST_DB_ID` via DB query (using `LAST_UPLOADED_MEASUREMENT_ID`)
    - Check if there are changes which need to be pushed to Firebase
    - Push changes to Firebase -> The `while` loop at the end of the script
  - Everything else is just error handling & logging
- `get_authorized_url.sh`: Create an URL containing the authorization token required by Firebase (see section Credentials below)
- `read_log.sh`: Returns the most recently uploaded measurement

### Generated files

- `sync.log`: For keeping track of what has been pushed to Firebase. Don't delete this file!
- `out.tmp`: Result of current Db query. File is newly created whenever the script is invoked

## Credentials

The script `get_authorized_url.sh` requires a config file:

```sh
CONFIG_FILE="$SCRIPT_DIR/credentials.json"
```

This `credentials.json` file must have the form:

```json
{
    "user": {
        "BASE_URL": "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=",
        "WEB_API_KEY": "<YOUR_WEB_API_KEY>",
        "EMAIL": "<YOUR_EMAIL>",
        "PASSWORD": "<YOUR_PASSWORD>"
    },
    "db": {
        "DB_URL": "https://<YOUR-FIREBASE-DB-URL>.firebasedatabase.app",
        "COLLECTION": "<YOUR_COLLECTION_NAME>"
    }
}
```

### Firebase

How to get all credentials from the Firebase UI:

- Build -> Authentication
- Select "Email/Password"
- Enable Email/Password -> Save
- In Authentication view: Switch to tab "Users" -> click "Add user"
- Add new user (email/password)
- Web API Key: Gear icon to the right of "Project Overview"
- DB URL: UI -> Realtime Database -> tab "Data"

## Periodic updates via cron

Configure a cron job using `crontab -e`:

```sh
*/10 * * * * ~/path/to/sync_with_firebase.sh >>/path/to/failure.log 2>&1
```

The above cron job

- runs every 10min (`*/10`)
- executes the script `~/path/to/sync_with_firebase.sh`
- redirects all output to `/path/to/failure.log` (via `>>/path/to/failure.log 2>&1`). Note: all logging output should already be taken care of by the main script. This ensures that we catch any errors that we missed.

Typical entries in `sync.log` might look similar to:

```txt
2022-10-24 22:10:39 | 304174 | -NFAbapOqzjI_Z1HW8hn
2022-10-24 22:10:44 | 304175 | -NFAbbfNYo6aQoI-TsOE
2022-10-24 22:20:29 | NA | Error Exiting - LAST_DB_ID is not a number (happens when the DB query returns no results...). The query was:  SELECT * FROM temperatures WHERE id > 304175
2022-10-24 22:30:30 | NA | Error Exiting - LAST_DB_ID is not a number (happens when the DB query returns no results...). The query was:  SELECT * FROM temperatures WHERE id > 304175
2022-10-24 22:40:29 | NA | Error Exiting - LAST_DB_ID is not a number (happens when the DB query returns no results...). The query was:  SELECT * FROM temperatures WHERE id > 304175
2022-10-24 22:50:31 | 304176 | -NFAki8l6F2RIB0VJTVj
2022-10-24 23:00:30 | 304177 | -NFAn-XDII1t22eHPgUx
2022-10-24 23:00:34 | 304178 | -NFAn0VSZr7viAMK3C0s
2022-10-24 23:00:37 | 304179 | -NFAn1KdFjDIKlJZf7pl
2022-10-24 23:10:29 | NA | Error Exiting - LAST_DB_ID is not a number (happens when the DB query returns no results...). The query was:  SELECT * FROM temperatures WHERE id > 304179
```

## Initial Import

Things to make the import easier:

- On the RPi2: Dump the current sqlite3 DB to json
- Copy json to a machine which is faster than the RPi2
- Run the initial import on fast machine (see flag `IS_INITIAL_IMPORT` in file `sync_with_firebase.sh`)

I tried to make the initial import as flawless as possible: Spoiler - it didn't work. 

It didn't import everything at once, because I encountered some timeouts or hit some firebase constraints in between. Although I tried, I wasn't able to resolve these issues. So I imported the data step-by-step.

## Removing duplicate entries from Firebase

We might have duplicate entries in the Firebase Realtime Database.

When deleting entries from firebase, we have to now the firebase-ID.

TODO

