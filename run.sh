dir=$(dirname "$(realpath "$0")")
uv run "$dir"/transcribe.py "$@"
