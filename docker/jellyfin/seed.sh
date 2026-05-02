#!/usr/bin/env bash
# Downloads a couple of public-domain shorts into ./media so a freshly
# launched Jellyfin has something to index. Idempotent: skips files that
# already exist.

set -euo pipefail

cd "$(dirname "$0")"
mkdir -p media/Movies

download() {
  local dest="$1"
  local url="$2"
  if [[ -s "$dest" ]]; then
    echo "[seed] $dest already present, skipping"
    return
  fi
  echo "[seed] fetching $dest"
  curl -L --fail --silent --show-error -o "$dest.partial" "$url"
  mv "$dest.partial" "$dest"
}

# Blender Foundation open movies. Small enough to download in seconds,
# rich enough metadata that TheMovieDB can pull a poster + synopsis.
download "media/Movies/Big Buck Bunny (2008).mp4" \
  "https://download.blender.org/peach/bigbuckbunny_movies/big_buck_bunny_480p_h264.mov"

download "media/Movies/Sintel (2010).mp4" \
  "https://archive.org/download/Sintel/sintel-2048-stereo.mp4"

download "media/Movies/Elephants Dream (2006).mp4" \
  "https://archive.org/download/ElephantsDream/ed_1024.mp4"

echo "[seed] done. Now run: docker compose up -d"
