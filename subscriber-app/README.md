# Subscriber verification metadata

> [!NOTE]
> On this page, understand why `subscriber-app` exists, what the demo setup deploys from it, and why
> it must remain outside the Record Health Check package.

This directory verifies Record Health Check from the same side of the package boundary as a
customer org. The demo setup installs the promoted namespaced package first, then deploys this
subscriber-owned metadata and runs `RHCSubscriberSmokeTest`.

## What belongs here

| Content                        | Purpose                                                                                                       |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| `RHCSubscriberSmokeTest`       | Calls installed package behavior from subscriber-owned Apex and verifies the supported boundary               |
| `RHCSubscriberTestDataFactory` | Creates only the records required by the subscriber smoke test                                                |
| `RHCSubscriberPlugin`          | Proves a subscriber-owned global Apex plugin resolves from installed namespaced package code                  |
| `Subscriber_Smoke_Extension`   | Proves subscriber-owned Custom Metadata can coexist with package-owned Example records and survive an upgrade |

## Subscriber plugin outcome matrix

The single `Subscriber_Unmanaged_Apex` Check is data-driven so the installed-package test covers
ordinary and non-success outcomes without introducing invalid metadata:

| Account name                                            | Expected status      | Expected reason                      |
| ------------------------------------------------------- | -------------------- | ------------------------------------ |
| `Subscriber Plugin Compatibility Healthy`               | `PASS`               | `SUBSCRIBER_PLUGIN_PASS`             |
| `Subscriber Plugin Compatibility [FAIL] Needs Review`   | `FAIL`               | `SUBSCRIBER_PLUGIN_NEEDS_REVIEW`     |
| `Subscriber Plugin Compatibility [SKIP] Not Applicable` | `SKIPPED`            | `SUBSCRIBER_PLUGIN_NOT_APPLICABLE`   |
| `Subscriber Plugin Compatibility [UNABLE] Missing Data` | `UNABLE_TO_EVALUATE` | `SUBSCRIBER_PLUGIN_DATA_UNAVAILABLE` |

`RHCSubscriberPluginCompatibilityTest.subscriberPluginPreservesControlledOutcomeMatrix` creates these records,
calls the installed package through its public Apex Check Set API, asserts every exact result, and
proves that validation plus execution construct the subscriber class once and evaluate the complete
scope once. The existing healthy smoke method retains `SUBSCRIBER_PLUGIN_PASS` as its evaluate-entry
marker.

For manual review, create the four named Accounts, put a Record Health Check card configured with
`Subscriber_Smoke_Extension` on the Account page, and compare every result with the table. Record
the installed `04t`, RHC version, source commit, org namespace, test run ID, and actual reasons.

This directory is not package source, not production customer metadata, and not the broad
maintainer integration-test suite. Keep it outside every package directory and deploy it only after
the promoted or candidate package is installed.

## Where it is used

- `npm run setup` deploys it while creating the prepared subscriber demo org.
- `npm run package:verify` uses it for clean-install and upgrade evidence.
- Release workflows use it to prove the `rhc` namespace boundary from subscriber-owned Apex.

## Related

- [Create the demo scratch org](../docs/install/install-demo-in-a-scratch-org.md)
- [Package testing and upgrades](../docs/quality-gates/package-testing-and-upgrades.md)
- [Integration tests](../packages/record-health-check/integration-tests/README.md)
- [Configuration identity](../docs/reference/configuration/names-and-api-identities.md)
