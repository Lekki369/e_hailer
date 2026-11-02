# Feature status

This is an implemented development system, not a production-readiness certificate. See the architecture, API, schema and validation documents for precise contracts.

| Area | Implemented | Remaining operational work |
| --- | --- | --- |
| Accounts | Firebase email/phone sign-in, profile recovery, role-aware navigation, restricted self-service profile changes | Provider/platform configuration and physical-device acceptance |
| Booking | Shared responsive express/consignment forms, explicit map selection, contacts, parcel dimensions, server quote, review/edit, single-use booking | Production routing capacity, service-area policy and real driver acceptance |
| Dispatch | Available job projection, vehicle matching, atomic acceptance, administrator assignment/batch reassignment | Pagination and large-fleet operational testing |
| Handover | Private owner PIN, assigned-driver verification, persistent attempt lockout, transactional settlement | Legacy PIN migration and recipient communication process |
| Tracking | Realtime private order streams and redacted expiring public token lookup | Confirmed hosting domain/deep-link associations and retention jobs |
| Wallet | Trusted ledger, balance-backed payouts, Paystack hosted checkout, signed webhook verification, duplicate-safe credits and restart recovery | Real Paystack test-mode acceptance, reconciliation/chargeback handling and bank-transfer automation |
| Support | Participant tickets, support ownership, administrator-only bounded refunds and return closure | Refund funding/accounting policy and operational reconciliation |
| Location | Explicit foreground sharing with errors surfaced and screen cleanup | Background tracking and device/network endurance testing |
| Notifications | Account-scoped registration and disposable foreground subscriptions | Server-side dispatch notification delivery and multi-device acceptance |
| Layouts | Bounded forms/dashboards, stacked/expanded booking and tracking, large-text regression coverage | End-to-end physical Android/iPhone usability review |
| Documentation | First-party architecture/API/data contracts, Archify diagram and scoped Graphify map | Keep artifacts synchronized as code changes |

Direct card checkout on bookings is unavailable; customers fund their wallet through hosted Paystack checkout when configured. Local provider stubs test the integration without taking payments. Payout settlement is an administrative record of a separately confirmed bank transfer. Existing production data requires a staged migration and financial reconciliation before enabling the new trust model.
