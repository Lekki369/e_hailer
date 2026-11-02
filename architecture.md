# e-Hailer Platform Architecture & Implementation Specification

`e-Hailer` is a production-grade cross-platform logistics, on-demand courier hailing, and parcel consignment platform built with **Flutter 3.x (Dart 3)** and **Firebase**.

---

## 1. Core Architectural Pillars

The application is engineered on five immutable architectural principles:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           e-Hailer Engineering Pillars                      │
├───────────────────────┬──────────────────────────┬──────────────────────────┤
│ Clean Layered DDD     │ Zero build_runner        │ Zero Maps API Billing    │
│ Domain, Infrastructure│ Pure Dart 3 Equatable    │ OpenStreetMap Raster +   │
│ & Presentation layers │ entities & manual mappers│ OSRM Driving Polylines   │
├───────────────────────┼──────────────────────────┼──────────────────────────┤
│ Zero Paid Storage     │ Functional Failures      │ Role-Enforced Security   │
│ 4-Digit Handover PIN  │ fpdart Either<Failure, T>│ Granular Firestore RBAC  │
│ verification & QR     │ with sealed AppFailure   │ for Customer/Driver/Admin│
└───────────────────────┴──────────────────────────┴──────────────────────────┘
```

1. **Domain-Driven Design (DDD) & Clean Layered Architecture**:
   - Clear separation between `domain/`, `infrastructure/`, and `presentation/` across all feature modules.
   - The domain layer contains pure Dart entities, value objects, and business calculators with zero Flutter UI or Firebase dependencies.
2. **Zero `build_runner` / No Code Generation**:
   - Zero reliance on `freezed`, `json_serializable`, or `riverpod_generator`.
   - All models extend `package:equatable` and implement explicit `toMap()`, `fromMap()`, and `copyWith()` methods.
   - Eliminates build-cache overhead and prevents analyzer mismatch errors during Flutter SDK upgrades.
3. **Zero Google Maps Platform API Billing**:
   - Free OpenStreetMap raster tiles rendered via [`flutter_map: ^8.3.2`](https://pub.dev/packages/flutter_map) and [`latlong2: ^0.10.1`](https://pub.dev/packages/latlong2).
   - Driving routes, road distances, and durations calculated through the open-source **OSRM (Open Source Routing Machine)** API in [`OsmRoutingService`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/map/infrastructure/osm_routing_service.dart).
   - Reverse geocoding powered by OpenStreetMap **Nominatim**.
4. **Zero Paid Cloud Storage (Handover PIN Verification Architecture)**:
   - Proof of delivery is cryptographically verified via an auto-generated 4-digit **Handover Verification PIN** (`recipientSecurityOtp`) stored in Firestore.
   - Consignment waybills and labels rendered on-screen using [`qr_flutter: ^4.1.0`](https://pub.dev/packages/qr_flutter).
5. **Functional Error Handling**:
   - Asynchronous infrastructure operations return `Future<Either<AppFailure, T>>` or `Stream<Either<AppFailure, T>>` using `package:fpdart`.
   - Failures inherit from the sealed [`AppFailure`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/core/domain/failures/app_failure.dart) class hierarchy.

---

## 2. System Topology & Architecture Graph

```mermaid
flowchart TD
    subgraph UI["Presentation Layer (Flutter Hooks + Riverpod)"]
        direction TB
        CustomerViews["Customer Modules\n• CustomerHomeScreen\n• ExpressBookingScreen\n• ConsignmentCreationScreen\n• OrderTrackingScreen\n• PublicTrackingScreen"]
        DriverViews["Driver Terminal\n• DriverDashboardScreen\n• ActiveDeliveryScreen\n• ReportDeliveryIssueModal"]
        AdminViews["Operations Command Center\n• AdminDashboardScreen\n• DispatchQueueScreen\n• DriverManagementScreen\n• AdminMapOverviewScreen\n• ManualAssignmentModal\n• AnalyticsDashboardScreen"]
        FinancialViews["Wallet & Support Modules\n• WalletScreen\n• PayoutManagementScreen\n• PayoutRequestModal\n• DisputeManagementScreen\n• FileDisputeModal"]
        
        StateProviders["Riverpod Providers\n• authStateProvider & currentUserProfileProvider\n• activeOrderStreamProvider & availableOrdersStreamProvider\n• allOrdersStreamProvider & fleetDriversStreamProvider\n• operationsAnalyticsProvider & disputesStreamProvider"]
    end

    subgraph Domain["Domain Layer (Pure Dart 3 + Equatable)"]
        direction TB
        DomainEntities["Entities\n• DeliveryOrder & DeliveryDispute\n• UserEntity & PayoutRequest\n• FleetDriverSummary & OperationsAnalytics\n• LocationPoint, ParcelDetails, PricingDetails, RouteResult"]
        ValueObjects["Value Objects & Enums\n• UserRole, DeliveryStatus, DeliveryType, VehicleType\n• DisputeCategory, DisputeStatus, PayoutStatus, TransactionType"]
        DomainServices["Domain Services\n• PricingCalculator (Volumetric & Road Distance Engine)"]
        Failures["Failures (Sealed Classes)\n• AppFailure (Server, Auth, Network, Location, InvalidOtp)"]
    end

    subgraph Infrastructure["Infrastructure Layer (External Adapters)"]
        direction TB
        AuthService["AuthRemoteService\n(Firebase Auth + Firestore /users)"]
        DeliveryService["DeliveryRemoteService\n(Firestore /deliveries & Handover PIN)"]
        AdminService["AdminRemoteService\n(Dispatch streams & manual assignment)"]
        WalletService["WalletRemoteService\n(Atomic ledger, payouts & top-up)"]
        DisputeService["DisputeRemoteService\n(Arbitration, wallet refund & returns)"]
        OsmService["OsmRoutingService\n(OSRM polylines & Nominatim geocoding)"]
    end

    subgraph CloudServices["External Cloud & Open APIs"]
        direction TB
        FirebaseAuth["Firebase Authentication (Phone OTP & Email)"]
        Firestore["Cloud Firestore Database"]
        OSRM["Open Source Routing Machine (OSRM API)"]
        OSM["OpenStreetMap Free Raster Tile Servers"]
    end

    UI --> StateProviders
    StateProviders --> Infrastructure
    Infrastructure --> Domain
    UI --> Domain
    
    AuthService --> FirebaseAuth
    AuthService --> Firestore
    DeliveryService --> Firestore
    AdminService --> Firestore
    WalletService --> Firestore
    DisputeService --> Firestore
    OsmService --> OSRM
    CustomerViews --> OSM
    DriverViews --> OSM
    AdminViews --> OSM
```

---

## 3. Order Lifecycle State Machine

```mermaid
stateDiagram-v2
    [*] --> Created: Customer books express ride or consignment
    
    state Created {
        [*] --> SearchingDriver: Express On-Demand Hailing
        [*] --> HubQueued: Consignment Parcel Ingestion
    }

    SearchingDriver --> Assigned: Nearby driver accepts job
    SearchingDriver --> Assigned: Dispatcher manually assigns via Admin Console
    HubQueued --> Assigned: Dispatcher assigns fleet driver
    
    Assigned --> ArrivedPickup: Driver reaches sender location
    ArrivedPickup --> PickedUp: Parcel loaded / ride started
    PickedUp --> InTransit: Navigating via OSRM Polyline
    InTransit --> ArrivedDropoff: Courier arrives at destination
    ArrivedDropoff --> Delivered: Recipient provides 4-digit PIN
    
    SearchingDriver --> Cancelled: Customer cancels / Dispatcher cancels
    Assigned --> Cancelled: Driver / Customer cancels with reason
    Assigned --> Assigned: Dispatcher reassigns to new driver
    
    InTransit --> FailedDelivery: Recipient unreachable / Inaccessible address
    FailedDelivery --> ReturnedToHub: Dispute resolution authorizes return
    Delivered --> Disputed: Customer files damage / overcharge claim
    Disputed --> Refunded: Admin issues wallet refund credit
    
    Delivered --> [*]
    Cancelled --> [*]
    Refunded --> [*]
    ReturnedToHub --> [*]
```

---

## 4. Platform Subsystems & Implementation Details

### Subsystem 1: Centralized Dispatch & Fleet Operations Command

The operations module provides dispatchers and fleet managers with real-time operational oversight and manual intervention capabilities:

1. **Operations Dashboard ([`AdminDashboardScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/admin/presentation/screens/admin_dashboard_screen.dart))**:
   - Executive operational metrics computed dynamically from live streams: Total Active Orders, Assigned Orders, Unassigned Orders, Delayed Orders, Active Online Fleet Count, and Today's Gross Revenue.
   - Quick-action navigation to Queue, Fleet Map, Driver Roster, Payouts Console, and Analytics.
2. **Real-Time Dispatch Queue ([`DispatchQueueScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/admin/presentation/screens/dispatch_queue_screen.dart))**:
   - Live stream of all platform orders with state filtering (`All`, `Pending`, `Assigned`, `In Transit`, `Delivered`, `Cancelled`).
   - Full-text search matching tracking numbers, customer names, phone numbers, and street addresses.
3. **Fleet Driver Management ([`DriverManagementScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/admin/presentation/screens/driver_management_screen.dart))**:
   - Roster view displaying online availability status (`isAvailable`), vehicle category (Motorcycle, Sedan, Van, Truck), registration plate number, completed trips, and customer rating.
4. **Manual Assignment & Dispatch Engine ([`ManualAssignmentModal`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/admin/presentation/widgets/manual_assignment_modal.dart))**:
   - Bottom sheet allowing operators to manually assign or reassign deliveries to online couriers.
   - Performs atomic Firestore batch writes updating the delivery order status to `assigned` and storing driver metadata (`driverId`, `driverName`, `driverPhone`).
5. **Interactive Fleet Map Overview ([`AdminMapOverviewScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/admin/presentation/screens/admin_map_overview_screen.dart))**:
   - OpenStreetMap canvas rendering green markers for available drivers with real-time GPS coordinates and primary markers for pending pickups.
   - Tapping markers displays order details with direct assignment triggers.

---

### Subsystem 2: Financial Ledger, Digital Wallet, & Payout Settlement

The financial engine manages dual-modality settlements (Digital and Cash on Delivery), transaction ledgers, and driver withdrawal workflows:

```mermaid
flowchart TD
    OrderCompletion["Handover Verification PIN Verified"] --> PaymentType{"Payment Method?"}
    
    PaymentType -- "Digital Wallet / Card" --> DigitalSettlement["Digital Settlement\n• Customer paid upfront\n• Credit Driver: +80% net earnings\n• Platform retains: 20% commission"]
    
    PaymentType -- "Cash on Delivery (COD)" --> CodSettlement["COD Settlement\n• Driver collected 100% cash in hand\n• Deduct Driver Wallet: -20% platform commission\n• Ledger: codCommission"]
    
    DigitalSettlement --> DriverWallet["Driver Wallet Balance Updated"]
    CodSettlement --> DriverWallet
    
    DriverWallet --> PayoutRequestAction["Driver requests withdrawal via PayoutRequestModal"]
    PayoutRequestAction --> PayoutPending["PayoutRequest status: pending\n• Locked amount deducted from wallet"]
    
    PayoutPending --> AdminReview{"Admin Payout Console (/admin/payouts)"}
    AdminReview -- "Approve & Transfer" --> PayoutSettled["status: settled\n• Bank transfer ref recorded"]
    AdminReview -- "Reject & Revert" --> PayoutRejected["status: rejected\n• Amount refunded back to Driver Wallet\n• Ledger: payoutReversal"]
```

1. **Automated 80/20 Commission & Fare Computation Engine**:
   - **Volumetric Weight Calculation**:
     $$\text{Volumetric Weight (kg)} = \frac{\text{Length (cm)} \times \text{Width (cm)} \times \text{Height (cm)}}{5000}$$
     $$\text{Billable Weight} = \max(\text{Physical Weight}, \text{Volumetric Weight})$$
   - **Split Mechanics**:
     - Gross Fare = Base Fare + Road Distance Fare + Weight Surcharge + Fragile Fee.
     - **Driver Net Earnings**: 80% of Gross Fare.
     - **Platform Commission**: 20% of Gross Fare.
2. **Dual Settlement Modes**:
   - **Digital Settlement**: Driver's digital wallet is atomically credited with 80% net earnings upon PIN verification (`TransactionType.deliveryEarnings`).
   - **Cash on Delivery (COD)**: Driver collects 100% physical cash from the recipient. To remit the platform's cut, the driver's digital wallet is atomically debited by 20% (`TransactionType.codCommission`).
3. **Digital Wallet & Ledger ([`WalletScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/wallet/presentation/screens/wallet_screen.dart))**:
   - Real-time balance display, instant card/transfer top-up, and an append-only transaction ledger subcollection at `/users/{userId}/transactions/{transactionId}`.
4. **Driver Withdrawal Request Flow ([`PayoutRequestModal`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/wallet/presentation/widgets/payout_request_modal.dart))**:
   - Couriers submit withdrawal requests specifying destination bank name, 10-digit NUBAN account number, and account name.
   - The requested amount is immediately deducted/locked from the driver's wallet balance to prevent double-spending.
5. **Administrative Settlement Console ([`PayoutManagementScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/wallet/presentation/screens/payout_management_screen.dart))**:
   - Operations queue filterable by status (`All`, `Pending Review`, `Settled`, `Rejected`).
   - **Approve Action**: Confirms bank transfer reference and transitions status to `settled`.
   - **Reject Action**: Captures rejection reason, transitions status to `rejected`, and atomically credits the funds back into the driver's wallet with a `payoutReversal` transaction.

---

### Subsystem 3: Unauthenticated Public Tracking & Waybill Deep-Linking

To ensure end-to-end visibility for senders and recipients without requiring account registration:

```mermaid
flowchart LR
    DeepLink["Public Tracking URL\n/track/{trackingNumber}"] --> AuthCheck{"GoRouter Guard\nstate.startsWith('/track')"}
    AuthCheck -- "Unauthenticated" --> AllowPublic["Public Access Granted\n(No Login Required)"]
    AuthCheck -- "Authenticated" --> AllowPublic
    
    AllowPublic --> PublicScreen["PublicTrackingScreen\n(/track/:trackingNumber)"]
    PublicScreen --> LiveStream["watchOrderByTrackingNumber() Stream"]
    LiveStream --> LiveMap["Interactive OSM Map\n(Pickup, Dropoff, Live Courier GPS)"]
    LiveStream --> Timeline["Real-time Delivery Timeline"]
    LiveStream --> OTPCard["Handover Security PIN Alert\n(Fraud Protection)"]
    LiveStream --> CourierCard["Assigned Courier & Phone Contact"]
```

1. **Zero-Login Deep Linking ([`PublicTrackingScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/delivery/presentation/screens/public_tracking_screen.dart))**:
   - Accessible publicly at `/track/:trackingNumber` or `/track`.
   - Unauthenticated visitors can look up consignments via waybill number.
2. **Live OpenStreetMap Tracking**:
   - Real-time courier coordinates (`driverLatitude`, `driverLongitude`) stream to an interactive map canvas with custom polyline paths.
3. **Fraud-Prevention Handover Security PIN Alert**:
   - Explicitly displays the 4-digit recipient verification PIN banner with instructions to only reveal the code after inspecting the parcel.
4. **Waybill QR Code**:
   - Generates scannable high-resolution QR codes via `package:qr_flutter` for checkpoint verification.

---

### Subsystem 4: Returns, Delivery Exceptions, & Dispute Arbitration

Handles field exceptions, failed delivery drop-offs, customer claims, and administrative resolutions:

```mermaid
flowchart TD
    ExceptionTrigger{"Delivery Incident?"}
    
    ExceptionTrigger -- "Driver cannot complete\n(Recipient unreachable / Wrong address)" --> DriverReport["ReportDeliveryIssueModal\n• Category logged\n• Order marked: failedDelivery"]
    
    ExceptionTrigger -- "Customer reports issue\n(Damaged parcel / Overcharge)" --> CustomerClaim["FileDisputeModal\n• Claimant details & description\n• Dispute ticket logged in /disputes"]
    
    DriverReport --> AdminQueue["Dispute Management Console (/admin/disputes)"]
    CustomerClaim --> AdminQueue
    
    AdminQueue --> ArbitrateAction{"Operator Arbitration"}
    
    ArbitrateAction -- "Approve Refund" --> RefundTx["Atomic Customer Wallet Credit\n• +₦ refundAmount\n• Ledger: TransactionType.refund"]
    ArbitrateAction -- "Return to Hub" --> ReturnLeg["Authorize Return Leg\n• Order marked: returnedToHub\n• returnTrackingNumber assigned"]
    ArbitrateAction -- "Dismiss Claim" --> DismissTicket["Ticket status: rejected\n• Explanation notes recorded"]
```

1. **Driver Delivery Failure Reporting ([`ReportDeliveryIssueModal`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/delivery/presentation/widgets/report_delivery_issue_modal.dart))**:
   - Couriers log delivery failure reasons (`unreachableRecipient`, `wrongAddress`, `packageRefused`, `damagedItem`).
   - Transitions order status to `failedDelivery` and logs operational notes.
2. **Customer Claims Portal ([`FileDisputeModal`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/delivery/presentation/widgets/file_dispute_modal.dart))**:
   - Attached to order tracking screens for reporting damaged packages, missing contents, or driver misconduct.
3. **Operations Arbitration Console ([`DisputeManagementScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/delivery/presentation/screens/dispute_management_screen.dart))**:
   - Dedicated administrative route at `/admin/disputes`.
   - **Issue Wallet Refund**: Atomically credits the customer's digital wallet with the disputed amount.
   - **Authorize Return to Hub**: Updates the consignment status to `returnedToHub` with reverse logistics tracking.
   - **Dismiss Ticket**: Records findings and closes the case.

---

### Subsystem 5: Fleet Intelligence & Business Analytics Engine

Aggregates operational activity into real-time executive decision-making metrics:

1. **Executive Dashboard ([`AnalyticsDashboardScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/admin/presentation/screens/analytics_dashboard_screen.dart))**:
   - **Dynamic Time-Horizon Slicing**: Operators toggle between **Today**, **Past 7 Days**, **Past 30 Days**, and **All Time** with reactive in-memory stream filtering.
2. **Key Metrics Evaluated**:
   - **Gross Merchandise Volume (GMV)**: Total gross booking value across the selected timeframe.
   - **Platform Commission Realized**: Net 20% platform revenue.
   - **Driver Net Payouts**: Net 80% courier earnings.
   - **Fulfillment Funnel**: Completion rate, ongoing in-transit shipments, and failure/return rates.
   - **Settlement Modality Split**: Percentage distribution of Cash on Delivery vs Digital Wallet payments.
   - **Vehicle Allocation Breakdown**: Proportion of volume handled by Motorcycles, Sedans, Cargo Vans, and Trucks.
   - **Courier Performance Leaderboard**: Top drivers ranked by completed volume, rating, and gross revenue generated.

---

### Subsystem 6: Role-Based Routing & Access Control

Navigation and permissions are enforced declaratively at the routing layer via `go_router`:

- **Customer Flow (`/home`)**:
  - Express on-demand hailing ([`ExpressBookingScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/delivery/presentation/screens/express_booking_screen.dart)).
  - Hub-and-spoke consignment parcel creation ([`ConsignmentCreationScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/delivery/presentation/screens/consignment_creation_screen.dart)).
  - Active shipment tracking ([`OrderTrackingScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/delivery/presentation/screens/order_tracking_screen.dart)).
  - Customer digital wallet ([`WalletScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/wallet/presentation/screens/wallet_screen.dart)).
- **Driver Flow (`/driver`)**:
  - Real-time job broadcast reception and acceptance modal.
  - Turn-by-turn navigation view with OSRM polylines ([`ActiveDeliveryScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/delivery/presentation/screens/active_delivery_screen.dart)).
  - Handover verification PIN dialog and delivery exception reporting.
  - Driver earnings ledger and bank withdrawal requests.
- **Admin Flow (`/admin`)**:
  - Operations Command Center ([`AdminDashboardScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/admin/presentation/screens/admin_dashboard_screen.dart)).
  - Live Dispatch Queue ([`DispatchQueueScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/admin/presentation/screens/dispatch_queue_screen.dart)).
  - Fleet Roster ([`DriverManagementScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/admin/presentation/screens/driver_management_screen.dart)).
  - Interactive Fleet Map ([`AdminMapOverviewScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/admin/presentation/screens/admin_map_overview_screen.dart)).
  - Payout Settlement Console ([`PayoutManagementScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/wallet/presentation/screens/payout_management_screen.dart)).
  - Dispute Resolution Desk ([`DisputeManagementScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/delivery/presentation/screens/dispute_management_screen.dart)).
  - Executive KPI Analytics ([`AnalyticsDashboardScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/admin/presentation/screens/analytics_dashboard_screen.dart)).

---

## 5. Cloud Firestore Schema & Security Invariants

All database access is strictly governed by [`firestore.rules`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/firestore.rules):

```
Firestore Database
├── /users/{userId}
│   ├── User profile: uid, email, fullName, role, walletBalance, rating, isAvailable
│   └── /transactions/{transactionId} (Immutable financial ledger)
├── /deliveries/{deliveryId}
│   └── Shipment order: status, pickup, dropoff, parcel, pricing, recipientSecurityOtp
├── /payouts/{payoutId}
│   └── Driver withdrawal: driverId, amount, bankDetails, status (pending/settled/rejected)
└── /disputes/{disputeId}
    └── Support claim: orderId, claimantId, category, status (open/underReview/resolved)
```

### Security Invariants Enforced in `firestore.rules`:
1. **Default Deny**: All unauthenticated and unmapped read/write attempts are blocked at the database root.
2. **Anti-Privilege Escalation**: Users can only register with `customer` or `driver` roles. Self-assigning the `admin` role is strictly blocked.
3. **Immutable Handover Security PIN**: The 4-digit verification PIN (`recipientSecurityOtp`) is immutable on update operations, preventing couriers from tampering with the expected OTP.
4. **Append-Only Financial Ledger**: Subcollections at `/users/{userId}/transactions` and `/wallets/{walletId}/transactions` permit only creation of valid ledger entries; update and delete operations are restricted to administrators.
5. **Driver Assignment Safeguards**: Unassigned deliveries can only be claimed by online drivers if currently unassigned; once claimed, only the assigned driver or an administrator can update delivery status.

---

## 6. Build & Quality Verification

The project complies with enterprise static analysis and multi-platform compilation standards:

- **Static Analysis**: `flutter analyze` runs clean with **0 errors, 0 warnings**.
- **Automated Test Suite**: Comprehensive unit and widget tests passing across domain, infrastructure, and presentation modules (`flutter test`).
- **iOS Dependency Management**: 100% native **Swift Package Manager (SPM)** integration. Zero CocoaPods dependencies.
- **Interactive Architecture Diagram**: Maintained via Archify in [`docs/architecture.html`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/docs/architecture.html).
