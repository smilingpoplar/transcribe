UNAME_S := $(shell uname -s)
ifneq ($(UNAME_S),Darwin)
  $(error This Makefile is intended to be used on macOS only.)
endif

define brew_install
    @if brew ls --versions $(1) > /dev/null; then \
        echo $(1) is already installed.; \
    else \
        brew install $(1); \
    fi
endef

define download_model
	@MODEL_PATH="$${HOME}/.cache/whisper-transcribe/models/"; \
	MODEL_NAME="ggml-$(1).bin"; \
	if [ -f "$${MODEL_PATH}$${MODEL_NAME}" ]; then \
		echo 模型$${MODEL_NAME}已存在。\\n若模型下载曾中断，请到$${MODEL_PATH}目录手动删除后重试。; \
	else \
		mkdir -p $${MODEL_PATH}; \
		whisper.cpp/models/download-ggml-model.sh $(1) $${MODEL_PATH}; \
	fi
endef

.PHONY: install
install:
	$(call brew_install,ffmpeg)
	$(call brew_install,uv)
	$(call brew_install,gsed)
	@uv tool install -U "yt-dlp[default]"
	@if [ ! -d "whisper.cpp" ]; then \
		git clone https://github.com/ggerganov/whisper.cpp.git; \
	fi
	@mkdir -p bin/
	cd whisper.cpp && make -j && cp main ../bin/whisper-cpp
	GOBIN=`realpath bin/` go install github.com/smilingpoplar/translate/cmd/translate@latest
	GOBIN=`realpath bin/` go install github.com/smilingpoplar/subtitle-translate/cmd/subtitle-translate@latest
	@uv tool install edge-srt-to-speech
	$(call download_model,large-v3-turbo)
	@uv tool install -e .
	@uv tool update-shell
	