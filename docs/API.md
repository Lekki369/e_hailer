# Trusted API contract

Serverpod 4.1.0 generates the client and endpoint dispatch. The single authenticated command endpoint is `operations.execute(command, payload, requestId)`. `payload` is a JSON object encoded as a string. `requestId` is a caller-generated 16–128 character `[A-Za-z0-9_-]` key; keep it when retrying the same intent. The generated client supplies serialization. Do not hand-build HTTP URLs in Flutter screens.

Every call needs `Authorization: Bearer <Firebase ID token>`. Identity and role are derived on the server. A reply contains `dataJson` and nullable `errorCode`/`errorMessage`. Missing or invalid authentication is rejected by Serverpod before command execution. Expected business failures are structured; raw exceptions, tokens, PINs and banking payloads are never returned or logged.

| Command | Caller | Input |
| --- | --- | --- |
| `quoteOrder` | Customer | `type`, `vehicleType`, `pickupLocation`, `dropoffLocation`, `parcel`, `paymentMethod` |
| `createOrder` | Quote's customer | Same booking input plus `quoteId`; consumes a valid quote once |
| `acceptJob` | Available matching driver | `orderId` |
| `updateStatus` | Assigned driver | `orderId`, valid `status` milestone; cannot directly set delivered |
| `updateDriverLocation` | Assigned active driver | `orderId`, `driverLatitude`, `driverLongitude` |
| `completeDelivery` | Assigned driver | `orderId`, `pin`; verifies privately and settles atomically |
| `cancelOrder` | Customer, assigned driver or administrator | `orderId`, `reason`; subject to lifecycle policy |
| `rateDelivery` | Booking customer | Delivered `orderId`, `rating` (1–5), optional `review`; once per order |
| `assignOrders` | Administrator | `orderIds` (1–20), `driverId`; compatible online driver |
| `submitPayout` | Driver | `amount`, `bankName`, `accountName`, `accountNumber` |
| `approvePayout` | Administrator | `payoutId`, confirmed manual `transactionRef` |
| `rejectPayout` | Administrator | `payoutId`, `reason` |
| `fileDispute` | Order participant | `orderId`, `category`, `description`, optional `evidenceNotes` |
| `assignDispute` | Support or administrator | `disputeId`, administrator's optional `agentId`; support claims only for itself |
| `resolveDispute` | Assigned support or administrator | `disputeId`, `status`, `resolutionNotes`; `refundAmount` for administrator-only refund |
| `initializeWalletTopUp` | Customer or driver | Integer `amountMinor` in kobo, 10000–100000000; account email required |
| `getWalletTopUp` | Signed-in owner | Empty payload; recover the account's current checkout |
| `verifyWalletTopUp` | Checkout owner | `reference`; server queries Paystack before settlement |
| `topUpWallet` | None | Legacy unchecked-credit command remains unavailable |

Locations require finite latitude/longitude, street address, contact name and phone. Parcel weight is **total actual weight across all pieces**; dimensions are per piece, so volumetric weight includes `quantity`. Accepted vehicles are `bike`, `car`, `van`, `truck`. Accepted payment methods are `wallet` and `cashOnDelivery`; card checkout is unavailable.

## Example booking input

```json
{
  "type": "express",
  "vehicleType": "bike",
  "paymentMethod": "cashOnDelivery",
  "pickupLocation": {"latitude": 6.52, "longitude": 3.37, "address": "Pickup street", "contactName": "Sender", "contactPhone": "08012345678"},
  "dropoffLocation": {"latitude": 6.55, "longitude": 3.40, "address": "Delivery street", "contactName": "Recipient", "contactPhone": "08012345679"},
  "parcel": {"category": "parcel", "weightKg": 2, "quantity": 1, "isFragile": false}
}
```

Request a quote, review its `pricing`, `distanceKm`, `estimatedDurationMinutes` and `expiresAt`, then submit the same input with the returned `id` as `quoteId`. Editing any booking field requires a new quote. Fare and participant fields supplied by a client cannot override trusted data.

## Error and retry behavior

`permission-denied`, `invalid-transition`, `invalid-pin`, `pin-locked`, `insufficient-balance`, `quote-expired`, `quote-changed` and `conflict` require user correction. `unavailable` and network timeouts are ambiguous: retry with the same key. A successful replay returns the committed result without repeating ledger writes. Do not interpret HTTP 200 alone as success; inspect the reply's error fields.

The endpoint has a 64 KiB request limit. PIN attempts have a persistent lockout. Deployment still requires ingress rate limits, operational monitoring and abuse controls; per-user quote/global command rate limits are not implemented here.

## Hosted wallet funding

The three payment commands return `{"topUp": {...}}`; recovery returns `null` when no checkout is active. The allowlisted object contains `reference`, `amountMinor`, `currency`, `mode`, `status` and nullable `authorizationUrl`. It excludes account email and provider secrets. Status is `initializing`, `pending`, `initializationFailed`, `failed`, `abandoned` or `credited`. Only `credited` means wallet value committed.

Initialization binds the UID and request key to a deterministic reference. Reusing that key with a different amount fails; another request for the same amount reuses an active checkout. A 30-second lease prevents simultaneous provider initialization. Failed initialization creates no ledger. After ambiguous failures, recover/check the intent before creating another attempt. Successful settlement atomically records a unique provider receipt, one ledger credit and the new balance. These payment intents are the durable retry mechanism; they do not use generic command receipts.

`payment-unavailable`, `payment-initialization-failed`, `payment-mismatch` and `payment-conflict` never imply a credit. A mismatch/conflict needs investigation with the reference; avoid automatic replacement payments. An unconfigured server returns a safe unavailable error.

## Web listener

`POST /payments/paystack/webhook` uses the separate web listener: port **8789** in development/production and **8799** in tests. It is public but requires exactly one valid `x-paystack-signature` HMAC-SHA512 header over the original bytes. It does not use a Firebase token. Only `charge.success` is processed, and Paystack is queried again before any credit. The amount in the webhook body is not authoritative.

Responses: `200` for handled/replayed/unrelated events, `401` for invalid signatures, `400` for malformed signed JSON, `413` for bodies over 64 KiB, `409` for reconciliation conflicts and `503` for transient failures. Configure ingress to preserve body bytes and forward this exact path. `GET /healthz` returns process liveness only, with no credentials or dependency-health claims. See [PAYMENTS.md](PAYMENTS.md) and [DEPLOYMENT.md](DEPLOYMENT.md).
