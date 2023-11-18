#!/bin/bash
if [ $# -ne 0 ]; then
    echo "Usage: ./build.sh"
    exit 1
fi

path=$(realpath "$0")
path=$(dirname "$path")
docker build -t transcribe -f "$path/Dockerfile" "$path/.."
