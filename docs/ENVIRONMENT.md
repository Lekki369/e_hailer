# Local environment and private builds

All deployment-specific keys and identifiers live in ignored local files. The tracked `.env.example` files contain only empty values or demo settings. Existing local configuration is never needed by GitHub's security checks.

## Separate client and server configuration

| Local file | Contents | Included in an app build? |
| --- | --- | --- |
| `.env`, `.env.demo`, or an explicitly selected client JSON/env file | Public Firebase client identifiers, API/map URLs and debug emulator flags | Yes, after allowlist validation. Treat every value as public. |
| `server/ehailer_server/.env` | Paystack secret, mode, backend project and optional credential-file path | Never. The server launcher loads it into its own process. |
| `android/.env` | Keystore location, alias and passwords | Never as Dart defines; supplied only to Gradle's signing environment. |
| Local service-account/signing files | Private credentials or key material | Never commit or package them as app assets. Prefer workload identity/ADC for servers. |

Firebase calls its client API keys [public project identifiers](https://firebase.google.com/docs/projects/api-keys); data access still depends on authentication, rules and service-side authorization. Flutter [does not protect secrets through obfuscation](https://docs.flutter.dev/deployment/obfuscate). Moving values to `.env` keeps them out of source control, but cannot hide values shipped in an APK, iOS app, JavaScript bundle or web configuration file.

## Run locally

From a fresh checkout, create an isolated demo configuration without overwriting existing local files:

```sh
test -f .env.demo || cp .env.example .env.demo
test -f server/ehailer_server/.env || cp server/ehailer_server/.env.example server/ehailer_server/.env
chmod 600 .env.demo server/ehailer_server/.env
flutter pub get
```

Start Firebase emulators as described in [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md), then run the API and app in separate terminals:

```sh
python3 tool/server_env.py
python3 tool/flutter_env.py --env .env.demo run -d chrome
```

For Android emulator access, edit both `FIREBASE_EMULATOR_HOST` and `E_HAILER_API_URL` in the client env to use `10.0.2.2`. Keep the server's emulator hosts on `127.0.0.1`. Do not use demo/test funding with production Firestore.

## Build from validated defines

The wrapper reads a flat JSON or simple `KEY=value` env file, rejects unknown/private keys, duplicate keys, shell expansion and credential-bearing URLs, then calls Flutter with **`--dart-define-from-file`** pointing to a temporary JSON file containing only validated client settings. It removes that temporary file when Flutter exits. Do not add unchecked `--dart-define` overrides; the wrapper rejects them.

```sh
python3 tool/flutter_env.py --env .env build web --release --no-pub
python3 tool/flutter_env.py --env .env build apk --debug --no-pub
python3 tool/flutter_env.py --env .env build ios --simulator --debug --no-pub
```

Release builds require real, complete Firebase client configuration with emulator mode disabled. A missing API URL leaves trusted operations unavailable; configure the deployed HTTPS API before acceptance. Emulator configuration is allowed only for debug builds. Run Flutter commands sequentially.

The same validated values generate ignored `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` and `web/firebase-client-config.js`. These files are local build inputs; their public values are included in distributed apps. The web worker uses the SDK version selected by the installed `firebase_core_web` package and has no hardcoded project fallback or query-string configuration override.

Use `python3 tool/flutter_env.py --configure-only` when preparing native files without launching Flutter. Supported dotenv values are single-line strings, optionally quoted; no command substitution, variable interpolation or `export` statements are evaluated.

## Server and signing secrets

`python3 tool/server_env.py` loads `server/ehailer_server/.env` and starts the Dart API from its package directory. Explicit process/secret-manager variables take precedence over local defaults. To choose another command:

```sh
python3 tool/server_env.py -- dart run bin/main.dart --mode=production
```

Set `GOOGLE_APPLICATION_CREDENTIALS` only on the server when a private local service-account file is necessary. Use an absolute path; the key file itself remains ignored and outside app assets. Do not paste credentials into issue reports or chat. Configure Paystack through [PAYMENTS.md](PAYMENTS.md).

For Android releases, copy `android/.env.example` to `android/.env`, set its private signing values and restrict permissions. Both the wrapper and Gradle reject release builds without signing configuration; they no longer fall back to the debug certificate. Changing application IDs still requires matching Android/iOS project settings and Firebase registrations.

## Keep the public repository clean

```sh
git config --local core.hooksPath .githooks
python3 tool/check_secrets.py
python3 tool/install_gitleaks.py
.cache/security-tools/gitleaks git . --log-opts=--all --redact --no-banner
```

The pre-commit hook checks staged bytes, including files explicitly force-added despite ignore rules. CI repeats the check and scans history. The clean public history has no historical credential exemptions; new key occurrences fail. Hash-only evidence exceptions are restricted to generated checksum manifests. Archived local history may still produce the reviewed findings recorded in the security audit. No secret scanner proves that all possible credentials are absent, and hooks can be bypassed; repository review and GitHub branch protection remain necessary.
