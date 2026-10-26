# Claude Assistant Context & Instructions: e-Hailer

This file provides system context, architectural guidelines, and build commands for **Claude** (Claude Code CLI, Cursor, and web).

---

## Commands & Verification

- **Install dependencies**: `flutter pub get`
- **Static Analysis**: `flutter analyze` *(Must pass with 0 issues)*
- **Run Application**: `flutter run`
- **Render Archify Diagram**: `node .agents/skills/archify/bin/archify.mjs render architecture docs/architecture.json docs/architecture.html`
- **Clean**: `flutter clean`

---

## Architectural Principles (DDD + Clean Architecture)

1. **Pure Dart Domain Layer**:
   - Entities inside `lib/features/<feature>/domain/entities/` extend `Equatable`.
   - Never import Flutter UI widgets or Firebase packages into `domain/`.
   - Never use `build_runner`, `freezed`, or code generation.

2. **Functional Error Handling**:
   - Infrastructure services return `Either<AppFailure, T>` from `fpdart`.
   - Failures inherit from `sealed class AppFailure extends Equatable`.

3. **Pure Riverpod State Management**:
   - Use `hooks_riverpod: ^2.5.2` and `flutter_hooks: ^0.20.5`.
   - Define providers by hand (`Provider`, `StreamProvider`, `StateNotifierProvider`) without `@riverpod` annotations.

4. **Zero-Cost Maps & Cloud Services**:
   - **OpenStreetMap (OSM)**: Managed by `flutter_map: ^7.0.2` and `latlong2: ^0.9.1`.
   - **Driving Routes & Distance**: Queried from the free **OSRM** API (`router.project-osrm.org`).
   - **Zero Cloud Storage**: Handover verified via 4-digit numeric PIN (`recipientSecurityOtp`).

5. **Centralized Routing & Asset Registries**:
   - Navigation: Use `AppRoutes` / `AuthRoutes` / `DeliveryRoutes` for route names, paths, and dynamic helpers.
   - Assets: Use `AppAssets` / `AuthAssets` / `DeliveryAssets` / `MapAssets` for image and icon paths. Avoid hardcoded string literals.

---

## Key Domain Formulas

- **Volumetric Weight (IATA standard)**:
  $$\text{Volumetric Weight} = \frac{\text{Length (cm)} \times \text{Width (cm)} \times \text{Height (cm)}}{5000}$$
- **Billable Weight**:
  $$\text{Billable Weight} = \max(\text{Actual Weight}, \text{Volumetric Weight})$$
- **Fare Split**:
  - Driver Earnings: $80\%$
  - Platform Commission: $20\%$
