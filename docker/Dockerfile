FROM debian:bullseye AS builder
WORKDIR /app

RUN apt update && apt install -y git make g++
RUN git clone https://github.com/ggerganov/whisper.cpp.git
RUN cd whisper.cpp && make -j

RUN apt install -y wget
RUN git clone whisper.cpp whisper.cpp.clone
RUN ./whisper.cpp.clone/models/download-ggml-model.sh medium-q5_0

RUN apt install -y python3 python3-pip
RUN pip install yt-dlp


FROM debian:bullseye-slim
WORKDIR /app

RUN apt update && apt install -y ffmpeg
COPY --from=builder /app/whisper.cpp/main /usr/bin/whisper-cpp
COPY --from=builder /app/whisper.cpp.clone whisper.cpp

RUN apt install -y python3
COPY --from=builder /usr/local/lib/python3.9/dist-packages /usr/local/lib/python3.9/dist-packages
COPY --from=builder /usr/local/bin/yt-dlp /usr/local/bin/yt-dlp

RUN apt install -y jq
COPY transcribe.sh .
