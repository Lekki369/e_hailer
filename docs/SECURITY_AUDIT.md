# Security audit — 2026-11-02

Scope: current Flutter/Serverpod code, Firestore rules, payment verification, configuration/build paths, publishable files, all **81 local pre-publication Git commits** (including archived local history), and a fresh mirror of all **53 commits reachable on GitHub before publication**. The remote had one branch, no tags and no forks at inspection. Tests use synthetic accounts and local provider stubs. No production credentials were tested, live services deployed or payment taken. The clean source-publication procedure is recorded below.

## Findings and remediation

| Finding | Impact | Change |
| --- | --- | --- |
| Firebase identifiers present in local source/history and the remote web worker; the worker assembled a split key fallback | Violated the requested public-repository policy. Firebase client identifiers are public, but restrictions and rules still matter. | Preserved values in ignored local `.env`; removed native config files from tracking; removed project metadata from tracked Firebase config and all worker fallbacks. |
| No enforced separation between client build settings and future server secrets | A developer could accidentally embed a Paystack/admin credential in a public app. | Allowlisted client builder rejects private key names and known credential patterns; separate server and Android-signing env loaders; no shell evaluation. |
| Android release variant used the debug signing key | A nominal release build did not establish a trusted release identity. | Removed fallback; wrapper and Gradle require private signing settings. Debug builds remain explicitly debug-signed. |
| Notification worker logged the full received payload | Potential disclosure of notification contents in browser logs. | Removed payload logging and duplicate manual notification display; worker uses locally generated public config. |
| Worker pinned Firebase JS 10.7.0 independently of FlutterFire | Unreviewed SDK drift and stale integration behavior. | Worker generation follows the installed FlutterFire-supported JS SDK (13.1.0 in this lockfile). No specific CVE is asserted for the old version. |
| API URLs allowed embedded credentials, query or fragment | Ambiguous routing and accidental sensitive URL configuration. | Build validation and the Flutter transport reject these before token acquisition. |
| Mixed emulated/real Firebase identity and test wallet funding | Test credits or emulator identity could cross an unintended storage boundary. | Server startup requires paired demo emulators or explicitly isolated staging for test funding; live payment mode rejects emulators. |

## Evidence

- **189 Flutter tests** pass, including URL rejection, payment recovery, exact amount parsing, asynchronous navigation safety and checkout at 320/600/1280 px with 1×/2× text. The checkout captures use the bundled font and synthetic data.
- **38 real-emulator/backend/API tests** pass: 15 operations policies, 19 payment scenarios and 4 authenticated HTTP tests. Payment mismatch, duplicate events, concurrent verification, late settlement, provider transaction reuse and private intent ownership are covered.
- **13 Firestore rules tests** pass, including denied client writes to balances, payment intents, settlements and pending-payment pointers. **7 provider/configuration unit tests** also pass.
- **9 environment/security-tool tests** and **3 web-worker tests** exercise secret exclusion, safe parsing, release guards, generated config consistency and trusted script origins.
- OSV returned **no known advisories for 208 resolved Pub package/version pairs**. `npm audit` returned **0 vulnerabilities** for the emulator-test lockfile. These are registry results at the audit date, not proof that dependencies have no defects. Native SDK/OS binaries were not comprehensively vulnerability-scanned.
- Gitleaks 8.30.1 scanned **81 commits / approximately 41.96 MB** before exceptions: 17 findings. Five were historical Firebase public API-key occurrences; twelve were SHA-256 source-integrity digests. No private server credential, service-account key or signing key was identified by this scan.

The fresh remote mirror scan covered 53 commits / approximately 20.24 MB and reported one historical public Firebase key occurrence in the notification worker. The other local findings belong to local-only or archived history. Both distinct historical Pub lockfile blobs were queried against OSV: 177 historical package/version pairs, no known advisories returned.

The user requested a fresh public copy. The old remote history is preserved in an ignored local mirror and a verified complete Git bundle under `.cache/security-backup/`; pending source was also backed up. The clean publication starts from an audited snapshot with no parent commits. No historical key-fingerprint exemptions are shipped. `.gitleaks.toml` excludes only 64-character source-integrity digests in named generated evidence files; default credential rules remain enabled. Local reports stay ignored and redacted. Replacing branch history cannot revoke identifiers or erase existing clones, caches or otherwise retained old commit objects.

## Historical application flaws

Manual review of the security-sensitive historical changes found full-record public delivery access (`allow get ... || true`), public tracking queries returning private delivery entities, owner-controlled wallet balance changes and client-created ledger entries. The latest old remote revision still contained these paths. This prepared implementation replaces them with redacted public projections, private PIN documents, denied client financial writes and verified Serverpod transactions. Emulator regression tests cover those boundaries. This is a source/rules review, not proof of exploitation or of the rules currently deployed to Firebase. Every reachable commit was secret-scanned; a complete manual proof of every historical code path is not claimed.

## Remaining release risks

1. Verify Firebase key API/application restrictions, Authentication settings, IAM, deployed rules and App Check in the actual project. They cannot be established from this checkout. Treat historical client identifiers as public; rotate/restrict them if required by your deployment policy. Any actual private credential found later needs immediate revocation, not merely a source edit.
2. Deploy ingress rate limits, request deadlines, abuse controls and monitoring. The API verifies Firebase identity but does not currently require App Check or impose a durable per-account quota across every command. PIN attempt limits and payment initialization leases do not replace global resource controls.
3. Complete real Paystack test-mode acceptance, webhook delivery, reconciliation, refund/chargeback handling and merchant accounting. Current tests use local stubs. Credits cannot be treated as cash until a correctly isolated provider deployment is accepted.
4. Migrate legacy public PIN/tracking fields and reconcile old wallet data before applying this model to existing users. Rules do not remove previously exposed document fields.
5. Driver self-registration and broad driver job-offer reads need an operator-approved onboarding/service-area policy before real customer locations are exposed to a fleet. Public tracking remains redacted, but authorized operational reads still contain personal data.
6. Finish production signing, private device acceptance, backup/retention policy and operational rollback. Local test/build success does not certify all devices, network failures or production permissions.

See [SECURITY.md](../SECURITY.md), [ENVIRONMENT.md](ENVIRONMENT.md), [PAYMENTS.md](PAYMENTS.md) and [VALIDATION.md](VALIDATION.md). No claim of zero vulnerabilities or guaranteed secrecy is made.
