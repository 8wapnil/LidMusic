#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_plist>"
    exit 1
fi

PLIST_PATH="$1"

# Read the sleep timer value in minutes
TIMER_MINUTES=$(plutil -extract sleepTimer raw "$PLIST_PATH")

# Check if the timer is set to a positive value
if [ "$TIMER_MINUTES" -gt 0 ]; then
    # Convert minutes to seconds
    DELAY_SECONDS=$((TIMER_MINUTES * 60))

    # Wait for the specified duration
    sleep "$DELAY_SECONDS"

    # Check which apps to pause
    if [ "$(plutil -extract toMonitor.Apple\\ Music raw "$PLIST_PATH")" == "true" ]; then
        /usr/bin/osascript -e 'try' -e 'tell application "Music" to pause' -e 'end try'
    fi
    if [ "$(plutil -extract toMonitor.Spotify raw "$PLIST_PATH")" == "true" ]; then
        /usr/bin/osascript -e 'try' -e 'tell application "Spotify" to pause' -e 'end try'
    fi
    if [ "$(plutil -extract toMonitor.Now\\ Playing\\ \\(Beta\\) raw "$PLIST_PATH")" == "true" ]; then
        /usr/bin/osascript -e 'try' -e 'tell application "Music" to pause' -e 'end try'
        /usr/bin/osascript -e 'try' -e 'tell application "Spotify" to pause' -e 'end try'
    fi

    # Put the system to sleep
    /usr/bin/pmset sleepnow
fi
