# Cloud Firestore Database Schema & Rules

This document outlines the complete database schema for the **e-Hailer** logistics platform.

---

## 1. Collections Overview

```
firestore/
├── users/                # Customer and fleet driver user profiles
│   └── {userId}
├── deliveries/           # Express dispatch and hub consignment orders
│   └── {deliveryId}
└── transactions/         # Digital wallet credit & debit ledger
    └── {transactionId}
```

---

## 2. Collection Schemas

### A. Collection: `users`
Document Path: `/users/{uid}`

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `uid` | `string` | Matches Firebase Authentication `User.uid` |
| `role` | `string` | `"customer"` \| `"driver"` \| `"admin"` |
| `fullName` | `string` | User's full name |
| `email` | `string` | User's email address |
| `phone` | `string` | Contact phone number |
| `avatarUrl` | `string?` | Optional profile image URL |
| `walletBalance`| `number` | In-app credit balance (default: `0.0`) |
| `rating` | `number` | Average rating (default: `5.0`) |
| `isAvailable` | `boolean` | Online/Offline toggle for fleet drivers |
| `vehicleType` | `string?` | `"bike"` \| `"car"` \| `"van"` \| `"truck"` |
| `vehiclePlateNumber` | `string?` | e.g. `"LAG-892-AA"` |
| `vehicleModel`| `string?` | e.g. `"Honda Ace 125"` |
| `createdAt` | `string` (ISO) | Profile creation timestamp |

---

### B. Collection: `deliveries`
Document Path: `/deliveries/{deliveryId}`

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `id` | `string` | Firestore Document ID |
| `trackingNumber` | `string` | Unique consignment waybill ID (e.g. `WAYBILL-948123`) |
| `type` | `string` | `"express"` (On-demand hailing) \| `"consignment"` (Hub parcel) |
| `vehicleType` | `string` | `"bike"` \| `"car"` \| `"van"` \| `"truck"` |
| `status` | `string` | `"created"`, `"searchingDriver"`, `"assigned"`, `"pickedUp"`, `"inTransit"`, `"delivered"`, `"cancelled"` |
| `customerId` | `string` | References sender `users/{uid}` |
| `customerName` | `string` | Sender's display name |
| `customerPhone` | `string` | Sender's contact number |
| `driverId` | `string?` | Assigned fleet driver's `uid` |
| `driverName` | `string?` | Driver's display name |
| `driverPhone` | `string?` | Driver's direct phone number |
| `driverLatitude` | `number?` | Real-time driver GPS latitude |
| `driverLongitude`| `number?` | Real-time driver GPS longitude |
| `pickupLocation` | `map` | `{ latitude, longitude, address, contactName, contactPhone, landmarkOrNote }` |
| `dropoffLocation`| `map` | `{ latitude, longitude, address, contactName, contactPhone, landmarkOrNote }` |
| `parcel` | `map` | Volumetric specification: `{ category, weightKg, quantity, lengthCm, widthCm, heightCm, isFragile, description }` |
| `pricing` | `map` | Fare breakdown: `{ baseFare, distanceFare, weightSurcharge, totalFare, currency, paymentMethod, isPaid }` |
| `distanceKm` | `number` | Real road driving distance calculated via OSRM |
| `estimatedDurationMinutes` | `number?` | Estimated travel time in minutes |
| `recipientSecurityOtp` | `string?` | Secure 4-digit handover PIN (verifies delivery with zero cloud storage costs) |
| `createdAt` | `string` (ISO) | Creation timestamp |
| `pickedUpAt` | `string?` (ISO) | Timestamp when driver picked up package |
| `deliveredAt` | `string?` (ISO) | Timestamp when order was marked completed |
| `cancellationReason` | `string?` | Optional cancellation explanation |
| `cancelledByRole` | `string?` | `"customer"` \| `"driver"` |
| `cancelledAt` | `string?` (ISO) | Timestamp when order was cancelled |
| `customerRating` | `number?` | Rating given by customer (1.0 - 5.0) |
| `customerReview` | `string?` | Optional customer feedback notes |

---

### C. Collection: `transactions`
Document Path: `/transactions/{transactionId}`

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `id` | `string` | Transaction ID |
| `userId` | `string` | References `/users/{uid}` |
| `deliveryId` | `string?` | Associated order ID (if debit/credit is order-linked) |
| `amount` | `number` | Transaction value (positive amount) |
| `type` | `string` | `"credit"` (Top-up, earnings) \| `"debit"` (Payment deduction) |
| `paymentMethod` | `string` | `"wallet"` \| `"card"` \| `"cash"` |
| `status` | `string` | `"success"` \| `"pending"` \| `"failed"` |
| `createdAt` | `string` (ISO) | Transaction timestamp |

---

## 3. Recommended Firestore Composite Indexes

For efficient real-time queries in production, create these compound indexes under **Firestore > Indexes**:

1. **Driver Incoming Request Feed**:
   - Collection: `deliveries`
   - Fields:
     - `status` -> `Ascending`
     - `createdAt` -> `Descending`
   - *Query: `deliveries.where('status', isEqualTo: 'searchingDriver').orderBy('createdAt', descending: true)`*

2. **Customer Order History**:
   - Collection: `deliveries`
   - Fields:
     - `customerId` -> `Ascending`
     - `createdAt` -> `Descending`
   - *Query: `deliveries.where('customerId', isEqualTo: userId).orderBy('createdAt', descending: true)`*
