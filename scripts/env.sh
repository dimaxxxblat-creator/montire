# Media/render toolchain for this sandbox (no apt access; binaries live outside the repo).
# Re-create them with: bash scripts/setup-media-toolchain.sh
export PATH="/home/user/.local/bin:$PATH"
export HYPERFRAMES_BROWSER_PATH="/home/user/.local/bin/hf-chrome"
export HYPERFRAMES_SKIP_SKILLS=1
export LD_LIBRARY_PATH="/home/user/.local/chromium/lib:/home/user/.local/chromium:/tmp:${LD_LIBRARY_PATH}"
export FONTCONFIG_PATH="${FONTCONFIG_PATH:-/etc/fonts}"
