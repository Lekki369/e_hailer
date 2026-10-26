# e-Hailer Feature Specifications

This document specifies the technical and business logic governing all features in the **e-Hailer** platform.

---

## 1. Express On-Demand Dispatch Hailing
*Synthesized from **myoga** and **deliverzler***

### Purpose
Enables instant point-to-point courier hailing (motorcycles, sedans, cargo vans). Customers tap on the map to set pickup and dropoff locations, preview road routes, view upfront pricing, and broadcast the request to nearby drivers.

### Technical Workflow
1. **Interactive OpenStreetMap**:
   - Implemented via [`flutter_map: ^7.0.2`](https://pub.dev/packages/flutter_map) and [`latlong2: ^0.9.1`](https://pub.dev/packages/latlong2).
   - Loads open raster tiles with no API key or billing required.
2. **Road Path & Real Distance Generation (OSRM)**:
   - Queries the Open Source Routing Machine:
     `https://router.project-osrm.org/route/v1/driving/{lon1},{lat1};{lon2},{lat2}?overview=full&geometries=geojson`
   - Yields the exact road polyline (`List<LatLng>`), real road distance in kilometers, and estimated drive duration in minutes.
3. **Driver Radius Broadcast**:
   - When confirmed, the order document is created in Firestore with `status: DeliveryStatus.searchingDriver`.
   - Fleet drivers running [`DriverDashboardScreen`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/delivery/presentation/screens/driver_dashboard_screen.dart) receive the job in their real-time stream (`availableOrdersStreamProvider`).
   - The first driver to tap **"Accept Delivery Job"** atomically binds `driverId`, `driverName`, and `driverPhone` and transitions the order to `DeliveryStatus.assigned`.

---

## 2. Volumetric Parcel Consignment
*Synthesized from **courierManagementSystem***

### Purpose
Handles standard multi-hop package deliveries, heavy parcels, boxes, and freight where cargo density dictates pricing.

### Dimensional Volumetric Weight Formula
Cargo pricing must account for low-density, bulky goods that occupy vehicle volume.
Standard IATA courier formula:
$$\text{Volumetric Weight (kg)} = \frac{\text{Length (cm)} \times \text{Width (cm)} \times \text{Height (cm)}}{5000}$$

$$\text{Billable Weight} = \max(\text{Actual Weight}, \text{Volumetric Weight})$$

### Business Rules
- **Standard Weight Allowance**: First 2.0 kg covered under base fare.
- **Excess Weight Surcharge**: $\text{Extra Weight (kg)} \times ₦80/\text{kg}$.
- **Fragile Handling**: Adds a flat $₦300$ protective fee and flags the order as fragile.
- **Waybill Number**: Auto-generates a unique tracking consignment number:
  $$\text{WAYBILL-TIMESTAMP}$$
  Rendered on-screen as a scannable 2D QR Code using `package:qr_flutter`.

---

## 3. Zero-Cloud-Storage Handover Verification PIN

### Purpose
Provides fraud-proof delivery verification without requiring paid Firebase Cloud Storage (GCS) for signatures or photo uploads.

### Mechanism
1. Upon creating any shipment, the system generates a cryptographic 4-digit numeric PIN:
   $$\text{OTP} = \text{Random}(1000 \dots 9999)$$
2. The PIN is stored directly on the Firestore order document (`recipientSecurityOtp`).
3. Only the sender and the recipient (via tracking link or notification) have access to the PIN.
4. When the rider reaches the drop-off location, the recipient reads the PIN to the courier.
5. The courier inputs the PIN into the app. When validated, the order transitions to `DeliveryStatus.delivered`.

---

## 4. Dynamic Fare Calculation & Earnings Split
*Handled by [`PricingCalculator`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/delivery/domain/services/pricing_calculator.dart)*

### Fare Breakdown:
$$\text{Base Fare} = ₦500 \times \text{VehicleMultiplier}$$
- Motorcycle: $1.0\times$ ($₦500$)
- Sedan: $1.5\times$ ($₦750$)
- Cargo Van: $2.2\times$ ($₦1,100$)
- Heavy Truck: $3.5\times$ ($₦1,750$)

$$\text{Distance Fare} = \text{DistanceKm} \times ₦120/\text{km}$$

$$\text{Weight Surcharge} = \max(0, \text{BillableWeight} - 2.0) \times ₦80/\text{kg}$$

$$\text{Total Fare} = \text{Base Fare} + \text{Distance Fare} + \text{Weight Surcharge} + \text{Fragile Fee}$$

### Split Model:
- **Driver Net Earnings**: $80\%$ of Total Fare.
- **Platform Commission**: $20\%$ of Total Fare.

---

## 5. Operations Dispatch Command Center & Fleet Assignment Engine
*Handled by the **`admin`** feature module (`lib/features/admin/`)*

### Purpose
Transforms e-Hailer from a client-driver hailing app into a comprehensive logistics operations platform with operational oversight, manual dispatch intervention, and fleet tracking.

### Core Capabilities
1. **Multi-Role Product Separation & Guards**:
   - `UserRole.admin`: Directly redirected to `/admin` (`AdminDashboardScreen`).
   - Non-admin attempts to access `/admin/*` routes are intercepted and redirected to their appropriate role home.
   - Profile-level terminal switcher allows testing across Customer, Driver, and Admin roles instantly.

2. **Real-Time Operational KPI Metrics**:
   - Live counters for Pending Dispatch, In-Transit Packages, Delivered Today, Active Fleet Ratio, Total Revenue, and Total Billable Volume.
   - Tapping any metric tile opens the filtered dispatch queue view.

3. **Live Dispatch Queue (`DispatchQueueScreen`)**:
   - Continuous Firestore synchronization of all orders sorted newest-first.
   - Status filters: `All`, `Pending`, `Assigned`, `In Transit`, `Delivered`, `Cancelled`.
   - Real-time instant search by Waybill number, customer name, phone number, or street address.

4. **Manual Driver Assignment & Reassignment (`ManualAssignmentModal`)**:
   - Hub operators can manually assign unassigned orders or reassign delayed/stalled deliveries.
   - Filters registered drivers, highlighting those with `isAvailable == true` and matching vehicle class.
   - Atomic Firestore batch updates the order status to `assigned` and sets `currentOrderId` on the driver's profile.

5. **Fleet Roster Management (`DriverManagementScreen`)**:
   - Comprehensive fleet directory with availability status, vehicle type badges, ratings, and active job status.
   - Filter by Online / Offline and instant search by driver name, phone, or license plate.

6. **Interactive Fleet Map Overview (`AdminMapOverviewScreen`)**:
   - Zero-billing OpenStreetMap raster map displaying:
     - Online driver locations (green vehicle markers).
     - Active pickup points (orange parcel markers).
   - Tapping any pin presents detailed operational metadata and direct assignment actions.

---

## 6. Payment, Wallet Settlement, & Driver Payout Engine
*Handled by the **`wallet`** feature module (`lib/features/wallet/`)*

### Purpose
Provides a complete financial operating system supporting dual cash/digital settlement, fair 80/20 driver revenue splitting, driver withdrawal requests, and administrative payout processing.

### Technical & Business Rules
1. **Dual Payment Modalities**:
   - **`PaymentMethod.wallet` / `card`**: Customer pays up front. Upon successful delivery verification with the 4-digit recipient PIN, `DeliveryRemoteService.verifyAndCompleteDelivery()` credits the driver's wallet with 80% net earnings (`TransactionType.deliveryEarnings`).
   - **`PaymentMethod.cashOnDelivery`**: Recipient pays cash to the driver upon handover. Since the driver has 100% in cash, the platform's 20% commission fee is deducted from the driver's digital wallet (`TransactionType.codCommission`).

2. **Driver Payout Request Flow (`PayoutRequestModal`)**:
   - Drivers with positive wallet balance can initiate withdrawals at any time.
   - Bank Selection: Major Nigerian banks and FinTechs (Access, GTBank, Zenith, First Bank, UBA, Kuda, OPay, Moniepoint, etc.).
   - Amount Selection: Quick preset chips (`₦2,000`, `₦5,000`, `₦10,000`, `All`) or custom amount up to the current balance.
   - Balance Locking: The requested amount is instantly debited from the driver's `walletBalance` upon request creation to prevent double withdrawals, creating a `PayoutRequest` in `pending` status.

3. **Admin Payout Management Console (`PayoutManagementScreen` at `/admin/payouts`)**:
   - Status Filters: `All`, `Pending Review`, `Settled`, `Rejected`.
   - Real-time search by driver name, phone number, and bank account number.
   - Action Modal 1: **Approve & Mark Settled** — Operator inputs or confirms bank transfer transaction reference; status transitions to `PayoutStatus.settled`.
   - Action Modal 2: **Reject & Refund** — Operator inputs reason for rejection (e.g., incorrect account name). Status transitions to `PayoutStatus.rejected` and the requested amount is atomically refunded back into the driver's wallet balance with a `TransactionType.payoutReversal` entry.

4. **Universal Fare Breakdown Bottom Sheet (`FareBreakdownBottomSheet`)**:
   - Accessible from Customer Tracking (`OrderTrackingScreen`), Driver Terminal (`ActiveDeliveryScreen`), and Admin Queue (`DispatchQueueScreen`).
   - Detailed visual breakdown showing:
     - Gross Fare Total
     - Vehicle Base Fare (with vehicle multiplier)
     - Distance Charge (₦120/km)
     - Billable Weight & Volumetric Surcharge (₦80/kg over 2kg)
     - Fragile Item Surcharge (₦300 if applicable)
     - 80% Driver Earnings vs 20% Platform Commission
     - Payment Method Badge (Cash on Delivery vs Digital Wallet)

---

## 7. Customer Public Tracking Portal & Waybill Deep-Linking Engine
*Accessible at `/track` and `/track/:trackingNumber`*

### Purpose
Enables senders, recipients, and third-party customers to monitor the real-time lifecycle of their parcel without logging in or downloading the native app.

### Technical & Business Rules
1. **Unauthenticated Public Route Security**:
   - `GoRouter` redirect configuration explicitly excludes `/track` and `/track/*` from the mandatory authentication redirect.
   - Anyone holding the tracking URL can monitor shipment progress.

2. **Real-Time Tracking Stream (`watchOrderByTrackingNumber`)**:
   - Streams live Firestore updates using an indexed `where('trackingNumber', isEqualTo: cleanCode)` query.
   - Automatically re-renders the map with real-time driver coordinates whenever the courier's location updates.

3. **Step-by-Step Delivery Progress Stepper**:
   - Highlights ongoing vs completed stages:
     - Stage 1: Shipment Booked / Created.
     - Stage 2: Courier Assigned / Dispatched.
     - Stage 3: Parcel Picked Up from Origin.
     - Stage 4: In Transit / Out for Delivery.
     - Stage 5: Delivered & Recipient Security PIN Verified.
   - Displays clear cancellation alerts if the order is aborted.

4. **Recipient Security Handover PIN Verification**:
   - Displays the cryptographic 4-digit numeric PIN (`recipientSecurityOtp`) on the tracking interface.
   - Provides clear guidance that this code must only be provided to the dispatch courier upon physical receipt.

5. **Consignment Specifications & Fare Transparency**:
   - Displays package category, physical weight, dimensions, IATA volumetric weight, and billable weight.
   - Shows total fare and provides access to the universal fare breakdown modal.

6. **Social Sharing & QR Barcodes**:
   - One-tap link copy (`https://ehailer.app/track/{trackingNumber}`) for SMS or messaging app dispatch.
   - Interactive modal presenting a large 2D QR Code waybill for sorting hub scanning.
