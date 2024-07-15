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
    title=$(yt-dlp --get-title "$1")
    # 下载音频
    file="$title.wav"
    yt-dlp --extract-audio --audio-format wav -o "$file" "$1"
    # 下载视频
    yt-dlp "$1" -o "$title.mkv" >/dev/null &
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

# translate字幕
echo "translating srt ..."
if [ -e "$f.txt" ]; then
    translate < "$f.txt" > "$f.zh.txt"
fi
if [ -e "$f.srt" ]; then
    subtitle-translate -i "$f.srt" -o "$f.zh.srt"
    subtitle-translate -i "$f.srt" -o "$f.en-zh.srt" -b
fi

# edge-tts生成音频
if [ -e "$f.zh.srt" ]; then
    echo "generating tts ..."
    edge-srt-to-speech --voice zh-CN-XiaoxiaoNeural "$f.zh.srt" "$f.zh.mp3"
fi

# 将音频合并到原视频
ffmpeg -i "$f.mkv" -i "$f.zh.mp3" -map 0:v -map 0:a -map 1:a -c:v copy -c:a aac -disposition:a:1 default -disposition:a:0 none "$f.en-zh.mp4"
