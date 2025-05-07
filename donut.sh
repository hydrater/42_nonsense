#!/bin/bash

# Temporary location for the binary
TMP_DONUT=$(mktemp /tmp/donut.XXXXXX)

# Download the binary
curl -sL https://raw.githubusercontent.com/hydrater/42_nonsense/main/donut -o "$TMP_DONUT"

# Make it executable
chmod +x "$TMP_DONUT"

# Run it
"$TMP_DONUT"

# Optional: delete the binary afterward
rm "$TMP_DONUT"
