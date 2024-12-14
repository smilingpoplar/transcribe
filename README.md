将视频、音频文件或 http 链接 => 中文 txt/srt => 中文 tts => 中文音轨添加到视频

## MacOS

### 安装

```
make
```

### 转录出视频文本、生成中文语音

```
./run.sh <video_file_or_http_link> [other_whisper_cpp_options]
```

支持的 http 链接 [见 yt-dlp](https://github.com/yt-dlp/yt-dlp/tree/master/yt_dlp/extractor) 、支持的参数选项 [见 whisper.cpp](https://github.com/ggerganov/whisper.cpp)
