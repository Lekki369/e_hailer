#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PUB_CACHE="$repo_root/.cache/serverpod-cli"
cd "$repo_root/server/ehailer_server"
exec dart pub global run serverpod_cli:serverpod_cli "$@"
