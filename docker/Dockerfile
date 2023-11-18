FROM alpine:3.18.4 AS builder
WORKDIR /app

RUN apk add --no-cache git make g++
RUN git clone https://github.com/ggerganov/whisper.cpp.git
RUN cd whisper.cpp && \
    sed -i 's/-mcpu=native//g' Makefile && \
    make -j

RUN git clone whisper.cpp whisper.cpp.clone
RUN apk add --no-cache bash wget
RUN ./whisper.cpp.clone/models/download-ggml-model.sh medium-q5_0

RUN apk add --no-cache python3 py3-pip
RUN pip install yt-dlp


FROM alpine:3.18.4
WORKDIR /app

RUN apk add --no-cache ffmpeg
COPY --from=builder /app/whisper.cpp/main /usr/bin/whisper-cpp
COPY --from=builder /app/whisper.cpp.clone whisper.cpp

RUN apk add --no-cache python3
COPY --from=builder /usr/lib/python3.11/site-packages /usr/lib/python3.11/site-packages/
COPY --from=builder /usr/bin/yt-dlp /usr/bin/yt-dlp

RUN apk add --no-cache bash jq
COPY transcribe.sh .
