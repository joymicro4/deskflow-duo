#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -ne 2 ]; then echo 'Usage: scripts/install.sh CONFIG NODE' >&2; exit 2; fi
if ! command -v python3 >/dev/null || ! command -v swiftc >/dev/null; then
  echo 'Install Python 3 and Xcode Command Line Tools (xcode-select --install), then retry.' >&2
  exit 1
fi
exec python3 scripts/duo.py install --config "$1" --node "$2"
