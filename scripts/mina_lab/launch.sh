#!/usr/bin/env bash
# Nano-Mina Chain Launcher for Git Bash

# Start node on port 61234
python nanomina.py node --words "$1" --supply $2 &

# Wait for node to initialize
sleep 2

# Open browser in Windows from Git Bash
cmd.exe /c start "" "http://localhost:61234/unified.html"

# Show node output
if [[ -f "chain_data/node.log" ]]; then
    tail -f chain_data/node.log
else
    echo "Node output will appear here..."
    tail -f /dev/null
fi
