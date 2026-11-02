# Gemini Assistant Context & Rules: e-Hailer

This file defines the project instructions, architectural boundaries, and guidelines for **Gemini** and the **Google DeepMind Antigravity** assistant.

---

## 1. Project Profile
- **Project Name**: `e-Hailer`
- **Application Type**: Cross-Platform Logistics, On-Demand Ride/Courier Hailing & Consignment Management.
- **Framework**: Flutter 3.47+ / Dart 3.13+
- **Backend**: Google Firebase (Authentication & Cloud Firestore).
- **Architecture**: Domain-Driven Design (DDD) + Layered Clean Architecture.

---

## 2. Core Constraints (Strict Enforcement)

1. **No Code Generators (`build_runner`)**:
   - Do NOT suggest or generate `.freezed.dart`, `.g.dart`, or `@riverpod` annotations.
   - Use [`package:equatable`](https://pub.dev/packages/equatable) for all value objects, entities, and states.
   - Implement `toMap()`, `fromMap()`, and `copyWith()` manually.

2. **No Google Maps API Billing**:
   - Use **OpenStreetMap (OSM)** via [`flutter_map: ^7.0.2`](https://pub.dev/packages/flutter_map) and [`latlong2: ^0.9.1`](https://pub.dev/packages/latlong2).
   - Driving polylines, travel durations, and road distances must use the **OSRM API** (`router.project-osrm.org`).
   - Reverse geocoding must use **OSM Nominatim**.

3. **Zero Paid Cloud Storage Dependencies**:
   - Do not upload images or signatures to Firebase Cloud Storage.
   - Handover verification is performed cryptographically using the 4-digit `recipientSecurityOtp` PIN generated on the order document.
   - Consignment tracking uses on-screen QR codes generated with `package:qr_flutter`.

4. **Functional Programming**:
   - Handle errors with `package:fpdart` (`Either<AppFailure, T>`, `left()`, `right()`, `unit`).
   - All failures inherit from the sealed `AppFailure` class.

5. **State Management & Routing**:
   - State: Pure `hooks_riverpod: ^2.5.2` (`Provider`, `StreamProvider`, `StateNotifierProvider`).
   - Routing: `go_router: ^14.2.0` with role-based auth guards (`/home` for Customers, `/driver` for Fleet Drivers, `/login` for unauthenticated).
   - Route & Asset Constants: Never use raw string literals. Use `AppRoutes` (`AuthRoutes`, `DeliveryRoutes`) and `AppAssets` (`AuthAssets`, `DeliveryAssets`, `MapAssets`).

---

## 3. Reference Synthesis Matrix

| Origin Repository | Features Adopted in e-Hailer |
| :--- | :--- |
| **courierManagementSystem** | • Volumetric Weight Formula: $(L \times W \times H) / 5000$<br>• Billable Weight Logic: $\max(\text{Physical}, \text{Volumetric})$<br>• Waybill Number Generation & QR Display<br>• Package Categories & Fragile Surcharge |
| **myoga** | • On-Demand Express Dispatch UX<br>• Live Driver GPS Coordinates on Map<br>• Vehicle Categories (Bike, Car, Van, Truck) with Multipliers<br>• Digital Wallet Balance & Transaction Ledger<br>• Driver Broadcast & Acceptance Modal |
| **deliverzler** | • DDD Layered Folder Structure (`domain`, `infrastructure`, `presentation`)<br>• Stream-Based Real-Time Firestore Synchronization<br>• Declarative GoRouter Redirection<br>• Functional Error Handling Pattern |

---

## 4. Verification Standard
Every modification must maintain **zero errors and zero warnings**:
```bash
flutter analyze
```
Architecture diagrams are maintained with **Archify**:
```bash
node .agents/skills/archify/bin/archify.mjs render architecture docs/architecture.json docs/architecture.html
```
