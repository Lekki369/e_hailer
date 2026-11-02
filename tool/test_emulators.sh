#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Capture the real Node before standalone Firebase CLI prepends its bundled runtime.
export E_HAILER_NODE="${E_HAILER_NODE:-$(command -v node)}"
"$E_HAILER_NODE" --version >/dev/null
exec firebase emulators:exec --project demo-ehailer --only auth,firestore 'bash tool/run_emulator_checks.sh'
