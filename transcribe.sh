#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Usage: ./transcribe.sh <video_file_or_http_link> [other_whisper_cpp_options]"
    exit 1
fi

# Ctrl+C时取消视频下载
bg_pid=0
cleanup() {
    if [ $bg_pid -ne 0 ]; then
        kill $bg_pid
    fi
    exit
}
trap cleanup SIGINT

# 指定文件或http链接
if [[ $1 =~ ^(http|https):// ]]; then
    dir="output.transcribe"
    mkdir -p $dir && cd $dir
    # 下载音频
    yt-dlp --extract-audio --audio-format wav --write-info-json "$1"
    title=$(jq -r .title *.info.json)
    rm *.info.json
    file="$title.wav"
    mv *\[*\].wav "$file"
    # 下载视频
    yt-dlp "$1" >/dev/null &
    bg_pid=$!

    cd ..
    file="$dir/$file"
else
    file="$1"
fi

# ffmpeg预处理
f=${file%.*} # 去除后缀
if [[ ! -f "$f" ]]; then
    ffmpeg -i "$file" -ar 16000 "$f.tmp.wav"
    mv "$f.tmp.wav" "$f"
fi

# whisper转录
shift # 将$1移出参数列表
script_dir=$(dirname "$(realpath "$0")")
export PATH="$script_dir/bin:$PATH"
export GGML_METAL_PATH_RESOURCES="$script_dir/whisper.cpp/"
model_name="large-v2"
model_path="$script_dir/whisper.cpp/models/ggml-$model_name.bin"
whisper-cpp -l auto -otxt -osrt -t 6 -mc 32 --prompt "cut at sentence." -m "$model_path" "$@" "$f"
rm "$f"

# translate翻译
echo "translating srt ..."
if [ -e "$f.txt" ]; then
    translate < "$f.txt" > "$f.zh.txt"
fi
if [ -e "$f.srt" ]; then
    subtitle-translate -i "$f.srt" -o "$f.zh.srt"
    subtitle-translate -i "$f.srt" -o "$f.en-zh.srt" -b
fi

# edge-tts生成音频
if [ -e "$f.zh.txt" ]; then
    echo "generating tts ..."
    edge-tts -v zh-CN-XiaoxiaoNeural -f "$f.zh.txt" --write-media "$f.tts.m4a" --write-subtitles "$f.tts.vtt"
fi
