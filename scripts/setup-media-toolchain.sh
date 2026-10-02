#!/usr/bin/env bash
# Recreates the local media/render toolchain for this sandbox.
#
# Why: this sandbox has NO access to apt/debian mirrors, Google's Chrome CDN,
# playwright CDN, jsdelivr/unpkg, Google Fonts or the HeyGen registry.
# What DOES work: registry.npmjs.org, pypi.org, api.github.com + codeload.github.com.
# So every binary below is fetched from npm or PyPI instead of apt/CDNs.
#
# Idempotent: safe to re-run. Installs into ~/.local and ~/.venv-ffmpeg
# (both outside the repo, so nothing heavy lands in Git).
set -euo pipefail

LOCAL=/home/user/.local
BIN="$LOCAL/bin"
CHROME_ROOT="$LOCAL/chromium"
mkdir -p "$BIN" "$CHROME_ROOT"

echo "==> [1/5] ffmpeg (PyPI: imageio-ffmpeg, static ffmpeg 7.0.2)"
if [ ! -x "$BIN/ffmpeg" ]; then
  python3 -m venv /home/user/.venv-ffmpeg
  /home/user/.venv-ffmpeg/bin/pip install -q imageio-ffmpeg
  FF=$(/home/user/.venv-ffmpeg/bin/python -c "import imageio_ffmpeg as f; print(f.get_ffmpeg_exe())")
  mkdir -p "$LOCAL/media"
  cp "$FF" "$LOCAL/media/ffmpeg"
  chmod +x "$LOCAL/media/ffmpeg"
  ln -sf "$LOCAL/media/ffmpeg" "$BIN/ffmpeg"
fi
"$BIN/ffmpeg" -version | head -1

echo "==> [2/5] ffprobe (npm: @ffprobe-installer/ffprobe)"
if [ ! -x "$BIN/ffprobe" ]; then
  T=$(mktemp -d)
  (cd "$T" && npm install --silent --no-audit --no-fund @ffprobe-installer/ffprobe)
  mkdir -p "$LOCAL/media"
  cp "$T/node_modules/@ffprobe-installer/linux-x64/ffprobe" "$LOCAL/media/ffprobe"
  chmod +x "$LOCAL/media/ffprobe"
  ln -sf "$LOCAL/media/ffprobe" "$BIN/ffprobe"
  rm -rf "$T"
fi
"$BIN/ffprobe" -version | head -1

echo "==> [3/5] chrome-headless-shell (npm: @sparticuz/chromium; Google/Playwright CDNs are blocked)"
if [ ! -x "$CHROME_ROOT/chrome-headless-shell" ]; then
  T=$(mktemp -d)
  (cd "$T" && npm install --silent --no-audit --no-fund @sparticuz/chromium)
  SRC="$T/node_modules/@sparticuz/chromium/bin"
  node -e "
const fs=require('fs'),zlib=require('zlib');
function gun(src,dst){return new Promise((res,rej)=>{const o=fs.createWriteStream(dst);fs.createReadStream(src).pipe(zlib.createBrotliDecompress()).pipe(o);o.on('finish',res);o.on('error',rej);});}
(async()=>{
  await gun('$SRC/chromium.br','$CHROME_ROOT/chrome-headless-shell');
  await gun('$SRC/al2023.tar.br','$CHROME_ROOT/al2023.tar');
  await gun('$SRC/swiftshader.tar.br','$CHROME_ROOT/swiftshader.tar');
  await gun('$SRC/fonts.tar.br','$CHROME_ROOT/fonts.tar');
})();
"
  chmod +x "$CHROME_ROOT/chrome-headless-shell"
  mkdir -p "$CHROME_ROOT/lib" "$CHROME_ROOT/swiftshader" "$CHROME_ROOT/fonts"
  tar xf "$CHROME_ROOT/al2023.tar"     -C "$CHROME_ROOT"        # -> lib/ (NSS/NSPR/expat)
  tar xf "$CHROME_ROOT/swiftshader.tar" -C "$CHROME_ROOT/swiftshader"
  tar xf "$CHROME_ROOT/fonts.tar"      -C "$CHROME_ROOT"
  rm -f "$CHROME_ROOT"/*.tar
  # SwiftShader is dlopen'ed from /tmp by this build; also keep a durable copy.
  cp -n "$CHROME_ROOT/swiftshader/"* /tmp/ || true
  rm -rf "$T"
fi
# point the ICD at an absolute path (the packaged one is ./relative)
node -e "
const p='$CHROME_ROOT/swiftshader/vk_swiftshader_icd.json';
const d=JSON.parse(require('fs').readFileSync(p));
d.ICD.library_path='$CHROME_ROOT/swiftshader/libvk_swiftshader.so';
require('fs').writeFileSync(p, JSON.stringify(d,null,2));
"

echo "==> [4/5] browser wrapper (injects --no-sandbox + LD_LIBRARY_PATH)"
cat > "$BIN/hf-chrome" <<'EOF'
#!/usr/bin/env bash
# chrome-headless-shell (@sparticuz/chromium build) + bundled AL2023 NSS libs + SwiftShader.
CHROOT=/home/user/.local/chromium
if [ ! -f /tmp/libvk_swiftshader.so ]; then cp -n "$CHROOT"/swiftshader/* /tmp/ 2>/dev/null || true; fi
export LD_LIBRARY_PATH="$CHROOT/lib:$CHROOT/swiftshader:/tmp:${LD_LIBRARY_PATH}"
exec "$CHROOT/chrome-headless-shell" --no-sandbox --disable-dev-shm-usage --disable-gpu "$@"
EOF
chmod +x "$BIN/hf-chrome"
"$BIN/hf-chrome" --version

echo "==> [5/5] hyperframes CLI sanity"
export PATH="$BIN:$PATH"
export HYPERFRAMES_BROWSER_PATH="$BIN/hf-chrome"
npx -y hyperframes@latest --version

cat <<'EOF'

Done. In every shell that renders, source the env first:

  source scripts/env.sh          # PATH + HYPERFRAMES_BROWSER_PATH + LD_LIBRARY_PATH

Caveats of this sandbox:
  * cdn.jsdelivr.net / unpkg / fonts.gstatic.com are unreachable -> vendor GSAP
    locally (npm i gsap && cp node_modules/gsap/dist/gsap.min.js vendor/) and use
    hyperframes' 18 pre-bundled font families or your own @font-face files.
  * npx hyperframes catalog/add (registry CDN) and HeyGen cloud render/TTS are
    unreachable -> use local render + repo-owned assets.
EOF
