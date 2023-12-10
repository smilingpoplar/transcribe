#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Usage: ./transcribe.sh <video_file_or_http_link> [other_whisper_cpp_options]"
    exit 1
fi

# 指定文件或http链接
if [[ $1 =~ ^(http|https):// ]]; then
    dir="videos"
    mkdir -p $dir && cd $dir
    yt-dlp --extract-audio --audio-format wav --write-info-json "$1"
    title=$(jq -r .title *.info.json)
    rm *.info.json
    file="$title.wav"
    mv *\[*\].wav "$file"
    cd ..
    file="$dir/$file"
else
    file="$1"
fi

# ffmpeg预处理
f=${file%.*} # 去除后缀
ffmpeg -i "$file" -ar 16000 "$f.tmp.wav"
mv "$f.tmp.wav" "$f"

# whisper转录
shift # 将$1移出参数列表
export GGML_METAL_PATH_RESOURCES="whisper.cpp/"
bin/whisper-cpp -l auto -otxt -osrt -t 6 -m "whisper.cpp/models/ggml-medium-q5_0.bin" "$@" "$f"
rm "$f"

# translate翻译
if [ -e "$f.txt" ]; then
    echo "translating txt ..."
    bin/translate < "$f.txt" > "$f.zh.txt"
fi
if [ -e "$f.srt" ]; then
    echo "translating srt ..."
    bin/translate < "$f.srt" | sed 's/ --&gt; / --> /g' > "$f.zh.srt"
fi
