# App guide

e-Hailer has four signed-in roles: customer, driver, administrator and support. Public tracking is available without an account. This guide describes the implemented application; see [feature status](FEATURES_SPECIFICATION.md) for unfinished integrations and [development setup](DEVELOPER_GUIDE.md) for local accounts and services.

## Customer: book and follow a delivery

1. Register or sign in using the configured email/phone authentication flow. Complete your profile if account recovery requests it.
2. On the home screen, choose **Instant Express** for on-demand dispatch or **Hub Consignment** for the operations-managed consignment flow.
3. Enter sender and recipient names and phone numbers. Choose each location on the map and enter an address or useful directions. Location permission helps center the map but is not required for manual selection.
4. Choose package category, total actual weight, quantity, dimensions of each package and a vehicle. The current form assumes the same dimensions for every piece; describe exceptional packages in the optional notes.
5. Select cash on delivery or an existing wallet balance. To add funds first, use the wallet's Paystack checkout when configured. Direct card payment on the booking form is unavailable.
6. Select **Review delivery & fare**. Check addresses, contact details, distance and the fare breakdown before confirming. **Edit details or refresh quote** returns you to the form; changed details need a new quote.
7. Confirm once, then open the delivery details to follow progress. A quote expires after ten minutes; refresh it if necessary. A failed or slow connection can leave a request's outcome uncertain, so use the app's retry and check the delivery list before starting another booking.

The customer can access the private handover PIN on the delivery details screen. Share it with the intended recipient for handover; the courier enters it to verify completion. The public tracking view does not contain this PIN.

After completion, the booking customer can submit one rating/review. A participant can raise a dispute when something went wrong. Cancellation is available only when the server's delivery-stage policy permits it; a completed delivery is not reopened through cancellation.

## Customer or driver: add wallet funds

1. Open **Wallet → Top Up**. An unfinished checkout is recovered automatically.
2. Enter an NGN amount between ₦100 and ₦1,000,000, with at most two decimal places, then select **Create checkout**.
3. Read the test-mode banner when shown. Select **Open Paystack** to continue in your browser; enter payment details only on Paystack.
4. Return to the app and select **Check payment status**. A browser return does not establish payment. The app confirms a top-up only after the API has verified and credited it.
5. If payment is pending, check again later or reopen the wallet. Keep the displayed reference for support. A failed or abandoned attempt offers **Start again**; first check its status to avoid paying twice.

Opening checkout, closing the dialog or a failed browser launch never adds money. Without backend payment configuration, the app reports that the payment service is unavailable. Test credits have no cash value and belong only in the isolated test environment. Setup and acceptance steps are in [PAYMENTS.md](PAYMENTS.md).

## Public visitor: track progress

Open a shared tracking link or enter the full tracking code in the tracking portal. The view shows status and milestone history, with available estimated duration. It excludes names, phone numbers, precise locations, wallet information and handover PINs.

A missing, expired or unavailable lookup shows recoverable feedback. Check the complete code, retry after restoring connectivity or contact the sender. If the deployment has no configured public host, sharing copies a code rather than presenting a non-working website link.

## Driver: manage and complete work

1. Sign in as a driver, complete your vehicle details and switch availability on.
2. Review available work and accept a job that matches your vehicle. Acceptance is confirmed by the server; another courier may already have taken it.
3. Open the active delivery and follow the allowed milestones. Assignment and status changes update the customer and operations views.
4. Enable location sharing when needed. Sharing is foreground-only and tied to the active screen; it stops on screen cleanup or a reported service error. Do not rely on it for background tracking.
5. At handover, enter the recipient's four-digit PIN. Repeated incorrect attempts trigger a temporary lockout. Completion and settlement occur only after the backend accepts verification.
6. Review your wallet history. A payout request reserves the requested amount from available funds. Staff can record a confirmed manual transfer or reject the request, returning the reserved amount once.

For cash orders, the courier collects the fare outside the digital wallet. The system records the commission owed; collection must follow the operator's real cash-handling process. A screen status is not a bank transfer confirmation.

## Administrator: coordinate operations

Use the dispatch queue and fleet views to review pending work, availability and delayed deliveries. Assign compatible online drivers; batch assignment is limited to twenty orders per command. Reassignment and completion preserve remaining active assignments.

Operations summaries distinguish active work from terminal deliveries and derive collected financial totals from settlement data. Historical on-time performance uses delivery timestamps and a route estimate plus the configured buffer; missing measurements are not treated as proof of on-time delivery.

Payout processing is manual: verify the external transfer, then record its reference. The app does not initiate a bank transfer. Refunds require administrator authority and are bounded by confirmed collections and previous refunds. Follow the documented funding and reconciliation policy before using these commands with real money.

## Support: resolve a dispute

Support staff can review and claim an eligible dispute, record resolution notes and perform supported non-financial actions for their assigned work. Administrators can assign another staff member and authorize refunds. Resolutions and assignments write audit events so responsibility remains traceable.

## Recovery and accessibility

- **Service unavailable:** confirm that the API is configured and reachable; the app does not substitute simulated bookings or credits.
- **Location unavailable:** choose a map pin manually and enter directions. The app requests foreground location only.
- **Quote changed or expired:** edit/review the details and request a fresh quote.
- **History or tracking error:** use **Try again** after checking the connection. Raw SDK error details are not shown in the common recovery panels.
- **Large text or small windows:** forms remain scrollable and primary panels stack; avoid reducing your system text size to complete a booking.
- **Licenses:** open **Profile & Settings → Open-source licenses** for dependency and font notices. The project's source uses the [MIT License](../LICENSE).

Screenshots in the repository overview are synthetic widget fixtures. Full customer-to-driver acceptance on production services and physical devices remains a release check, not something those images prove.
