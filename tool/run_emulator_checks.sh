#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${FIRESTORE_EMULATOR_HOST:-}" != 127.0.0.1:* && "${FIRESTORE_EMULATOR_HOST:-}" != localhost:* ]]; then
  echo 'Use: firebase emulators:exec --project demo-ehailer --only auth,firestore "bash tool/run_emulator_checks.sh"' >&2
  exit 1
fi
"${E_HAILER_NODE:-node}" --test tool/firestore_tests/rules.test.js
cd server/ehailer_server
dart test test/operations_test.dart test/payments_test.dart test/api_auth_test.dart test/command_rate_limiter_test.dart --concurrency=1 --reporter expanded
