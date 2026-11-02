# Dependencies and toolchain

Verified against package registries on **2026-11-01**. Stable releases are used; prereleases are not selected. The lockfiles are the reproducible installation record.

The 2026-11-02 security pass also checked 208 resolved Pub package/version pairs against OSV (no known advisories returned) and the npm test lockfile (0 audit vulnerabilities). The web notification worker now follows `firebase_core_web`'s supported Firebase JS SDK, **13.1.0**, instead of independently pinning 10.7.0. See [SECURITY_AUDIT.md](SECURITY_AUDIT.md) for scope and limits.

## Dart packages

| Package | App | Server | Generated client |
| --- | --- | --- | --- |
| cached_network_image | 4.0.6 | — | — |
| cloud_firestore | 7.1.0 | — | — |
| crypto | 3.0.8 | 3.0.8 | — |
| cupertino_icons | 2.0.0 | — | — |
| equatable | 3.0.0 | 3.0.0 | — |
| firebase_admin_sdk | — | 0.5.6 | — |
| firebase_auth | 7.0.1 | — | — |
| firebase_core | 5.1.0 | — | — |
| firebase_messaging | 17.0.1 | — | — |
| flutter_hooks | 0.21.3+1 | — | — |
| flutter_lints | 6.0.0 | — | — |
| flutter_map | 8.3.2 | — | — |
| flutter_screenutil | 5.9.3 | — | — |
| flutter_svg | 2.3.2 | — | — |
| fpdart | 1.2.0 | — | — |
| geolocator | 14.1.2 | — | — |
| go_router | 18.1.2 | — | — |
| google_cloud_firestore | — | 0.5.5 | — |
| hooks_riverpod | 3.4.3 | — | — |
| http | 1.6.0 | 1.6.0 | 1.6.0 |
| intl | 0.20.3 | — | — |
| latlong2 | 0.10.1 | — | — |
| lints | — | 6.1.0 | 6.1.0 |
| pinput | 7.0.0 | — | — |
| qr_flutter | 4.1.0 | — | — |
| serverpod | — | 4.1.0 | — |
| serverpod_client | 4.1.0 | — | 4.1.0 |
| serverpod_test | — | 4.1.0 | — |
| test | — | 1.33.0 | — |
| url_launcher | 6.3.3 | — | — |
| uuid | 4.6.0 | — | — |

Direct registry packages are at the stable versions found by this audit. The local `ehailer_client` path dependency is versioned with this repository. The generated client, server and Serverpod CLI are aligned at **4.1.0**.

## Upstream constraints

These transitive packages have newer releases, but the selected Flutter SDK or upstream packages constrain the resolver. No Dart dependency overrides are used to force incompatible versions.

| Scope | Package | Resolved | Registry latest |
| --- | --- | --- | --- |
| App | dbus | 0.7.15 | 0.8.0 |
| App | gsettings | 0.2.8 | 0.2.9 |
| App | material_color_utilities | 0.13.0 | 0.13.1 |
| App | qr | 3.0.3 | 4.0.1 |
| App | test_api | 0.7.12 | 0.7.15 |
| App | xml | 7.0.1 | 7.1.0 |
| Server | sqlite3_web | 0.9.4 | 0.9.5 |
| Server | sqlite_async | 0.14.5 | 0.14.7 |

## Supporting tools

- Flutter **3.47.9 stable**, Dart **3.13.7** are installed for the final build checks on 2026-11-02; earlier checks used Flutter 3.47.5 / Dart 3.13.4. The app requires Flutter >=3.47 and Dart >=3.12.2.
- Android build declarations: AGP **9.5.0**, Kotlin **2.4.21**, Google Services **4.5.0**, Gradle **9.8.2**. See `VALIDATION.md` for the actual native build result.
- The Android build reports that `firebase_auth` and `firebase_core` still apply the Kotlin Gradle Plugin. Track their upstream built-in Kotlin migration before a future Flutter upgrade; this is a compatibility warning, not a dependency override applied here.
- iOS uses Swift Package Manager. Firebase native SDK versions follow the current FlutterFire plugins; do not override their SDK constraints independently.
- Firestore test dependencies: Firebase JS **13.1.0**, rules-unit-testing **6.0.0**. `npm audit` reports **zero vulnerabilities** in the test lockfile.
- An npm override selects **@grpc/grpc-js 1.14.6** because Firebase pins an older release. It addresses the [certificate-verification advisory](https://github.com/advisories/GHSA-m9gg-hp2v-232j); rules tests exercise the override against the emulator.
- Graphify **0.9.100** is isolated in `.cache/graphify-env`; the global Python installation is unchanged. Set `GRAPHIFY_NO_AUTO_REFRESH=1` for CLI commands.
- The repository Archify skill is **3.2.0**; its delivery check reports the installed version current.
- Plus Jakarta Sans is bundled with its OFL license. Runtime `google_fonts` downloads were removed.

Registry sources: [pub.dev](https://pub.dev), [Graphify/PyPI](https://pypi.org/project/graphifyy/), [Google Maven AGP metadata](https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/maven-metadata.xml), [Google Services metadata](https://dl.google.com/dl/android/maven2/com/google/gms/google-services/maven-metadata.xml), [Kotlin releases](https://kotlinlang.org/docs/releases.html), [Gradle releases](https://gradle.org/releases/).

## Refresh and verify

```sh
flutter pub outdated --show-all
(cd server/ehailer_server && dart pub outdated --show-all)
(cd server/ehailer_client && dart pub outdated --show-all)
npm --prefix tool/firestore_tests outdated
npm --prefix tool/firestore_tests audit
```

Review release notes before upgrading. Run the analyzers, Flutter tests, emulator security/transaction tests and relevant platform builds after a dependency change. A current package version does not establish production readiness.
