#!/bin/bash

PID_FILE="/tmp/lidmusic.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if [ -n "$PID" ] && ps -p "$PID" > /dev/null; then
        kill "$PID"
    fi
    rm "$PID_FILE"
fi
