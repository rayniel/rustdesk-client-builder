#!/usr/bin/env bash
set -euo pipefail

echo "==> Rust version"
rustc -Vv
cargo -V

echo "==> Python version"
python3 --version

echo "==> Flutter version"
flutter --version
flutter config --enable-linux-desktop

echo "==> Build RustDesk Linux (Flutter)"
python3 ./build.py --flutter --hwcodec --unix-file-copy-paste

server_host=${RUSTDESK_HOST:-}
server_host=$(printf '%s' "$server_host" | xargs)
if [[ ${EMBED_SELFHOST_CONFIG:-} != "false" && -n "$server_host" ]]; then
  client_library_path="./flutter/build/linux/x64/release/bundle/lib/librustdesk.so"
  if [[ ! -f "$client_library_path" ]]; then
    echo "Built RustDesk library was not found: $client_library_path" >&2
    exit 1
  fi

  if ! grep --binary-files=text --fixed-strings --quiet -- "$server_host" "$client_library_path"; then
    echo "The built RustDesk library does not contain the configured self-hosted server. Refusing to package it." >&2
    exit 1
  fi

  echo "Verified that the packaged RustDesk library contains the configured self-hosted server."
fi

echo "==> Build completed"
