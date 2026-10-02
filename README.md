# montire

## What this repo is

Workspace for producing YouTube videos with [HyperFrames](https://github.com/heygen-com/hyperframes)
("write HTML, render video") + ffmpeg. Agent skills from `heygen-com/hyperframes`
are installed project-locally in `.claude/skills/` (see `skills-lock.json`),
installed via `npx skills add heygen-com/hyperframes --agent claude-code --copy`.

## Sandbox toolchain

This sandbox blocks apt/Debian mirrors, Google's Chrome CDN, jsdelivr/unpkg,
Google Fonts and the HeyGen registry; npm + PyPI + GitHub API work.
`scripts/setup-media-toolchain.sh` rebuilds everything from those sources
(ffmpeg 7.0.2 via PyPI, ffprobe via npm, chrome-headless-shell via
@sparticuz/chromium). Render shells must start with:

```bash
source scripts/env.sh
```

Compositions must vendor their JS runtimes locally (`npm i gsap` -> `vendor/gsap.min.js`)
and stick to HyperFrames' 18 pre-bundled font families (they embed offline,
Cyrillic included) or self-hosted `@font-face` files.
