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
