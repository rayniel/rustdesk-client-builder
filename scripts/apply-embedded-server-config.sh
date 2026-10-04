#!/usr/bin/env bash
set -euo pipefail

rustdesk_root=${1:?Usage: apply-embedded-server-config.sh <rustdesk-source-directory>}
config_path="$rustdesk_root/libs/hbb_common/src/config.rs"
server_host=${RUSTDESK_HOST:-}
public_key=${RUSTDESK_KEY:-}

server_host=$(printf '%s' "$server_host" | xargs)
public_key=$(printf '%s' "$public_key" | xargs)

if [[ -z "$server_host" && -z "$public_key" ]]; then
  echo "No self-hosted secrets supplied; retaining RustDesk upstream defaults."
  exit 0
fi

if [[ -z "$server_host" || -z "$public_key" ]]; then
  echo "Embedded self-hosted builds require both RUSTDESK_HOST and RUSTDESK_KEY." >&2
  exit 1
fi

if [[ ! -f "$config_path" ]]; then
  echo "RustDesk shared configuration source was not found: $config_path" >&2
  exit 1
fi

python3 - "$config_path" <<'PY'
import os
import re
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
server_host = os.environ["RUSTDESK_HOST"].strip()
public_key = os.environ["RUSTDESK_KEY"].strip()

def escape_rust_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')

server_replacement = (
    f'pub const RENDEZVOUS_SERVERS: &[&str] = &["{escape_rust_string(server_host)}"];'
)
key_replacement = (
    f'pub const RS_PUB_KEY: &str = "{escape_rust_string(public_key)}";'
)
exe_server_replacement = (
    "pub static ref EXE_RENDEZVOUS_SERVER: RwLock<String> = "
    f'RwLock::new("{escape_rust_string(server_host)}".to_owned());'
)

source = config_path.read_text(encoding="utf-8")
source, server_count = re.subn(
    r'pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[[^\r\n]*\];',
    server_replacement,
    source,
    count=1,
)
if server_count != 1:
    raise SystemExit(
        "Unable to locate the RustDesk RENDEZVOUS_SERVERS constant. "
        "The upstream source layout changed."
    )

source, key_count = re.subn(
    r'pub const RS_PUB_KEY: &str = "[^"\r\n]*";',
    key_replacement,
    source,
    count=1,
)
if key_count != 1:
    raise SystemExit(
        "Unable to locate the RustDesk RS_PUB_KEY constant. "
        "The upstream source layout changed."
    )

source, exe_server_count = re.subn(
    r'pub static ref EXE_RENDEZVOUS_SERVER: RwLock<String> = Default::default\(\);',
    exe_server_replacement,
    source,
    count=1,
)
if exe_server_count != 1:
    raise SystemExit(
        "Unable to locate the RustDesk EXE_RENDEZVOUS_SERVER default. "
        "The upstream source layout changed."
    )

if (
    source.count(server_replacement) != 1
    or source.count(key_replacement) != 1
    or source.count(exe_server_replacement) != 1
):
    raise SystemExit("Embedded self-hosted configuration verification failed.")

config_path.write_text(source, encoding="utf-8")
PY

echo "Embedded a self-hosted server and public key into RustDesk source."
