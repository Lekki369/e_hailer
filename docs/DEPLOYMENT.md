# Server deployment preparation

This repository provides a production-mode configuration and a native Dart bundle path. No hosting provider, domain, production credentials or deployment has been selected or provisioned. Follow the payment test-mode acceptance steps before enabling real funding.

## Build a server bundle

Use the locked server dependencies and Dart 3.13.7, matching the verified local toolchain. Build on the target operating system and architecture:

```sh
cd server/ehailer_server
dart pub get --enforce-lockfile
dart analyze
dart build cli --target=bin/main.dart --output=../../.cache/server-release
```

Keep the resulting `bundle/bin/main` and `bundle/lib/` together. Copy the repository's `server/ehailer_server/config/` directory alongside the bundle, excluding `passwords.yaml` if one exists. Start from the directory containing `config/`:

```sh
./bundle/bin/main --mode=production
```

The [Dart CLI bundle](https://dart.dev/tools/dart-build) includes dependency code assets. A macOS build is not a Linux deployment artifact; build again in the target environment. Keep the runtime's trusted CA certificates and outbound HTTPS access. No container image has been built or validated here.

## Environment and identity

Use `server/ehailer_server/.env.example` as a setting reference. The local `tool/server_env.py` launcher loads the ignored server env; production environment injection belongs to the process supervisor or hosting secret manager. Plain Dart does not load `.env` automatically. Do not bake credentials into a bundle, image or Flutter app. Client builds use the separate allowlisted wrapper described in [ENVIRONMENT.md](ENVIRONMENT.md).

For a staging test deployment, set `FIREBASE_PROJECT_ID` to a dedicated staging project, `PAYSTACK_TEST_PROJECT_ID` to that same project, `PAYSTACK_MODE=test`, and the test secret. Remove both emulator variables. Use a workload/service identity with the required Firestore and Firebase Authentication permissions through Application Default Credentials. Verify token revocation checks with that identity.

Set `SERVERPOD_API_SERVER_PUBLIC_HOST` and `SERVERPOD_WEB_SERVER_PUBLIC_HOST` to the actual API and webhook domains. Production YAML declares public HTTPS port 443 while the internal listeners remain HTTP. Serverpod's [configuration precedence](https://docs.serverpod.dev/concepts/experimental/) lets environment variables override these YAML values. No PostgreSQL or Redis service is required by this implementation.

## Ingress and process checks

| Listener | Internal port | Public routing |
| --- | --- | --- |
| Authenticated Serverpod RPC | 8787 | API HTTPS domain; Flutter `E_HAILER_API_URL` points here. Preserve Authorization headers. |
| Web routes | 8789 | Webhook HTTPS domain; forward exact `POST /payments/paystack/webhook` body and signature header. |
| Insights | 8788 | Keep private; do not expose through internet ingress. |

`GET /healthz` on the web listener returns process liveness only. It does not verify Firebase credentials, Paystack availability, successful settlement or ingress correctness. Monitor the process separately from provider and datastore health. Configure bounded body sizes, connection deadlines and abuse/rate limits; preserve Paystack's retry behavior rather than turning failed verification into a false 200 acknowledgment.

Run under a supervised unprivileged account with restart policy and graceful termination. Keep sensitive request headers, webhook bodies, PINs and banking payloads out of ingress logs. The application disables console session logging and emits only a generic reconciliation warning for payment conflicts.

## Release sequence

1. Complete local tests, a target-platform bundle build and isolated staging smoke checks.
2. Back up and reconcile any existing data; migrate legacy PIN/tracking fields as described in [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md).
3. Configure real domains, TLS, Firebase credentials/rules/indexes, routing capacity and a separately controlled Paystack test webhook.
4. Complete customer/driver flows and the payment acceptance checklist on web and physical devices. Verify the database and merchant dashboard evidence.
5. Establish reconciliation, refunds/chargebacks, retention, monitoring and rollback responsibilities before switching to a separately configured live environment.

Do not roll back to a client that writes wallet balances or public PINs. If payment processing must stop, remove/disable the provider configuration and show service-unavailable feedback while preserving intents and receipts for reconciliation. Payout transfers are still manually confirmed outside the app. See [VALIDATION.md](VALIDATION.md) for completed checks and their limits.
