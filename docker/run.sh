#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Usage: ./run.sh <video_file_or_http_link> [other_whisper_cpp_options]"
    exit 1
fi

if [[ $1 =~ ^(http|https):// ]]; then
    dir="videos"
    mkdir -p $dir
else
    dir=$(dirname "$file")
fi
todir="/app/$dir"
dir=$(realpath "$dir")

file="$1"
shift # 将$1移出参数列表
opts="$@"
docker run --rm -it --name transcribe -v "$dir:$todir" transcribe ./transcribe.sh "$file" $opts
