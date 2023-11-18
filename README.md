将视频、音频文件或 http 链接 => 文本或字幕

## MacOS

### 安装

```
brew install whisper-cpp ffmpeg
brew install yt-dlp jq

git clone https://github.com/ggerganov/whisper.cpp.git
./whisper.cpp/models/download-ggml-model.sh medium-q5_0
```

### 转录出视频文本

```
./transcribe.sh <video_file_or_http_link> [other_whisper_cpp_options]
```

支持的 http 链接 [见 yt-dlp](https://github.com/yt-dlp/yt-dlp/tree/master/yt_dlp/extractor) 、支持的参数选项 [见 whisper.cpp](https://github.com/ggerganov/whisper.cpp)

# Docker

```
./docker/build.sh
./docker/run.sh <video_file_or_http_link> [other_whisper_cpp_options]
```

注：mac m1 的 docker 中用不了 gpu (mps)，转录速度较慢
