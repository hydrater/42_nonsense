#!/bin/bash

# Download the raw C file using curl
curl -s -o donut.c https://raw.githubusercontent.com/hydrater/42_nonsense/main/donut.c

# Compile the C file with gcc
gcc -o donut donut.c -lm

# Run the compiled binary
./donut
