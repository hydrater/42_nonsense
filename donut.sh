#!/bin/bash

# Create a temp directory and move into it
tmpdir=$(mktemp -d)
cd "$tmpdir" || exit 1

# Download the C file
curl -sSL https://raw.githubusercontent.com/hydrater/42_nonsense/main/donut.c -o donut.c

# Compile it
gcc -o donut donut.c -lm

# Run the donut
./donut
