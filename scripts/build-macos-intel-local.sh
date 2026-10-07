#!/usr/bin/env bash
set -euo pipefail

builder_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
rustdesk_root=${RUSTDESK_ROOT:?Set RUSTDESK_ROOT to a local RustDesk source checkout.}
rustdesk_root=$(cd "$rustdesk_root" && pwd)
rust_version=${RUST_VERSION:-1.81}
flutter_version=${FLUTTER_VERSION:-3.24.5}
vcpkg_commit=${VCPKG_COMMIT_ID:-9e593bb18ea69cc5095e012465dcd675a822ed0d}
vcpkg_root=${VCPKG_ROOT:-"$HOME/.cache/rustdesk-client-builder/vcpkg"}

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "x86_64" ]]; then
  echo "This script must run on an Intel Mac to produce a native x86_64 macOS client." >&2
  exit 1
fi

for command in brew cargo curl flutter git python3 rustup unzip; do
  command -v "$command" >/dev/null || {
    echo "Required command was not found: $command" >&2
    exit 1
  }
done

if [[ ! -f "$rustdesk_root/build.py" || ! -f "$rustdesk_root/Cargo.toml" ]]; then
  echo "RUSTDESK_ROOT is not a RustDesk source checkout: $rustdesk_root" >&2
  exit 1
fi

if ! flutter --version | grep -Fq "$flutter_version"; then
  echo "Flutter $flutter_version is required; found:" >&2
  flutter --version >&2
  exit 1
fi

echo "==> Install macOS build dependencies"
brew install cmake create-dmg llvm ninja pkg-config

if ! command -v nasm >/dev/null || ! nasm -v | grep -Fq "2.16.03"; then
  temporary_directory=$(mktemp -d)
  trap 'rm -rf "$temporary_directory"' EXIT
  curl --fail --location --silent --show-error \
    --output "$temporary_directory/nasm.zip" \
    https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/macosx/nasm-2.16.03-macosx.zip
  unzip -q "$temporary_directory/nasm.zip" -d "$temporary_directory"
  sudo install -m 755 "$temporary_directory/nasm-2.16.03/nasm" /usr/local/bin/nasm
fi
nasm -v

echo "==> Setup Rust $rust_version"
rustup toolchain install "$rust_version" --profile minimal
rustup target add x86_64-apple-darwin --toolchain "$rust_version"
rustup component add rustfmt --toolchain "$rust_version"
export RUSTUP_TOOLCHAIN="$rust_version"

echo "==> Setup vcpkg"
if [[ ! -d "$vcpkg_root/.git" ]]; then
  mkdir -p "$(dirname "$vcpkg_root")"
  git clone https://github.com/microsoft/vcpkg "$vcpkg_root"
fi
git -C "$vcpkg_root" fetch --depth 1 origin "$vcpkg_commit"
git -C "$vcpkg_root" reset --hard "$vcpkg_commit"
"$vcpkg_root/bootstrap-vcpkg.sh" -disableMetrics
export VCPKG_ROOT="$vcpkg_root"
export VCPKG_DEFAULT_TRIPLET=x64-osx
export VCPKG_DEFAULT_HOST_TRIPLET=x64-osx
pushd "$rustdesk_root" >/dev/null
"$VCPKG_ROOT/vcpkg" install \
  --triplet "$VCPKG_DEFAULT_TRIPLET" \
  --x-install-root="$VCPKG_ROOT/installed"
popd >/dev/null

echo "==> Generate Flutter Rust Bridge files"
cargo install cargo-expand --version 1.0.95 --locked
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid --locked
sed -i '' 's/extended_text: 14.0.0/extended_text: 13.0.0/g' "$rustdesk_root/flutter/pubspec.yaml"
pushd "$rustdesk_root/flutter" >/dev/null
flutter pub get
popd >/dev/null
"${HOME}/.cargo/bin/flutter_rust_bridge_codegen" \
  --rust-input "$rustdesk_root/src/flutter_ffi.rs" \
  --dart-output "$rustdesk_root/flutter/lib/generated_bridge.dart" \
  --c-output "$rustdesk_root/flutter/macos/Runner/bridge_generated.h"
cp "$rustdesk_root/flutter/macos/Runner/bridge_generated.h" \
  "$rustdesk_root/flutter/ios/Runner/bridge_generated.h"

echo "==> Apply Flutter patch"
patch_path="$rustdesk_root/.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff"
if [[ -f "$patch_path" ]]; then
  flutter_root=$(dirname "$(dirname "$(command -v flutter)")")
  if git -C "$flutter_root" apply --check "$patch_path"; then
    git -C "$flutter_root" apply "$patch_path"
  elif git -C "$flutter_root" apply --reverse --check "$patch_path"; then
    echo "Flutter patch is already applied."
  else
    echo "Flutter patch cannot be applied to the installed SDK." >&2
    exit 1
  fi
fi

echo "==> Apply embedded self-host configuration"
bash "$builder_root/scripts/apply-embedded-server-config.sh" "$rustdesk_root"

echo "==> Build RustDesk for macOS Intel"
pushd "$rustdesk_root" >/dev/null
flutter config --enable-macos-desktop
python3 ./build.py --flutter --hwcodec --unix-file-copy-paste

app_path="./flutter/build/macos/Build/Products/Release/RustDesk.app"
test -d "$app_path" || { echo "Built RustDesk app was not found: $app_path" >&2; exit 1; }
version=$(awk -F '"' '/^version = / { print $2; exit }' Cargo.toml)
test -n "$version" || { echo "Unable to determine RustDesk version." >&2; exit 1; }
output_path="$builder_root/dist/rustdesk-${version}-x86_64-unsigned.dmg"
mkdir -p "$builder_root/dist"
rm -f "$output_path"
create-dmg \
  --icon "RustDesk.app" 200 190 \
  --hide-extension "RustDesk.app" \
  --window-size 800 400 \
  --app-drop-link 600 185 \
  "$output_path" \
  "$app_path"
popd >/dev/null

echo "Built Intel macOS DMG: $output_path"
