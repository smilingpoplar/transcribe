import os
import re
import shlex
import signal
import subprocess
import sys
from pathlib import Path


def log(msg: str):
    print()  # Ctrl+C时正确换行
    print(f"[transcribe] {msg}")


def run_cmd(cmd: str, capture_output: bool = False) -> str:
    """运行命令并捕获输出（可选）"""
    result = subprocess.run(cmd, shell=True, capture_output=capture_output, text=True)
    if result.returncode != 0:
        log(f"Error executing: {cmd}\n{result.stderr}")
    return result.stdout.strip() if capture_output else ""


bg_process = None


def cleanup(signum, frame):
    """Ctrl+C时取消视频下载"""
    global bg_process
    if bg_process and bg_process.poll() is None:  # 后台进程正在运行
        bg_process.terminate()
        try:
            bg_process.wait(timeout=5)  # 等待后台进程安全退出
        except subprocess.TimeoutExpired:
            bg_process.kill()
        log("Downloading video canceled")
    sys.exit(0)


signal.signal(signal.SIGINT, cleanup)


def download_link(url_or_file: str) -> tuple[Path, Path]:
    """处理视频文件或http链接"""
    if re.match(r"^https?://", url_or_file):
        title: str = run_cmd(
            f'yt-dlp --get-title "{url_or_file}" | sed "s/\\//:/g"', capture_output=True
        )
        dir: Path = Path(f"output.transcribe/{title}")
        dir.mkdir(parents=True, exist_ok=True)
        audio_file: Path = dir / f"{title}.wav"

        if not audio_file.exists():
            log("Downloading audio")
            run_cmd(
                f'yt-dlp --extract-audio --audio-format wav -o "{audio_file}" "{url_or_file}"'
            )

        ext: str = run_cmd(
            f'yt-dlp --get-filename "{url_or_file}"', capture_output=True
        ).split(".")[-1]
        video_file = dir / f"{title}.{ext}"

        if not video_file.exists():
            log("Downloading video in background")
            global bg_process
            bg_process = subprocess.Popen(
                f'yt-dlp "{url_or_file}" -o "{video_file}"', shell=True
            )
    else:
        video_file = audio_file = Path(url_or_file)

    return audio_file, video_file


def ffmpeg_preprocess(audio_file: Path):
    """ffmpeg预处理"""
    if not audio_file.with_suffix(".srt").exists():
        log("FFmpeg preprocessing")
        tmp_file = audio_file.with_suffix(".tmp.wav")
        run_cmd(f'ffmpeg -i "{audio_file}" -ar 16000 "{tmp_file}"')
        tmp_file.rename(audio_file.with_suffix(""))


def whisper_transcribe(audio_file_16k: str, whisper_options: list[str]):
    """whisper转录"""
    script_dir = Path(__file__).resolve().parent
    os.environ["PATH"] = f"{script_dir}/bin:{os.environ['PATH']}"
    if not Path(f"{audio_file_16k}.srt").exists():
        log("Whisper transcribing")
        model_name = "large-v3-turbo"
        model_path = f"{os.environ['HOME']}/.cache/whisper-transcribe/models/ggml-{model_name}.bin"
        run_cmd(
            f'whisper-cpp -l auto -otxt -osrt -t 6 --prompt "Hello." -m "{model_path}" '
            f'{" ".join(shlex.quote(arg) for arg in whisper_options)} "{audio_file_16k}"'
        )
        Path(audio_file_16k).unlink()


def fix_transcription(path: str):
    """修复转录结果"""
    if Path(path).exists():
        run_cmd(f'gsed -i "s/^ >>//g" "{path}"')


def translate_subtitles(name: str):
    """translate字幕"""
    script_dir = Path(__file__).resolve().parent
    fix_file = script_dir / "config/fixes.csv"
    frm, to = Path(f"{name}.txt"), Path(f"{name}.zh.txt")
    if frm.exists() and not to.exists():
        log("Translating txt")
        run_cmd(f'translate -f "{fix_file}" < "{frm}" > "{to}"')

    frm, to = Path(f"{name}.srt"), Path(f"{name}.zh.srt")
    if not to.exists():
        log("Translating srt")
        run_cmd(f'subtitle-translate -f "{fix_file}" -i "{frm}" -o "{to}" -a=false')

    to = Path(f"{name}.zh.align.srt")
    if not to.exists():
        run_cmd(f'subtitle-translate -f "{fix_file}" -i "{frm}" -o "{to}"')

    to = Path(f"{name}.en-zh.srt")
    if not to.exists():
        run_cmd(f'subtitle-translate -f "{fix_file}" -i "{frm}" -o "{to}" -b -a=false')

    to = Path(f"{name}.en-zh.align.srt")
    if not to.exists():
        run_cmd(f'subtitle-translate -f "{fix_file}" -i "{frm}" -o "{to}" -b')


def gen_tts(name: str):
    """edge-tts生成音频"""
    tts_tasks = [
        (".zh.srt", ".zh.mp3"),
        (".zh.align.srt", ".zh.align.mp3"),
    ]
    for subtitle_ext, audio_ext in tts_tasks:
        audio_file = Path(f"{name}{audio_ext}")
        if not audio_file.exists():
            log("Generating tts")
            subtitle_file = f"{name}{subtitle_ext}"
            run_cmd(
                f'edge-srt-to-speech --voice zh-CN-XiaoxiaoNeural "{subtitle_file}" "{audio_file}"'
            )


def merge_tts_audio(video_file: Path):
    """将音频合并到原视频"""
    if video_file.with_suffix(".en-zh.mp4").exists():
        return

    global bg_process
    if bg_process:
        log("Waiting for video download to finish")
        bg_process.wait()

    log("Merging tts audio")
    total_audio_channels, default_audio_channel = 3, 2
    audio_channel_options = [
        f"-disposition:a:{i} default"
        if i == default_audio_channel
        else f"-disposition:a:{i} none"
        for i in range(total_audio_channels)
    ]
    run_cmd(
        f'ffmpeg -i "{video_file}" -i "{video_file.with_suffix(".zh.mp3")}" -i "{video_file.with_suffix(".zh.align.mp3")}" '
        f"-map 0:v -map 0:a -map 1:a -map 2:a -c:v copy -c:a aac "
        f"{' '.join(audio_channel_options)} "
        f'"{video_file.with_suffix(".en-zh.mp4")}"'
    )


def main():
    if len(sys.argv) < 2:
        print("Usage: transcribe <video_file_or_http_link> [other_whisper_cpp_options]")
        sys.exit(1)

    audio_file, video_file = download_link(sys.argv[1])
    ffmpeg_preprocess(audio_file)
    filename = str(audio_file.with_suffix(""))
    whisper_transcribe(filename, sys.argv[2:])
    translate_subtitles(filename)
    gen_tts(filename)
    merge_tts_audio(video_file)


if __name__ == "__main__":
    main()
