# Development guide

## Requirements and structure

Use Flutter stable 3.47.x or newer with Dart >=3.12.2, Serverpod CLI **4.1.0**, Node compatible with Firebase 13/rules-unit-testing 6, and Java 21+ for the Firestore emulator. Keep Flutter, generated client and server dependency lockfiles. iOS uses Swift Package Manager; do not add CocoaPods. Existing contributor instructions in `AGENTS.md` remain unchanged.

```sh
flutter pub get
(cd server/ehailer_client && dart pub get)
(cd server/ehailer_server && dart pub get)
npm --prefix tool/firestore_tests ci --ignore-scripts
PUB_CACHE="$PWD/.cache/serverpod-cli" dart pub global activate serverpod_cli 4.1.0
```

## Local backend and app

Start the Firebase Auth/Firestore emulators in one terminal:

```sh
firebase emulators:start --project demo-ehailer --only auth,firestore
```

Run the API in another:

```sh
test -f server/ehailer_server/.env || cp server/ehailer_server/.env.example server/ehailer_server/.env
python3 tool/server_env.py
```

Run Flutter against the same demo project:

```sh
test -f .env.demo || cp .env.example .env.demo
python3 tool/flutter_env.py --env .env.demo run -d chrome
```

For Android's emulator, use `10.0.2.2` in both client host arguments. For physical devices, use reachable development hosts and HTTPS; the client permits cleartext API traffic only on debug loopback/Android emulator addresses. On this Mac use the existing Pixel 9 Metal launcher described in the supplied agent instructions. Do not confuse an Android-produced screenshot with proof that the Mac viewer repainted.

Customer/driver registration creates only unprivileged profiles. Provision staff through a trusted administrative process; there is no role switcher. Never put service-account credentials or payment secrets in Flutter defines/assets. Server production authentication uses Application Default Credentials; production hosting/configuration is intentionally not deployed by this repository change.

## Quality checks

```sh
dart format lib test server/ehailer_server/lib server/ehailer_server/bin server/ehailer_server/test server/ehailer_client/lib
flutter analyze --no-pub
flutter test --no-pub
(cd server/ehailer_server && dart analyze && dart test)
bash tool/test_emulators.sh
npm --prefix tool/firestore_tests audit
```

Run Flutter commands sequentially. `test_emulators.sh` uses a `demo-` project, resets only emulator data, and runs rules, real Firestore transaction races, authenticated Serverpod HTTP tests and signed payment-webhook checks. It captures the real Node executable before the standalone Firebase CLI alters PATH; `E_HAILER_NODE=/absolute/path/to/node` can select another working runtime. Tests use local OSRM and Paystack stubs; they do not probe production routing or process real money.

For hosted funding, follow [PAYMENTS.md](PAYMENTS.md). Use [ENVIRONMENT.md](ENVIRONMENT.md) for separate client/server/signing files. The launchers load local configuration without shell evaluation; plain Dart does not load `.env` automatically. The [deployment guide](DEPLOYMENT.md) explains the production configuration and native bundle. Never use a production wallet database for test credits.

Capture fixture-based layout evidence with:

```sh
flutter test --no-pub --dart-define=CAPTURE_UI=true test/presentation/responsive_layout_test.dart
```

Images go to ignored `.cache/ui/`. They are rendered Flutter widget fixtures, not physical-device acceptance. See `VALIDATION.md` for the checks actually completed.

## Platform builds

Run these separately after the checks above, using a complete real Firebase client `.env` with emulator mode disabled:

```sh
python3 tool/flutter_env.py --env .env build web --release --no-pub
python3 tool/flutter_env.py --env .env build apk --debug --no-pub
python3 tool/flutter_env.py --env .env build ios --simulator --debug --no-pub
```

Android follows Flutter's compile/target SDK and NDK defaults; install those SDK components instead of substituting an installed preview. iOS resolves native dependencies through Swift Package Manager. Build outputs remain ignored under `build/`; completed builds and environment failures are recorded in [VALIDATION.md](VALIDATION.md).

Before distributing a mobile release, replace the template application/bundle identifiers, configure matching Firebase apps and release signing, and verify domain associations. Android release builds require separate private signing credentials and reject the former debug-certificate fallback. A debug APK or simulator build does not establish store signing or physical-device acceptance.

## API generation and feature changes

```sh
bash tool/serverpod.sh generate
```

Keep the CLI, `serverpod`, `serverpod_test` and `serverpod_client` versions aligned. Generation is limited to API contracts; handwritten Flutter domain models remain Equatable/manual. Add domain policy tests, update trusted commands and read projections, extend rules tests, then adapt providers/UI. Register routes/assets centrally. Never implement a financial mutation directly in a widget or Firebase client service.

## Maps and sharing configuration

Server `OSRM_BASE_URL` controls authoritative quotes. Flutter `OSRM_BASE_URL` controls preview routing. `NOMINATIM_BASE_URL` enables an explicitly configured Nominatim-compatible address service; without it customers select a map pin and enter directions. For public deployment use a service with capacity and policy appropriate to the application, preferably an owned/proxied endpoint with shared caching and rate limits.

The [public Nominatim policy](https://operations.osmfoundation.org/policies/nominatim/) caps **aggregate application traffic** at one request per second, prohibits autocomplete and requires attribution and identification. The local client throttle alone cannot enforce an application-wide limit. The public endpoint is not the default for this app. Review the [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/) before distributing builds using public tiles; there is no SLA.

Set `E_HAILER_PUBLIC_URL=https://your-confirmed-host/` only after configuring hosting/deep links. Sharing otherwise copies a tracking code rather than inventing a live website. Mobile deep-link domain association and production web routing remain deployment tasks.

## Architecture tooling

See `GRAPHIFY.md` for the scoped structural map. Archify renders `docs/architecture.json` into `docs/architecture.html`; preserve source evidence and the receipt when changing it. Architecture documentation should describe first-party behavior; reference-project notes belong in `REFERENCE_REVIEW.md`.

After reviewing the candidate's source line ranges, refresh the isolated evidence snapshot and finalize the diagram:

```sh
python3 tool/architecture_snapshot.py
node .agents/skills/archify/bin/archify.mjs finalize architecture \
  docs/architecture.json docs/architecture.html \
  --repo-root .cache/architecture-source --quality showcase \
  --out-dir .cache/architecture-review-next --json
```

Use a fresh `--out-dir` for each changed artifact after a browser check has run. The snapshot includes only the cited source files and never commits the application worktree. Source links are intentionally local-only until the reviewed implementation is committed upstream. Archify validates source ranges, delivers HTML, checks provenance and measures it in a real browser. Optional screenshots require `visual-check --require-provenance`; inspect them before claiming visual review.

For payment architecture, pass `docs/payments-architecture.json` to the snapshot script and use that candidate with `docs/payments-architecture.html` in the finalize command. Run diagram deliveries sequentially: Archify locks their shared output directory while publishing.
