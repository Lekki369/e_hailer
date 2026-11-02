# Firestore data model

Firebase UID is the identity key. Unless listed as editable below, client writes are denied and trusted Serverpod transactions own mutations. Dates are UTC ISO-8601 strings; monetary values are NGN numbers converted to validated integer kobo before arithmetic.

| Path | Purpose | Client access |
| --- | --- | --- |
| `users/{uid}` | Role, contact profile, wallet balance, vehicle, availability, rating, active order IDs | Own get; staff reads/lists. Self-create customer/driver with zero balance. Own contact, vehicle/availability and messaging registration edits only. |
| `users/{uid}/transactions/{id}` | Positive amount plus explicit credit/debit transaction type and reference | Owner or administrator read; server writes only. |
| `deliveryQuotes/{id}` | Customer, input hash, authoritative route/fare, expiry, consumed order ID | Server only. |
| `deliveries/{id}` | Participant contacts, locations, parcel, pricing, lifecycle, settlement and cumulative refund amount | Owner, assigned driver or staff read. |
| `deliveries/{id}/timeline/{eventId}` | Immutable milestone, authenticated actor, role and timestamp | Same authorized readers as order. |
| `deliveryPins/{orderId}` | Customer UID, random four-digit PIN, attempt count and lock expiry | Owner get only; no list; no driver/staff access. Deleted on terminal handover/cancellation/return. |
| `jobOffers/{orderId}` | Available-job projection with route coordinates and parcel/fare; no contact identity or PIN | Authenticated drivers read. Deleted on assignment/closure. |
| `publicTracking/{randomToken}` | Allowlisted status, type, vehicle, estimated duration, timestamps and bounded timeline | One unexpired document lookup without sign-in. Lists/writes denied. |
| `payouts/{id}` | Reserved withdrawal, bank details, pending/settled/rejected state and transfer reference | Requesting driver or administrator read. |
| `payouts/{id}/audit/{eventId}` | Administrator action and processing metadata | Administrator read. |
| `disputes/{id}` | Claimant, order, category, description, assignment and resolution | Claimant, target driver or staff read. |
| `disputes/{id}/audit/{eventId}` | Trusted actor/action/timestamp | Staff read. |
| `commandReceipts/{hash}` | UID, command, canonical request hash, result and commit timestamp | Server only. |
| `paymentIntents/{reference}` | UID, email snapshot, integer amount, NGN currency, test/live mode, initialization lease, checkout URL and verification status | Server only; owner receives an allowlisted view through the API. |
| `paymentSettlements/paystack-{mode}-{transactionId}` | Unique provider transaction receipt, reference, UID and amount | Server only; prevents reuse across top-ups. |

## Atomic invariants

- An order, wallet charge, PIN and initial projections commit together.
- Deterministic ledger IDs prevent duplicate settlement, cancellation refund and payout reversal.
- Payout reservation reads the balance inside the transaction; concurrent requests cannot overdraw it.
- A courier's active assignment list is updated when accepting, assigning, completing, cancelling or returning a delivery.
- Dispute refunds read and update the order's cumulative refund amount, including across separate tickets.
- Receipt replay verifies the original payload hash. Changing input while retaining a key is a conflict.
- A top-up credits `users/{uid}/transactions/topup-{reference}`, balance, intent and provider receipt in one transaction only after server verification. Concurrent webhook/manual checks cannot credit twice.
- The server-owned `users/{uid}.pendingTopUpReference` enables app-restart recovery. Late settlement clears it only if it still refers to that payment, preserving a newer checkout.

Payment intents retain only the fields needed for verification and recovery. Card details, card authorization tokens, raw provider responses and webhook bodies are not persisted. Payment references identify attempts, not proof of money. Test receipts and credits must remain in an isolated project. Provider refunds/chargebacks require separate reconciliation; they are not handled by the top-up settlement command.

## Retention and indexing

Public projections expire for reads after thirty days from the most recent published milestone. Expiry denies access; it does **not** delete the document. Configure and test retention jobs/TTL separately. Do not purge command receipts without a documented idempotency retention policy. Current participant queries use single-field filters; sorting small result sets occurs client-side. Large operational datasets need pagination and server-side aggregates before launch.

## Existing data migration

Older orders may contain `recipientSecurityOtp` inside the readable order document and short guessable tracking codes. Tightening rules alone does not remove those fields. Before enabling this API against existing production data:

1. Back up Firestore and inventory it with `FIREBASE_PROJECT_ID=... dart run bin/audit_legacy.dart` from the server package. This command is read-only and prints counts only.
2. Rotate legacy public codes; migrate active PINs into private documents and remove the old order field. Previously exposed PINs must be regenerated and privately delivered to the customer.
3. Reconcile wallet balances against real payments and ledger evidence. Never assume prior client-created credits are valid money.
4. Reconcile delivered orders and settlement markers; build active driver lists from verified assignments.
5. Rebuild allowlisted job/public projections, test on a staging copy, and deploy coordinated client/API/rules changes.

No live inventory, migration or deployment has been performed by this change.
