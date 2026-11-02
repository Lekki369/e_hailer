# Paystack wallet funding

Customers and drivers can add NGN wallet funds through Paystack hosted checkout. The integration is implemented with local-provider tests; a real Paystack test-mode checkout has not yet been accepted. Direct card payment on bookings and automated bank payouts are separate, unfinished capabilities.

Explore the [interactive payment architecture](payments-architecture.html) for code-backed trust boundaries and settlement ownership.

## Request and settlement flow

1. The authenticated API validates an integer kobo amount (₦100–₦1,000,000) and the account email, then saves a private payment intent.
2. The backend initializes Paystack with its secret key and returns only an allowlisted view, including an HTTPS `checkout.paystack.com` URL. Flutter opens this in the external browser; no payment SDK or card collection runs in the app.
3. The owner can check payment status. A signed `charge.success` webhook independently triggers the same verification path.
4. The backend queries Paystack and checks successful status, reference, test/live mode, NGN currency, exact amount and email before settlement.
5. One Firestore transaction creates the provider receipt and wallet ledger entry, updates the balance and marks the intent credited. Duplicate events, concurrent verification and retries cannot credit the same payment again.

This follows Paystack's [transaction initialization contract](https://paystack.com/docs/api/transaction/), [server verification guidance](https://paystack.com/docs/payments/verify-payments/) and [raw-body webhook signature requirements](https://paystack.com/docs/payments/webhooks/). Browser redirects and provider HTTP success alone are never proof of a successful payment.

## Configure isolated test mode

Start with the normal Firebase emulator setup in [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md). Supply `PAYSTACK_MODE=test` and a Paystack test secret through the **server process environment**. Use your secret manager or ignored `server/ehailer_server/.env`, loaded by `python3 tool/server_env.py`. Plain Dart does not load the file automatically. Never place the secret in the client env, Flutter defines, Git, logs or chat. See [environment separation](ENVIRONMENT.md) and Paystack's [API-key guidance](https://paystack.com/docs/developer-tools/api-keys/).

| Setting | Behavior |
| --- | --- |
| `PAYSTACK_SECRET_KEY` | Required to enable payments; empty/absent disables them. Prefix must match mode. |
| `PAYSTACK_MODE` | Defaults to `test`; accepts `test` or `live`. Live mode rejects Firebase emulators. |
| `PAYSTACK_TEST_PROJECT_ID` | Outside emulators, must equal the explicitly isolated staging `FIREBASE_PROJECT_ID`. Never point this at production balances. |
| `PAYSTACK_CALLBACK_URL` | Optional controlled HTTPS return page. No automatic app deep link or callback settlement is implemented. |
| `PAYSTACK_BASE_URL` | Automated local stub only: HTTP loopback plus demo emulators and test mode. Omit for real Paystack requests. |

Both Firebase Auth and Firestore emulator variables must be present together, using a `demo-` project. For real staging Firebase, remove both emulator variables and use Application Default Credentials. Do not mix test credits with real earnings or payouts.

For webhook acceptance, expose only the web listener's `/payments/paystack/webhook` through a controlled HTTPS ingress/tunnel and configure that URL in the Paystack **test** dashboard. Development web port is 8789; the authenticated API uses 8787. Preserve the request body bytes, allow POST, and do not require a Firebase login at the webhook path. An optional callback page should simply tell the customer to return to the wallet; it must not claim that funds were credited.

## Test and accept

Automated checks require no Paystack account or key:

```sh
(cd server/ehailer_server && dart test)
bash tool/test_emulators.sh
flutter test --no-pub test/presentation/wallet_top_up_test.dart
```

Before release, use an isolated staging account to complete a test checkout with [Paystack's published test details](https://paystack.com/docs/payments/test-payments/). Confirm one credit and ledger entry, repeat status checks, verify dashboard webhook delivery, close/reopen the app during payment, decline/abandon an attempt, and test lost connectivity and duplicate webhook delivery. Opening checkout is only one step; verify the actual stored result.

## Recovery and remaining operations

An active intent is recovered through the owner API after app restart. Same-amount initialization reuses it; conflicting amounts require resolving it first. Initialization uses a short lease, and provider failure cannot undo a credit already committed by a webhook. Failed/abandoned attempts may be replaced; late success still settles its original reference without deleting a newer pending intent.

Unknown merchant references are acknowledged without creating wallets. Invalid signatures are rejected. Transient verification/storage failures return a retryable response. Mismatched payment details or reused transaction IDs require reconciliation and create no credit. See [API.md](API.md) for exact status codes.

Scheduled reconciliation, durable webhook queuing, refund/chargeback ingestion, merchant settlement accounting and operational alerts remain release work. Already credited intents do not reverse themselves when Paystack later reports a refund. Keep provider receipts and financial ledger evidence under an explicit retention policy. Store neither card details nor raw provider/webhook payloads. The delivery-dispute wallet adjustment is not a Paystack refund.
