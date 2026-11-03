# Driver access and API abuse controls

Implemented on 2026-11-02 against baseline `09a0649663a2ab44e3ce57fa50c96442bad1d7a3`. This describes source changes and local verification; it does not claim a Firebase or backend deployment.

## Driver approval workflow

1. Drivers register with zero balance, offline and unapproved. Registration cannot grant approval or an operating area.
2. The driver enters their vehicle category, plate and model in Profile. Administrators must verify identity and vehicle details through their own onboarding process before approving; this app does not perform identity verification.
3. An administrator opens **Fleet Drivers Roster**, reviews the driver and selects **Review and approve**. They choose an operating-area centre using the existing map picker, review the driver, vehicle and area, then confirm.
4. The trusted API records approval, permitted area IDs, the area label, administrator UID and time. A separate private audit document records each approval/revocation. Support and driver accounts cannot approve drivers.
5. The driver receives the profile update and can go online. Approval itself leaves the driver offline.
6. An administrator can revoke approval from the same roster. Active jobs must first finish or be reassigned. Revocation clears the area permissions and forces the account offline. To change an approved vehicle or area, revoke approval, update/review the details, then approve again.

Missing approval fields fail closed. No existing driver is implicitly approved. Approved vehicle fields cannot be edited directly by the driver; contact-profile changes remain available.

## Job visibility and location privacy

Both Firestore rules and backend assignment commands enforce approved vehicle and pickup-area permissions. An online driver can read only offers matching their approved vehicle and area IDs. Lists require a limit of at most 30; the app supplies both filters and that limit. The corresponding composite index is shipped in `firestore.indexes.json` and referenced by `firebase.json`.

The selected operating centre grants its 0.1-degree latitude/longitude cell and eight neighbouring cells. This forms a grid-aligned area approximately 33 km north to south; east-west width varies by latitude. It is an operating-zone policy, not a GPS radius or proof that a driver is physically nearby. Pickup eligibility is derived from the order's validated coordinates on the server; a client-supplied zone cannot override it. The map confirmation explains the approximate extent. Locations close to zone boundaries follow these explicit cells.

Offers contain job ID/type/status, vehicle, fare, road distance/duration, creation time, pickup-area ID and coarse pickup/drop-off cell centres. They omit customer identity, contacts, exact addresses/coordinates, parcel descriptions/notes, PINs and public tracking tokens. The driver can choose **View approximate areas** to inspect those broad areas on a map. Exact delivery details become readable only after assignment, when the driver becomes a participant. Authorized customer and staff reads are unchanged.

Accepting a job and manual/batch assignment use the same vehicle/area policy inside the order transaction. Guessing an order ID or bypassing the Flutter UI cannot bypass approval. Assignment/revocation races share the driver document, so a conflicting transaction retries against current permissions. Previously viewed or cached data cannot be recalled by revoking future access.

## Durable API quotas

Every authenticated `operations.execute` request consumes a shared per-Firebase-UID token bucket before command-payload decoding or business/provider work. Malformed requests, unknown commands, reads and retries consume quota too. Keys use a UID digest; arbitrary command names share one fixed bucket instead of creating unbounded database fields. Firestore transactions serialize concurrent requests across API instances. Missing/unavailable quota storage does not permit the request to proceed.

| Bucket | Initial burst capacity | Continuous refill |
| --- | --- | --- |
| All commands combined | 120 | 120 tokens/minute |
| Delivery quotes | 10 | 10 tokens/minute |
| Payment initialization | 5 | 5 tokens/10 minutes |
| Payment verification | 20 | 20 tokens/minute |
| Driver location updates | 90 | 90 tokens/minute |
| All remaining/unknown commands combined | 30 | 30 tokens/minute |

Each request needs a token from both its specific bucket and the combined bucket. These are token buckets, not strict rolling-window counts: a burst consumes accumulated capacity, then tokens return gradually. For example, an exhausted funding bucket gains one token every two minutes. Server restarts do not reset persisted balances. Backward clock movement grants no extra tokens.

Quota denials return the existing command envelope with `errorCode: resource-exhausted`. The app displays the error and retains the idempotency key for a later user retry, including when an earlier request's outcome is uncertain. It does not automatically retry in a tight loop. Payment webhooks remain on their separately signed, bounded-body route; customer quota exhaustion does not prevent settlement through a legitimate webhook.

The RPC envelope is bounded by Serverpod's configured 64 KiB maximum request size. The command also rejects payload strings above 32,768 code units or command names above 80 code units. These application checks run after authentication and are not connection-level deadlines.

## Deployment and limits

- For this user's fresh-start rollout, the user will remove any old Firebase data; no production deletion or migration was performed here. Keep the legacy migration guide for deployments that retain old users or balances.
- Deploy the backend, matching client, Firestore rules and indexes together. From the selected Firebase project, rules/index deployment uses `firebase deploy --only firestore:rules,firestore:indexes --project <project-id>`. This command is a deployment step for the operator; it has not been run here. Wait for the index to become ready before accepting driver traffic.
- Provision the first administrator through a trusted administrative process. Self-registration cannot create admin/support roles. Do not loosen rules to bootstrap staff.
- Verify the restrictions against the actual deployed project with synthetic accounts: pending driver, approved driver in the right area/vehicle, wrong area/vehicle, revoked driver and non-admin approval attempt. Confirm that exact locations are absent from offer documents and present only in authorized delivery reads.
- Per-account RPC quotas do not cover Firebase sign-up/SMS/password reset, direct Firestore reads/listeners, unauthenticated token-verification traffic, public tracking or signed webhook throughput. Multi-account abuse remains possible. Set Firebase Authentication/SMS quotas and appropriate App Check enforcement; configure ingress IP limits, connection/body deadlines and monitoring before public launch.
- Every quota attempt still reaches authentication and Firestore. Quotas limit downstream work, not all infrastructure cost. Observe rejected traffic and resource usage at ingress; do not log tokens, PINs or request bodies.
- Quota documents contain bounded bucket state and persist by account. Approval audit records persist by event. Define retention with the account/audit policy; deleting live quota documents resets their burst allowance. Never permit client access to these collections.
- Real Paystack test-mode acceptance, production credentials/configuration, signing and physical-device acceptance remain separate release work.

## Verification

Run Flutter checks sequentially:

```sh
flutter analyze
flutter test --no-pub
```

Run the backend analyzer and local-emulator regression suite:

```sh
cd server/ehailer_server
dart analyze
cd ../..
bash tool/test_emulators.sh
```

On this Mac, the existing Node compatibility wrapper can be selected with `E_HAILER_NODE="$PWD/.cache/node-compat/node" bash tool/test_emulators.sh`; it uses the installed compatible simdjson library without changing system links.

The emulator runner uses only `demo-ehailer`. It covers denied self-approval, online gating, scoped offer queries, private approval/quota collections, backend acceptance/manual-assignment restrictions, coarse projections, concurrent payment initialization quotas, refill, clock rollback, cross-instance persistence and actual HTTP enforcement before invalid-command/payment work. Client tests check subscription removal after revocation and preservation of request keys on rate-limit responses. See [VALIDATION.md](VALIDATION.md) for completed results and limits.

Completed local results: **197 Flutter tests, 45 emulator/backend/API tests and 15 Firestore rules tests passed**. Flutter and backend analyzers found no issues; the publishable-file guard reported 0 findings. No deployment or physical-device acceptance is claimed.
