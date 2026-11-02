# e-Hailer documentation

e-Hailer supports customer bookings, courier delivery work and staff operations. Its trusted Serverpod API controls delivery and money changes while Firebase supplies authentication and realtime reads. Start with the guide that matches your task.

## Understand and use the app

| Document | Read it for |
| --- | --- |
| [Repository overview](../README.md) | What the app does, screenshots, roles, setup and contribution expectations. |
| [App guide](APP_GUIDE.md) | Customer, driver, administrator and support workflows; common recovery steps. |
| [Feature status](FEATURES_SPECIFICATION.md) | Implemented capabilities and remaining integrations or operational work. |
| [Validation record](VALIDATION.md) | Tests and build evidence, UI coverage and the limits of local verification. |

## Explore the architecture

**[Open the interactive Archify architecture](architecture.html)** to trace sign-in, authenticated commands, trusted transactions and authorized client reads. It includes source references, light/dark themes and export controls. Download or open the HTML locally; GitHub displays its source rather than executing the viewer.

The **[Paystack funding architecture](payments-architecture.html)** separately shows the browser checkout, Firebase-authenticated commands, signed public webhook and shared settlement transaction.

| Document | Read it for |
| --- | --- |
| [Architecture explanation](ARCHITECTURE.md) | DDD structure, trust boundaries, booking lifecycle, money/retry policy and deliberate constraints. |
| [API contract](API.md) | Commands, caller permissions, request fields, quote inputs and error semantics. |
| [Database and security model](DATABASE_SCHEMA.md) | Collections, read access, atomic writes, legacy migration and retention. |
| [Graphify code map](codebase-map.html) | Structural navigation through handwritten code, tests and documentation. |
| [Graphify instructions](GRAPHIFY.md) | Reproducible refresh, scope, exclusions and why structural edges require source verification. |
| [Reference review](REFERENCE_REVIEW.md) | Patterns considered from the reference repositories and how they apply here. |

Archify explains runtime responsibilities; Graphify indexes symbols and references. Neither diagram establishes production deployment. Archify evidence pins an isolated local snapshot of the changed source; [architecture-evidence.json](architecture-evidence.json) records its provenance.

## Develop and maintain

- [Development guide](DEVELOPER_GUIDE.md): tools, emulator setup, configuration, code generation and validation commands.
- [Local environment](ENVIRONMENT.md): client defines, private server/signing settings and generated native configuration.
- [Security audit](SECURITY_AUDIT.md): findings, remediations, dependency/history scans and release risks.
- [Paystack payments](PAYMENTS.md): hosted funding, verification, isolated test setup and acceptance steps.
- [Deployment preparation](DEPLOYMENT.md): server bundle, environment, ports, HTTPS ingress and release requirements.
- [Dependencies](DEPENDENCIES.md): selected package versions and upstream constraints.
- [Improvement worklog](IMPROVEMENT_WORKLOG.md): baseline, decisions and delivered changes.
- [Contributor instructions](../AGENTS.md): preserved repository conventions, together with the documented Serverpod transport-generation exception.
- [MIT license](../LICENSE) and [third-party notices](../THIRD_PARTY_NOTICES.md).

When a feature changes, update its guide, API/schema contract and tests together. Refresh diagram evidence after reviewing the affected source ranges; refresh Graphify after source or documentation edits. Keep release prerequisites visible rather than marking an integration complete because a screen or button exists.
