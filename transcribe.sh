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
        echo "downloading video canceled ..."
    fi
    exit
}
trap cleanup SIGINT

# 指定文件或http链接
download_link() {
    if [[ $1 =~ ^(http|https):// ]]; then
        dir="output.transcribe"
        mkdir -p $dir
        local title=$(yt-dlp --get-title "$1" | sed 's/\//:/g')
        file="$dir/$title.wav"

        # 下载音频
        if [ ! -f "$file" ]; then
            echo "downloading audio ..."
            yt-dlp --extract-audio --audio-format wav -o "$file" "$1"
        fi
        # 下载视频
        local filename=$(yt-dlp --get-filename "$1")
        local ext="${filename##*.}" # 取后缀
        video_file="$dir/$title.$ext"
        if [ ! -f "$video_file" ]; then
            echo "downloading video in background ..."
            yt-dlp "$1" -o "$video_file" >/dev/null &
            bg_pid=$!
        fi
    else
        file="$1"
    fi
    name=${file%.*} # 去除后缀
}
download_link "$1"

# ffmpeg预处理
ffmpeg_preprocess() {
    if [ ! -f "$2.srt" ]; then
        echo "ffmpeg preprocessing ..."
        ffmpeg -i "$1" -ar 16000 "$2.tmp.wav"
        mv "$2.tmp.wav" "$2"
    fi
}
ffmpeg_preprocess "$file" "$name"

# whisper转录
whisper_transcribe() {
    local script_dir=$(dirname "$(realpath "$0")")
    export PATH="$script_dir/bin:$PATH"
    if [ ! -f "$name.srt" ]; then
        echo "whisper transcribing ..."
        export GGML_METAL_PATH_RESOURCES="$script_dir/whisper.cpp/"
        local model_name="large-v2"
        local model_path="$script_dir/whisper.cpp/models/ggml-$model_name.bin"
        whisper-cpp -l auto -otxt -osrt -t 6 -mc 32 --prompt "cut at sentence." -m "$model_path" "$1" "$name"
        rm "$name"
    fi
}
shift # 将$1移出参数列表
whisper_transcribe "$@"

# translate字幕
translate_subtitles() {
    if [ ! -f "$1.zh.txt" ]; then
        echo "translating txt ..."
        translate < "$1.txt" > "$1.zh.txt"
    fi
    if [ ! -f "$1.zh.srt" ]; then
        echo "translating srt ..."
        subtitle-translate -i "$1.srt" -o "$1.zh.srt"
        subtitle-translate -i "$1.srt" -o "$1.en-zh.srt" -b
    fi
}
translate_subtitles "$name"

# 修复翻译用词
fix_translation() {
    if [ -f "$1" ]; then
        gsed -i 's/法学硕士/LLM/g' "$1"
    fi
}
fix_translation "$name.zh.txt"
fix_translation "$name.zh.srt"
fix_translation "$name.en-zh.srt"

# edge-tts生成音频
gen_tts() {
    if [ ! -f "$1.zh.mp3" ]; then
        echo "generating tts ..."
        edge-srt-to-speech --voice zh-CN-XiaoxiaoNeural "$1.zh.srt" "$1.zh.mp3"
    fi
}
gen_tts "$name"

# 将音频合并到原视频
merge_tts_audio() {
    if [ ! -f "$2.en-zh.mp4" ]; then
        if [ $bg_pid -ne 0 ]; then
            wait $bg_pid # 等待视频下载完成
        fi
        echo "merging tts audio..."
        ffmpeg -i "$1" -i "$2.zh.mp3" -map 0:v -map 0:a -map 1:a -c:v copy -c:a aac -disposition:a:1 default -disposition:a:0 none "$2.en-zh.mp4"
    fi
}
merge_tts_audio "${video_file:-$file}" "$name"
