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
}
trap cleanup SIGINT

# 指定文件或http链接
if [[ $1 =~ ^(http|https):// ]]; then
    dir="data.trans"
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
ffmpeg -i "$file" -ar 16000 "$f.tmp.wav"
mv "$f.tmp.wav" "$f"

# whisper转录
shift # 将$1移出参数列表
script_dir=$(dirname "$(realpath "$0")")
export PATH="$script_dir/bin:$PATH"
export GGML_METAL_PATH_RESOURCES="$script_dir/whisper.cpp/"
model_name="large-v2"
model_path="$script_dir/whisper.cpp/models/ggml-$model_name.bin"
whisper-cpp -l auto -otxt -osrt -t 6 -mc 32 -m "$model_path" "$@" "$f"
rm "$f"

# translate翻译
if [ -e "$f.txt" ]; then
    echo "translating txt ..."
    translate < "$f.txt" > "$f.zh.txt"
fi
if [ -e "$f.srt" ]; then
    echo "translating srt ..."
    translate < "$f.srt" | sed 's/ --&gt; / --> /g' > "$f.zh.srt"
fi

# edge-tts生成音频
if [ -e "$f.zh.txt" ]; then
    echo "generating tts ..."
    edge-tts -v zh-CN-XiaoxiaoNeural --rate +100% -f "$f.zh.txt" --write-media "$f.tts.m4a" --write-subtitles "$f.tts.vtt"
fi
