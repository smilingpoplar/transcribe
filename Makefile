UNAME_S := $(shell uname -s)
ifneq ($(UNAME_S),Darwin)
	$(error This Makefile is intended to be used on macOS only.)
endif

UNAME_M := $(shell uname -m)
OS_VER  := $(shell sw_vers -productVersion)
MLX_VER := $(shell printf "13.5\n$(OS_VER)" | sort -V | head -n1)
ifeq ($(UNAME_S)$(UNAME_M)$(MLX_VER),Darwinarm6413.5)
    MLX_SUPPORTED := true
else
    MLX_SUPPORTED := false
endif

OS_MAJOR := $(shell echo $(OS_VER) | cut -d. -f1)
define brew_install
	@if [ "$(OS_MAJOR)" = "11" ]; then \
		echo "skip \`brew install $(1)\` on macOS 11"; \
	else \
		if brew ls --versions $(1) > /dev/null; then \
			echo "$(1) is already installed."; \
		else \
			brew install $(1); \
		fi \
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
install: install-common
ifeq ($(MLX_SUPPORTED),true)
	@$(MAKE) install-mlx
else
	@$(MAKE) install-nomlx
endif
	@uv tool update-shell

.PHONY: install-common
install-common:
	$(call brew_install,ffmpeg)
	$(call brew_install,uv)
	$(call brew_install,gsed)
	@uv tool install -U "yt-dlp[default]"
	@mkdir -p bin/
	@GOBIN=`realpath bin/` go install github.com/smilingpoplar/translate/cmd/translate@latest
	@GOBIN=`realpath bin/` go install github.com/smilingpoplar/subtitle-translate/cmd/subtitle-translate@latest
	@uv tool install edge-srt-to-speech
	@uv tool install -e .

.PHONY: install-mlx
install-mlx:
	@echo "MLX supported..."
	@uv tool install parakeet-mlx

.PHONY: install-nomlx
install-nomlx:
	@if [ ! -d "whisper.cpp" ]; then \
		git clone https://github.com/ggerganov/whisper.cpp.git; \
	fi
	@mkdir -p bin/
	cd whisper.cpp && make -j && cp main ../bin/whisper-cpp
	$(call download_model,large-v3-turbo)
	
