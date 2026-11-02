# e-Hailer architecture

The Flutter application owns presentation and realtime subscriptions. **Serverpod owns all delivery and financial commands.** Firebase Authentication establishes identity; Firestore stores operational state. There is no PostgreSQL or Redis requirement in this implementation.

See the [interactive architecture](architecture.html), [data model](DATABASE_SCHEMA.md), [API contract](API.md), [developer guide](DEVELOPER_GUIDE.md) and [validation record](VALIDATION.md). The architecture describes this working tree; it is not a deployment claim.

The [delivery overview](architecture.html) emphasizes command authorization and client read boundaries. The separate [Paystack architecture](payments-architecture.html) traces hosted checkout, the signed public webhook and verified settlement. Tile rendering, optional geocoding and notification registration are described below. Sources are pinned to **isolated local Git snapshots of the implementation**, not the repository's original HEAD. Each diagram's `*-evidence.json` records its base revision, snapshot and source hashes. The snapshot tool does not change the application branch or index.

## Repository organization

```text
lib/
  core/{domain,infrastructure,presentation,routing}/
  features/{auth,delivery,map,wallet,admin,notification}/
    domain/             # Equatable entities, manual mappers, policies
    infrastructure/     # Firebase reads and trusted API adapters
    presentation/       # Riverpod providers, widgets, screens, routes
server/
  ehailer_server/
    bin/                # API entrypoint and read-only legacy inventory
    config/             # development, test, production and generator settings
    lib/src/core/       # command-store abstraction, failures, Firestore adapter
    lib/src/features/   # delivery policies, routing, operations and payments
    lib/src/generated/  # Serverpod-generated transport and dispatch code
    test/               # transactional behavior and HTTP authentication tests
  ehailer_client/       # generated Dart transport contract consumed by Flutter
test/                   # Flutter domain, API adapter, route and layout tests
tool/                   # emulator runner, Firestore rules tests, Graphify refresh
docs/                   # first-party architecture and operational guidance
```

Flutter domain code imports neither Firebase nor Flutter UI. Infrastructure results use `Either<AppFailure,T>`; providers deliberately translate failures into Riverpod error states where appropriate. Server domain commands throw typed `OperationFailure` internally so failed transactions roll back; the endpoint catches these and returns safe, structured failures. Unknown exceptions never expose request payloads.

## Identity and trust boundaries

`OperationsApi` attaches a fresh Firebase ID token to the generated Serverpod client. The server validates the token, including revocation, and reads the caller's role from Firestore. Payload fields such as `driverId`, `customerId`, `role`, fare or current wallet balance cannot authorize an action.

Firestore rules permit narrowly scoped profile changes and authorized reads. All client delivery, timeline, wallet-ledger, payout, dispute and public-projection writes are denied, including administrator clients. Staff access requires an administratively provisioned role; self-registration permits customer or driver only. Navigation guards are a usability layer, not the security boundary.

Public tracking reads one expiring projection using a random 128-bit tracking token. It contains status and milestone timestamps, never contacts, addresses, coordinates, banking details, price or PIN. The booking customer reads the PIN from a separate private document; couriers and support cannot read it.

## Booking and delivery lifecycle

1. The customer selects actual map coordinates, contacts, parcel details, vehicle and payment method.
2. `quoteOrder` requests an OSRM road route and computes the fare on the server. A quote binds its customer and input for ten minutes.
3. The review screen displays the quote. `createOrder` consumes it exactly once and, for wallet payment, debits the balance in the same transaction as order creation, ledger, PIN, timeline and public/job projections.
4. A courier accepts an available job or an administrator assigns a compatible online courier. Transaction reads prevent competing acceptances. Batched assignments maintain `activeOrderIds` and the next `currentOrderId`.
5. Only the assigned courier can advance valid stages. Completion verifies the private PIN, settles once, removes the PIN and releases the assignment. Five incorrect attempts lock verification for fifteen minutes. Replaying the same failed request does not consume another attempt.
6. Delivered, cancelled and returned deliveries cannot reopen, even through an administrator override. Cancellation refunds only the remaining collected wallet fare.

## Money and retries

Money is validated and calculated as integer minor units at transaction boundaries; persisted legacy-compatible amounts remain numeric NGN values. The rounded fare equals courier earnings plus commission. Cash completion records commission owed, and may produce a negative courier balance; withdrawals require sufficient available funds.

Command receipts bind UID, command and request key to a canonical payload hash. Flutter coalesces concurrent identical requests and retains keys after ambiguous transport failures. Server receipts survive process restarts; Flutter's pending-key cache is in memory. Quotes independently prevent duplicate bookings across app restarts. Check payout history before repeating an ambiguous withdrawal after restarting the app.

Payout requests reserve funds atomically. Rejection restores them once. “Mark settled” records an administrator-confirmed **manual bank transfer** and reference; it does not execute or verify a transfer. Only administrators can refund disputes, and cumulative refunds cannot exceed confirmed collection. Refunds after settlement are platform-funded adjustments; courier earnings are not silently clawed back.

## Hosted payment boundary

Flutter's wallet adapter calls authenticated payment commands through the existing transport. `PaymentService` creates a private intent before contacting Paystack and returns a validated hosted checkout URL. Browser navigation and return callbacks grant no wallet value. The owner can recover the active intent after an app restart or request verification.

Paystack also calls a separate public web route. HMAC-SHA512 authenticates the raw event body before parsing. Both this route and owner verification use the same service: query Paystack, compare reference, mode, currency, amount and email, then atomically credit once with a unique provider transaction receipt and deterministic ledger ID. A late event cannot erase a newer pending checkout.

Provider credentials stay in the server environment. Test mode requires both Firebase emulators with a demo project, or an explicitly designated isolated staging project. Mixed real/emulated identity and storage fail startup validation. No key means checkout is disabled. Provider refunds, chargebacks, durable webhook queues and scheduled reconciliation are still operational work; direct card booking payment and automated bank transfers remain unavailable. See [payment details](PAYMENTS.md).

## UI, maps and operational limits

Shared layouts use available width: compact below 600 px, medium from 600 px and expanded from 840 px. Booking and tracking use side-by-side panels when space permits and stack at large text sizes. Forms and dashboards have bounded widths. ScreenUtil scaling is disabled so desktop widths do not inflate every font and spacing value. The interface font is bundled for offline rendering.

GPS sharing is opt-in and foreground only. It reports backend failures and stops when the active screen is disposed; background location delivery is not implemented. Notification subscriptions follow account identity and are disposed correctly; dispatch-triggered push sending is not implemented.

OSRM and tile defaults are development conveniences, not capacity guarantees. Configure operational map services before launch. Address search requires an explicitly configured Nominatim-compatible service; pin selection works without it. See the developer guide for public-service restrictions.

## Generation and preservation

Deployment values are separate from source. `tool/flutter_env.py` accepts only public client settings, generates ignored platform/worker configuration and passes validated settings with `--dart-define-from-file`. The server and Android signing have separate private env files; their credentials never enter Dart defines. Runtime permission checks remain necessary because public client identifiers are extractable from builds. See [ENVIRONMENT.md](ENVIRONMENT.md) and [SECURITY_AUDIT.md](SECURITY_AUDIT.md).

The existing `AGENTS.md` is preserved. The user-selected Serverpod architecture requires protocol generation only inside `server/ehailer_server/lib/src/generated` and `server/ehailer_client`; Flutter domain models remain handwritten, with no build_runner, Freezed or Riverpod generator. Generated transport is regenerated, not hand-edited.
