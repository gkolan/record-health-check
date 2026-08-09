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
| `Subscriber_Smoke_Extension`   | Proves subscriber-owned Custom Metadata can coexist with package-owned Example records and survive an upgrade |

This directory is not package source, not production customer metadata, and not the broad
maintainer integration-test suite. Keep it outside every package directory and deploy it only after
the promoted or candidate package is installed.

## Where it is used

- `npm run setup` deploys it while creating the prepared subscriber demo org.
- `npm run package:verify` uses it for clean-install and upgrade evidence.
- Release workflows use it to prove the `rhc` namespace boundary from subscriber-owned Apex.

## Related

- [Create the demo scratch org](../docs/installation/create-rhc-scratch-org.md)
- [Package testing and upgrades](../docs/reference/framework/package-testing-and-upgrades.md)
- [Integration tests](../packages/record-health-check/integration-tests/README.md)
- [Configuration identity](../docs/reference/framework/configuration-identity.md)
