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
	@if [ -f "whisper.cpp/models/ggml-$(1).bin" ]; then \
		echo 模型ggml-$(1).bin已存在。\\n若模型下载曾中断，请到whisper.cpp/models/目录手动删除后重试。; \
	else \
		whisper.cpp/models/download-ggml-model.sh $(1); \
	fi
endef

.PHONY: install
install:
	$(call brew_install,ffmpeg)
	$(call brew_install,pipx)
	@pipx install yt-dlp
	$(call brew_install,jq)
	@if [ ! -d "whisper.cpp" ]; then \
		git clone https://github.com/ggerganov/whisper.cpp.git; \
	fi
	@mkdir -p bin/
	cd whisper.cpp && make -j && cp main ../bin/whisper-cpp
	GOBIN=`realpath bin/` go install github.com/smilingpoplar/translate/cmd/translate@latest
	GOBIN=`realpath bin/` go install github.com/smilingpoplar/subtitle-translate/cmd/subtitle-translate@latest
	@pipx install edge-srt-to-speech
	$(call download_model,large-v2)
