# Agent Guidelines & Project Manual: e-Hailer

Welcome to **e-Hailer**, a production-grade on-demand logistics and courier platform template built with **Flutter 3.x (Dart 3)** and **Firebase**.

This document is the authoritative instruction set for all AI agents, pair programmers, and contributors working on this codebase.

---

## 1. Project Overview & Architectural DNA

`e-Hailer` combines the best features and engineering patterns from three benchmark repositories:
1. **[courierManagementSystem](https://github.com/whattadarsh/courierManagementSystem)**:
   - Volumetric package dimensions ($L \times W \times H$ in $cm$).
   - IATA volumetric weight computation: $\frac{L \times W \times H}{5000}$.
   - Billable weight logic ($\max(\text{Physical}, \text{Volumetric})$).
   - Consignment waybill generation and scannable QR tracking.
2. **[myoga](https://github.com/softontechsolution/myoga)**:
   - On-demand point-to-point courier hailing.
   - Driver availability toggle (`isAvailable`) and radius job broadcasting.
   - Vehicle categories (Motorcycle, Sedan, Van, Truck) with dynamic rate multipliers.
   - In-app digital wallet ledger and customer/driver split calculations.
3. **[deliverzler](https://github.com/AhmedLSayed9/deliverzler)**:
   - Domain-Driven Design (DDD) layered architecture (`domain/`, `infrastructure/`, `presentation/`).
   - Clean separation of concerns with zero UI/Firebase dependencies in the domain layer.
   - Stream-based reactive synchronization with Cloud Firestore.

---

## 2. Immutable Engineering Rules

All AI agents and developers modifying this codebase MUST strictly adhere to these rules:

### Rule 1: Zero `build_runner` / No Code Generation
- **DO NOT** add `freezed`, `json_serializable`, or `riverpod_generator`.
- All domain entities, failures, and value objects MUST extend [`package:equatable`](https://pub.dev/packages/equatable) and define `props`.
- All serialization must use manual, pure Dart `toMap()` and `factory fromMap()` methods.
- This ensures near-instant hot reloads, eliminates GBs of build cache, and avoids analyzer mismatch issues.

### Rule 2: Zero Google Maps Billing (OpenStreetMap Only)
- **DO NOT** add `google_maps_flutter` or Google Cloud Platform billing dependencies.
- Map rendering is handled by [`flutter_map: ^7.0.2`](https://pub.dev/packages/flutter_map) using free OpenStreetMap raster tiles.
- Road polylines, real driving distance, and travel durations are calculated via the **OSRM (Open Source Routing Machine)** API in [`OsmRoutingService`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/map/infrastructure/osm_routing_service.dart).
- Reverse geocoding is powered by OpenStreetMap **Nominatim**.

### Rule 3: Zero Paid Cloud Storage (PIN Verification Architecture)
- **DO NOT** add `firebase_storage` or upload binary files to GCS.
- Proof of delivery is achieved through a secure 4-digit **Handover Verification PIN** (`recipientSecurityOtp`) auto-generated on order creation and stored in Firestore.
- Waybill labels and consignment numbers are rendered on-screen via [`qr_flutter: ^4.1.0`](https://pub.dev/packages/qr_flutter).

### Rule 4: Functional Error Handling with `fpdart`
- Operations in the `infrastructure/` layer must return `Future<Either<AppFailure, T>>` or `Stream<Either<AppFailure, T>>`.
- Never throw unhandled exceptions in services.
- Presentation logic handles results using `.fold((failure) => ..., (success) => ...)`.

---

## 3. Directory Layout & DDD Structure

```
lib/
├── app.dart                                         # Root widget with ScreenUtil & GoRouter
├── main.dart                                        # Bootstrap & Firebase.initializeApp
├── firebase_options.dart                            # FlutterFire configuration
│
├── core/                                            # Cross-cutting utilities & styles
│   ├── domain/failures/app_failure.dart             # Sealed AppFailure hierarchy (Equatable)
│   ├── presentation/
│   │   ├── styles/                                  # AppColors & AppTheme (Material 3)
│   │   └── utils/fp_framework.dart                  # Re-exported fpdart constructs
│   └── routing/app_router.dart                      # GoRouter with role & auth guards
│
└── features/                                        # Feature modules (DDD)
    ├── auth/                                        # User accounts & roles (Customer/Driver/Admin)
    │   ├── domain/user_entity.dart
    │   ├── infrastructure/auth_remote_service.dart
    │   └── presentation/screens/login_screen.dart
    │
    ├── map/                                         # OpenStreetMap & OSRM Routing
    │   ├── domain/route_result.dart
    │   ├── infrastructure/osm_routing_service.dart
    │   └── presentation/widgets/osm_map_widget.dart
    │
    └── delivery/                                    # Express hailing & parcel consignment
        ├── domain/
        │   ├── entities/                            # DeliveryOrder, LocationPoint, ParcelDetails, PricingDetails
        │   ├── services/pricing_calculator.dart     # Volumetric & road distance fare engine
        │   └── value_objects/                       # DeliveryStatus, DeliveryType, VehicleType
        ├── infrastructure/delivery_remote_service.dart
        └── presentation/
            ├── providers/delivery_providers.dart    # Pure Riverpod StreamProviders
            └── screens/
                ├── customer_home_screen.dart
                ├── driver_dashboard_screen.dart
                ├── order_tracking_screen.dart
                ├── express_booking_screen.dart
                └── consignment_creation_screen.dart
```

---

## 4. Key Workflows & Commands

### Code Quality & Static Analysis
Always run before committing:
```bash
flutter analyze
```
*Current standard: 0 errors, 0 warnings.*

### Re-rendering the Interactive Architecture Diagram (Archify)
An interactive, standalone HTML architecture diagram is located at `docs/architecture.html`.
To update or re-render:
```bash
node .agents/skills/archify/bin/archify.mjs render architecture docs/architecture.json docs/architecture.html
```

---

## 5. Adding a New Feature (Recipe)
When adding any new capability (e.g., Wallet top-up, Push notifications, Live driver GPS broadcast):
1. **Domain**: Define the model in `domain/entities/` extending `Equatable`.
2. **Infrastructure**: Create the remote service returning `Either<AppFailure, T>`.
3. **Presentation Providers**: Create pure Riverpod providers (`Provider`, `StreamProvider`).
4. **Presentation UI**: Build widgets/screens using `HookConsumerWidget` or `ConsumerWidget`.
5. **Route**: Register the path in `lib/core/routing/app_router.dart`.
