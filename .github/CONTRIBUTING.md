# Contributing

Thanks for your interest in improving Record Health Check. This guide explains
how to report a bug, request a feature, and open a pull request. It is written so
that someone new to the project can follow it step by step.

Please read the [Code of Conduct](CODE_OF_CONDUCT.md) before participating. By
contributing, you agree that your contributions are licensed under the
[Apache License, Version 2.0](../LICENSE).

Subscribers should install the promoted unlocked package (see the root README install link and
[Install and verify](../docs/installation/02-install-and-verify.md)). Contributors deploy unpackaged
Framework source for development; do not point new users at GitHub source deploy as the primary install
path.

Contributors changing Framework source use
[Source development](../docs/contributing/source-development.md) (`npm run dev:setup`), not the
subscriber install path.

## Ways to contribute

| I want to…                  | Do this                                                                                                                         |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **Report a bug**            | Open a [Bug report](https://github.com/gkolan/record-health-check/issues/new?template=bug_report.yml) issue                     |
| **Request a feature**       | Open a [Feature request](https://github.com/gkolan/record-health-check/issues/new?template=feature_request.yml) issue           |
| **Ask a question**          | Start a [GitHub Discussion](https://github.com/gkolan/record-health-check/discussions) (or open an issue if Discussions is off) |
| **Report a security issue** | Report privately through the [Security policy](SECURITY.md) rather than a public issue                                          |
| **Fix code or docs**        | Open a pull request (see below)                                                                                                 |

## Reporting a bug: step by step

1. **Search first.** Check [existing issues](https://github.com/gkolan/record-health-check/issues)
   so you do not file a duplicate.
2. Go to **Issues → New issue → Bug report**.
3. Fill in every field. The most useful reports include:
   - The expected behavior, actual behavior, and exact steps to reproduce it.
   - The **Check Set Qualified API Name** and **Rule Developer Name** involved (not screenshots of labels only).
   - The object and a sketch of the field/query values that triggered it.
   - A redacted screenshot or screen recording when the problem appears on the card.
   - The redacted `[RHC]` console report after reproducing with **Show Diagnostics** enabled. If diagnostics cannot be enabled or do not apply, explain why (see [Troubleshoot with Show Diagnostics](../docs/guides/07-troubleshoot-with-show-diagnostics.md)).
   - Package version or installed `04t`, installation type, org type, API version, and browser or device when relevant.
4. Submit. A maintainer will triage and may ask for a minimal reproduction.

Omit customer data, record IDs, Salesforce access tokens, session IDs, and full Org IDs from issues.
Redact screenshots and console output before attaching them.

## Opening a pull request: step by step

1. **Fork** the repo and **clone** your fork:
   ```bash
   git clone https://github.com/<your-username>/record-health-check.git
   cd record-health-check
   npm ci
   ```
2. **Create a focused branch** (one change per branch):
   ```bash
   git checkout -b fix/short-description
   ```
3. **Make your change.** Keep it small and include tests for every behavior change.
4. **Run the local gates** before you push (all must pass):
   ```bash
   npm run prettier:verify
   npm run lint
   npm test                    # LWC Jest unit tests
   npm run test:unit:coverage  # enforces LWC coverage thresholds
   ```
   These `npm` commands work the same on Windows, macOS, and Linux. Pass Dev Hub aliases with
   `--dev-hub` rather than a `VAR=value` prefix. On Windows, use PowerShell, cmd, or Git Bash; do
   not call the Windows `sf` CLI from WSL bash. See
   [Source development](../docs/contributing/source-development.md#windows-and-shell-notes).
5. **Commit and push** to your fork:
   ```bash
   git commit -m "Fix: short description of the change"
   git push -u origin fix/short-description
   ```
6. **Open the PR** against `main`. The PR template will prompt you for a summary,
   testing notes, and a checklist. Link the issue it closes (e.g. `Closes #12`).
7. CI ([`workflows/ci.yml`](workflows/ci.yml)) runs prettier, lint,
   Jest with coverage, and XML validation on every PR. Keep it green.

A maintainer ([CODEOWNERS](CODEOWNERS) is auto-requested) will review. Address
feedback by pushing more commits to the same branch.

## Quality bar (what reviewers enforce)

- **Tests are required** for every behavior change: both a positive test and a
  misconfiguration/negative test where applicable.
- **Coverage thresholds** are enforced by `coverageThreshold` in
  [`packages/record-health-check/jest.config.js`](../packages/record-health-check/jest.config.js).
  `npm run test:unit:coverage` exits non-zero if they are not met.
- **Apex changes** must also pass the project Apex test suite and a validation
  deployment (`sf project deploy validate`) with `RunLocalTests` in a clean
  scratch org.
- Keep CRUD/FLS enforcement, the 25-Rule run cap, the 5-way Apex
  concurrency cap, debug-detail authorization, and result normalization intact even when
  that makes a test harder to write.
- **New evaluator features** must update runtime validation, deploy-time
  validation, reason-code documentation, and both positive and misconfiguration
  tests. Prefer extending the shared modules over adding another parser or comparison operator copy.

See [`docs/reference/framework/01-architecture.md`](../docs/reference/framework/01-architecture.md)
for the published Framework architecture and to find where things live.

## Configuration identity and package boundary

When changing Demo `Example_` Check Sets/Rules or any public identity boundary:

1. Change the record in `packages/record-health-check/force-app/main/default/customMetadata`.
2. Copy the same record into `packages/record-health-check/integration-tests/main/default/customMetadata` (identical XML).
3. Keep Check Set `CardTitle__c` values prefixed with `Demo:`.
4. Update `packages/record-health-check/manifest/package.xml` CustomMetadata members when members are listed explicitly.
5. Deploy `force-app` alone to a clean org before broader fixture deployment (from `packages/record-health-check/`).
6. Run `npm run check:configuration-identity` and `npm run check:package-boundary`.

Every public input must accept the exact Custom Metadata `QualifiedApiName` Salesforce returns. Do
not guess namespaces or retry alternate name forms. See
[Configuration identity](../docs/reference/framework/06-configuration-identity.md).

## Apex test-only access policy

`@TestVisible` and `Test.isRunningTest()` are temporary workarounds. Do not add test-only access without
updating the architecture baseline. The full policy lives in
[Contributor policy: Apex test-only access](../docs/reference/apex/09-test-only-access.md). Run
`npm run check:apex-architecture` before opening a PR that touches Apex.

## Integration-test sample data

[`packages/record-health-check/integration-tests/`](../packages/record-health-check/integration-tests/) holds CI-only sample metadata and is **not** part of
the Framework install. Keep it out of the root `sfdx-project.json` `packageDirectories`. The release
gate deploys it with an explicit `--source-dir packages/record-health-check/integration-tests` after Core. See
[`packages/record-health-check/integration-tests/README.md`](../packages/record-health-check/integration-tests/README.md).

## Apex test ownership

| Layer                | Location                                                   | Who maintains it          |
| -------------------- | ---------------------------------------------------------- | ------------------------- |
| Package unit tests   | `packages/record-health-check/force-app` `@IsTest` classes | This repository           |
| Integration fixtures | `packages/record-health-check/integration-tests/`          | This repository (CI only) |
| Customer tests       | Subscriber repository                                      | The subscriber            |

Package tests must use `RecordHealthCheckTestDataFactory`, schema tokens, and queried
`QualifiedApiName` values. Do not add hardcoded `rhc__` string literals to package Apex under
`packages/record-health-check/force-app`.
Run `npm run check:test-data-factory` before opening a PR that touches Apex tests.

## Documentation changes

Docs must match the code at the same commit. Follow these authoring standards:

- **Active voice**: name the actor in instructions ("Assign the permission set" not "The permission set should be assigned").
- **Setup names**: in prose and Setup instructions, write **Label** (`API_Name`), for example **Record Health Check User** (`rhc__Record_Health_Check_User`). Keep API-name-only forms in code fences and CLI arguments.
- **No filler**: avoid _simply_, _just_, _easily_, _straightforward_, _it's worth noting_, _as mentioned above_ unless they carry technical meaning (for example "not just presence").
- **Code blocks**: introduce every block with a sentence ending in a colon; use fenced blocks with a language identifier (`bash`, `apex`, `sql`, `json`).
- **No em-dashes**: replace each em-dash by hand with a period, comma, or parentheses, never a blanket swap to a colon.

The public [architecture document](../docs/reference/framework/01-architecture.md) is the
contributor-facing source of truth for Framework architecture and where code and docs live.
Maintainer release steps are in [`RELEASING.md`](RELEASING.md).
