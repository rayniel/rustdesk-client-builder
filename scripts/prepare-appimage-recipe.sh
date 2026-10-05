#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <AppImageBuilder recipe>" >&2
  exit 2
fi

recipe_path=$1
if [[ ! -f "$recipe_path" ]]; then
  echo "AppImageBuilder recipe was not found: $recipe_path" >&2
  exit 1
fi

old_command=' - tar -xvf ./data.tar.xz'
if [[ $(grep --fixed-strings --count -- "$old_command" "$recipe_path") -ne 1 ]]; then
  echo "Expected exactly one Debian data archive extraction command in $recipe_path." >&2
  exit 1
fi

sed -i \
  's|^ - tar -xvf \./data\.tar\.xz$| - bsdtar -xvf "$(find . -maxdepth 1 -type f -name '\''data.tar.*'\'' -print -quit)"|' \
  "$recipe_path"
