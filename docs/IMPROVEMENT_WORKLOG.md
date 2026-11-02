# Codebase improvement worklog

This work follows the 2026-10-28 review of commit `3bacce3`. It preserves the existing AGENTS.md, manual Dart models, Riverpod, OpenStreetMap and Swift Package Manager.

## Scope and acceptance

- [x] Enforce ownership and roles in Firestore; deny direct financial mutations and private delivery reads.
- [x] Add an authenticated, transactional Serverpod (Dart) backend for creation, assignment, lifecycle, PIN verification, payouts and refunds. Keep unconfigured payment top-ups unavailable.
- [x] Separate public tracking from private order data; keep delivery PINs available only to the booking customer.
- [x] Test unauthorized access, duplicate requests, concurrent settlement, invalid transitions and failed PIN attempts against Firebase emulators.
- [x] Audit auth, routing, providers, maps, notifications, financial summaries and error handling.
- [x] Introduce shared adaptive layout primitives and improve customer, driver, operations, tracking and form layouts.
- [x] Test narrow phones, tablets, desktop widths, increased text sizes, loading, empty and error states.
- [x] Add a scoped, reproducible Graphify graph and documented update commands.
- [x] Review the six reference repositories and record applicable patterns separately from first-party architecture documentation.
- [x] Run formatting, analyzer, Flutter tests, backend/rules tests and available build/UI checks; document deployment prerequisites and remaining limitations.

## Baseline

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter expanded`: 103 passed.
- Existing tests cover domain models and selected widgets, not Firestore authorization or transactional workflows.
- No backend deployment or payment-provider configuration has been verified.

## Decisions

- Sensitive writes require a trusted backend; mobile clients cannot verify payments or authorize their own wallet credits.
- Backend development and emulator testing do not deploy services or change Firebase billing.
- New public tracking data must contain an explicit allowlist of non-sensitive fields.
- Regression tests must exercise observable behavior and denied operations, not merely assert that helpers exist.

## Serverpod decision

The user selected Serverpod for the trusted API. Firebase Authentication and Firestore remain the identity and realtime storage boundary initially. Serverpod protocol generation is confined to the API client/server contracts; Flutter domain models remain manual and no Flutter build_runner is introduced. Backend code follows domain/infrastructure/endpoint boundaries. Architecture documentation and validated Archify diagrams must describe the actual implementation.

## Delivery record — 2026-11-02

- Implemented Serverpod 4.1.0 commands with verified Firebase identity, role/state checks, atomic ledger effects, single-use quotes, private PIN lockout and receipt-based retries.
- Removed public order/PIN exposure, client role changes and simulated wallet top-ups. Hardened Firestore rules and separated public/job projections from private orders.
- Rebuilt booking around real map selections, server quotes and review/edit. Added bounded adaptive layouts, accessible text scaling, bundled fonts, recovery panels and lifecycle cleanup.
- Fixed profile save callbacks after navigation, support-role labels and profile action tap feedback; vehicle choices wrap and retain keyboard/accessibility support.
- Fixed quantity-aware volumetric pricing, historical on-time metrics, password whitespace handling and an API cleanup-future deadlock found by the new tests.
- Updated stable dependencies and lockfiles, preserving documented upstream constraints. Native toolchain verification and outcomes are recorded in `VALIDATION.md`.
- Added MIT licensing, third-party notices, an in-app license entry, a detailed README, app guide, documentation index, API/schema contracts and reviewed fixture screenshots.
- Delivered a validated Archify architecture with source-snapshot provenance and a scoped Graphify map. Reviewed relevant slices of all six reference repositories.
- Verified 176 Flutter tests, 12 authorization tests and 18 real-emulator/backend/API tests. Analyzers pass. Web release, Android debug and iOS Simulator debug builds pass; see the validation record for their scope and release prerequisites.

The checklist records local implementation and review work. It does not mark payment integrations, production deployment, legacy migration or physical-device acceptance complete. The user requested local commits for this baseline. The existing root AGENTS.md was preserved; no production writes or deployments were performed.

## Paystack and public-repository security pass — 2026-11-02

- Added hosted wallet funding, private durable intents, signed webhooks, server re-verification and atomic duplicate-safe settlement. Recovery survives app restarts; the UI confirms success only after credit commits.
- Added production-mode server configuration, a liveness route, private environment templates and a native bundle/deployment guide. Real provider acceptance remains separate from local stubs.
- Moved project-specific client configuration into ignored local env/platform files. Added allowlisted `--dart-define-from-file` builds and separate server/signing loaders; private credentials cannot be passed through the client wrapper.
- Removed worker payload logs, split-key fallbacks and query-based configuration overrides. The worker now follows FlutterFire's selected web SDK. Android releases no longer use debug signing.
- Cleared the prior `assume-unchanged` flag on Firebase options so source review and commits include its environment-backed replacement. Added a staged secret guard, local hook and pinned GitHub security workflow.
- Scanned all 81 local historical commits and a fresh mirror of all 53 GitHub commits; preserved a verified remote bundle and pending-source backup locally. Historical Firebase identifiers and checksum findings are documented separately from private credentials. Reviewed historical financial/public-read flaws and closed their current-code paths.
- Verified 189 Flutter tests, 38 real-emulator/backend/API tests, 13 rules tests, 7 provider/config tests, 9 environment-tool tests and 3 worker tests. Env-based web/Android/iOS Simulator builds pass; missing Android release credentials are rejected. See `VALIDATION.md` for exact boundaries.
- Updated README, payment/environment/security/deployment docs and both Archify diagrams; refreshed Graphify to include build/security tools and the worker.

The user requested a clean **public** copy with fresh history. The publication procedure preserves the former history only in local backups, audits the complete new snapshot, and updates the existing GitHub main branch with an explicit expected old revision. It does not delete the repository, publish local env files, deploy Firebase rules or erase old external caches/clones.
