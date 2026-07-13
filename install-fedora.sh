#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec env KAMALEN_PROFILE=fedora "$ROOT_DIR/scripts/install/experimental-installer.sh" "$@"
