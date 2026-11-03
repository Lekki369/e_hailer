# Validation record

Local verification through **2026-11-02**, covering the trusted API, Paystack integration and private environment/build changes. The initial repository baseline was `3bacce3`; the existing root `AGENTS.md` remains unchanged. This record describes local evidence, not production acceptance.

## Tests and analysis

| Check | Result | What it establishes |
| --- | --- | --- |
| Flutter analyzer | No issues | App and tests resolve against the selected SDK and packages. |
| Flutter tests | **189 passed** | Domain behavior, route guards, safe API retries/URLs, map parsing, recovery, profile lifecycle, hosted checkout and layouts. |
| Server and generated-client analyzers | No issues | Handwritten backend and generated protocol have no analyzer findings. |
| Real Firestore + Serverpod tests | **38 passed** | 15 operations-policy scenarios, 19 payment scenarios and 4 actual authenticated HTTP tests. |
| Provider/configuration unit tests | **7 passed** | Paystack request/signature validation, redacted errors, isolated test funding and emulator startup restrictions. |
| Firestore rules tests | **13 passed** | Role/owner/anonymous boundaries, private PINs, redacted tracking and denied client financial/payment writes. |
| Environment/security-tool tests | **9 passed** | Safe dotenv/JSON parsing, private-key exclusion, define-override rejection, generated configuration and release signing requirements. |
| Web-worker tests | **3 passed** | Generated configuration, trusted SDK script origin and no remote SDK registration in emulator mode. |
| Secret and dependency checks | Completed | Current publishable files pass the local guard and Gitleaks; history findings and advisory scope are in `SECURITY_AUDIT.md`. |

The backend/API total includes the transactional scenarios; it is not an additional 38 unrelated tests. Earlier memory-store operation tests also passed (15). The payment HTTP test races two valid signed webhooks with authenticated verification and observes exactly one ledger credit; forged/tampered webhook requests add no money. No real Paystack key or checkout is needed for these tests.

The final emulator runner uses an explicit working Node executable when required. This Mac's concurrent Homebrew upgrade temporarily broke Node's simdjson library link; a task-local wrapper used the matching installed library without changing global symlinks. The HTTP test allows bounded cold Dart startup and fails early if the server exits.

## UI and architecture evidence

The main responsive suite covers nine screens at **320, 600 and 1280 logical pixels**, each with **1× and 2× text scaling**: 54 layout cases. The checkout adds six cases using the bundled font and asserts that the status-check action remains reachable. Tests also cover asynchronous dialog completion after closing, browser-launch failure and recovery of an existing payment.

Selected synthetic widget captures were inspected, including checkout at 320 px with normal and enlarged text. These are widget renders, not physical-device screenshots. Capture with:

```sh
flutter test --no-pub --dart-define=CAPTURE_UI=true test/presentation/wallet_top_up_test.dart
```

Capture flags contain no deployment credentials. Images and logs stay in ignored `.cache/ui/` and `.cache/validation/`. Archify's delivery/read and payment diagrams include source-snapshot evidence and automated browser receipts. Light/dark captures of the payment topology were inspected; subsequent evidence refreshes preserve that topology. Graphify is a structural index, not proof of runtime behavior.

## Current build checks

| Target | Result | Scope |
| --- | --- | --- |
| Web release | Passed | `python3 tool/flutter_env.py build web --release --no-pub`; output `build/web`. Wasm dry run also passed; no deployed web acceptance is claimed. |
| Android debug | Passed | Same wrapper with `build apk --debug --no-pub`; output `build/app/outputs/flutter-apk/app-debug.apk`. Explicitly a debug build. |
| iOS Simulator debug | Passed | Same wrapper with `build ios --simulator --debug --no-pub`; output `build/ios/iphonesimulator/Runner.app`, Xcode 26.6 and Swift Package Manager. |
| Server native bundle | Passed | `dart build cli --target=bin/main.dart`; macOS x64 bundle with native assets. Production YAML starts locally, liveness returns 200 and unauthenticated RPC returns 401. |
| Android release guard | Expected refusal verified | Direct Gradle `:app:validateReleaseSigning` rejects absent private signing configuration. No release APK was falsely signed with the debug key. |

App builds use the validated local client env and generated platform configuration, with Flutter **3.47.9 / Dart 3.13.7**. Android uses Flutter's NDK 28.2.13676358 and emits upstream Kotlin migration/deprecation warnings, but compilation passes. No private server credential is supplied to Flutter. No physical device was installed or tested, Linux/container bundle built, or production signing completed.

## Limits and release prerequisites

- Emulators use `demo-ehailer` and local OSRM/Paystack stubs. They do not prove deployed rules, IAM, App Check, provider delivery or production routing availability.
- No payment was taken, bank transfer sent, backend deployed, Firestore rule published or production data migrated. GitHub source publication is separate from application deployment.
- Review deployed Firebase configuration and migrate/reconcile legacy balances, PINs and tracking data before rollout. Old rules allowed public delivery reads and client financial writes; changing this repository does not update a running Firebase project.
- Complete real Paystack test-mode acceptance, reconciliation/refunds/chargebacks, ingress rate limits, monitoring, retention and operating policies before live funding.
- Verify customer/driver/staff flows on physical Android/iPhone devices, including permission denial, reconnection, authentication, deep links and app lifecycle behavior.
- No line-coverage percentage, exhaustive historical code proof, absence of all vulnerabilities or production-readiness certification is claimed.

## Driver access and API quota follow-up — 2026-11-02

The original counts/build checks above describe the publication snapshot. Follow-up implementation is based on commit `09a0649663a2ab44e3ce57fa50c96442bad1d7a3`, with local source changes for administrator driver approval, operating-area permissions, coarse offer previews and durable authenticated-RPC quotas.

- Flutter and backend analyzers pass with no issues.
- **197 Flutter tests pass** in the final full run, including the two driver-subscription scenarios and 60 responsive cases across ten screens at 320/600/1280 px with 1×/2× text. The fleet roster includes pending and approved synthetic drivers. The local log is `.cache/validation/driver-access-flutter-tests.txt`.
- **15 Firestore rules tests pass**, including protected approval metadata, denied self-approval/online bypass, vehicle/area filtering, list limits, revoked access and private quota/audit collections.
- **45 emulator/backend/API tests pass**: 18 operations-policy scenarios, 19 payment scenarios, 5 actual HTTP tests and 3 durable-quota tests. Concurrent funding attempts share one allowance across Firestore transactions; separate limiter instances observe persisted state. The HTTP test seeds exhausted buckets to verify rejection before invalid-command/payment work; exact burst/refill tests inject a clock rather than assuming a fixed window.
- The client subscription tests pass for pending/offline/unscoped drivers and cancellation of an approved driver's offers subscription after revocation. Retry tests also exercise `resource-exhausted` without losing the idempotency key.
- The publishable-file guard reports **534 files checked, 0 findings**; `git diff --check` passes. The new Firestore index is valid JSON. Dependency advisories and Git history were not rescanned in this follow-up.

The approval screen has also been added to responsive widget coverage. No application build, physical-device flow, live Firebase rule/index publication, production deletion or real Paystack acceptance was performed in this follow-up. The user plans to clear Firebase for a fresh-start rollout. See [DRIVER_ACCESS_AND_ABUSE_CONTROLS.md](DRIVER_ACCESS_AND_ABUSE_CONTROLS.md) for the workflow, exact quota values and deployment checklist.
