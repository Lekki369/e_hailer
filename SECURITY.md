# Security policy

This public repository contains templates and source code, not private credentials. Local environment files, Firebase platform configuration, service-account files, signing keys, builds and audit logs must remain outside Git.

- Put public Flutter configuration in an ignored `.env` and build through `python3 tool/flutter_env.py`. Values compiled into a mobile or web app are extractable.
- Keep Paystack secrets and server credential paths in `server/ehailer_server/.env` or the server's secret manager. Never pass that file to Flutter.
- Keep Android signing values in `android/.env`; the build wrapper supplies them only to Gradle. iOS signing remains in the local Xcode/keychain setup.
- Run `python3 tool/check_secrets.py` before staging and enable the local hook with `git config --local core.hooksPath .githooks`. GitHub security checks also scan the tracked snapshot and history.
- Never log PINs, authorization headers, provider payloads, card data or full banking details. Confirm financial effects through the trusted backend.

See [configuration instructions](docs/ENVIRONMENT.md), the [security audit](docs/SECURITY_AUDIT.md) and [release prerequisites](docs/DEPLOYMENT.md).

Report suspected vulnerabilities privately to the maintainer. Use GitHub's private vulnerability reporting if it is enabled; do not open a public issue containing secrets, personal data or an exploit against a live account. Include the affected revision, reproduction using synthetic data, impact and proposed mitigation. This repository does not promise a response SLA or certify a production deployment.

If an actual private credential reaches GitHub, revoke/rotate it first. Removing it from the latest source does not remove it from Git history, forks, caches or downloaded builds. Coordinate any history rewrite separately; do not silently rewrite shared history.
