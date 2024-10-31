import os
import sys
import subprocess
import signal

def cleanup(bg_pid):
    if bg_pid != 0:
        os.kill(bg_pid, signal.SIGINT)
        print("downloading video canceled ...")
    sys.exit()

def download_link(input_arg):
    if input_arg.startswith(('http://', 'https://')):
        dir_name = "output.transcribe"
        os.makedirs(dir_name, exist_ok=True)
        title = subprocess.check_output(['yt-dlp', '--get-title', input_arg]).decode().strip().replace('/', ':')
        file = f"{dir_name}/{title}.wav"

        if not os.path.isfile(file):
            print("downloading audio ...")
            subprocess.run(['yt-dlp', '--extract-audio', '--audio-format', 'wav', '-o', file, input_arg])

        filename = subprocess.check_output(['yt-dlp', '--get-filename', input_arg]).decode().strip()
        ext = filename.split('.')[-1]
        video_file = f"{dir_name}/{title}.{ext}"

        if not os.path.isfile(video_file):
            print("downloading video in background ...")
            bg_pid = subprocess.Popen(['yt-dlp', input_arg, '-o', video_file], stdout=subprocess.DEVNULL).pid
        else:
            bg_pid = 0
    else:
        file = input_arg
        bg_pid = 0

    name = os.path.splitext(file)[0]
    return file, name, bg_pid

def ffmpeg_preprocess(input_file, output_name):
    if not os.path.isfile(f"{output_name}.srt"):
        print("ffmpeg preprocessing ...")
        subprocess.run(['ffmpeg', '-i', input_file, '-ar', '16000', f"{output_name}.tmp.wav"])
        os.rename(f"{output_name}.tmp.wav", output_name)

def whisper_transcribe(input_file, name, other_options):
    script_dir = os.path.dirname(os.path.realpath(__file__))
    os.environ['PATH'] = f"{script_dir}/bin:{os.environ['PATH']}"
    if not os.path.isfile(f"{name}.srt"):
        print("whisper transcribing ...")
        os.environ['GGML_METAL_PATH_RESOURCES'] = f"{script_dir}/whisper.cpp/"
        model_name = "large-v2"
        model_path = f"{script_dir}/whisper.cpp/models/ggml-{model_name}.bin"
        subprocess.run(['whisper-cpp', '-l', 'auto', '-otxt', '-osrt', '-t', '6', '-mc', '32', '--prompt', 'cut at sentence.', '-m', model_path, input_file, name] + other_options)
        os.remove(name)

def fix_transcription(file):
    if os.path.isfile(file):
        subprocess.run(['gsed', '-i', 's/^ >>//g', file])

def translate_subtitles(name):
    if not os.path.isfile(f"{name}.zh.txt"):
        print("translating txt ...")
        with open(f"{name}.txt", 'r') as infile, open(f"{name}.zh.txt", 'w') as outfile:
            subprocess.run(['translate'], stdin=infile, stdout=outfile)

    if not os.path.isfile(f"{name}.zh.srt"):
        print("translating srt ...")
        subprocess.run(['subtitle-translate', '-i', f"{name}.srt", '-o', f"{name}.zh.srt"])
        subprocess.run(['subtitle-translate', '-i', f"{name}.srt", '-o', f"{name}.en-zh.srt", '-b'])

def fix_translation(file):
    if os.path.isfile(file):
        subprocess.run(['gsed', '-i', 's/法学硕士/LLM/g', file])

def gen_tts(name):
    if not os.path.isfile(f"{name}.zh.mp3"):
        print("generating tts ...")
        subprocess.run(['edge-srt-to-speech', '--voice', 'zh-CN-XiaoxiaoNeural', f"{name}.zh.srt", f"{name}.zh.mp3"])

def merge_tts_audio(video_file, name, bg_pid):
    if not os.path.isfile(f"{name}.en-zh.mp4"):
        if bg_pid != 0:
            os.waitpid(bg_pid, 0)
        print("merging tts audio...")
        subprocess.run(['ffmpeg', '-i', video_file, '-i', f"{name}.zh.mp3", '-map', '0:v', '-map', '0:a', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-disposition:a:1', 'default', '-disposition:a:0', 'none', f"{name}.en-zh.mp4"])

def main():
    if len(sys.argv) < 2:
        print("Usage: python transcribe.py <video_file_or_http_link> [other_whisper_cpp_options]")
        sys.exit(1)

    input_arg = sys.argv[1]
    other_options = sys.argv[2:]

    file, name, bg_pid = download_link(input_arg)
    ffmpeg_preprocess(file, name)
    whisper_transcribe(file, name, other_options)
    fix_transcription(f"{name}.srt")
    fix_transcription(f"{name}.txt")
    translate_subtitles(name)
    fix_translation(f"{name}.zh.txt")
    fix_translation(f"{name}.zh.srt")
    fix_translation(f"{name}.en-zh.srt")
    gen_tts(name)
    merge_tts_audio(file, name, bg_pid)

if __name__ == "__main__":
    main()