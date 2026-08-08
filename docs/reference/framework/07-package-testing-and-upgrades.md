# Reference: Package testing and upgrades

> [!NOTE]
> On this page, learn which tests belong to the package, how packaged tests behave for subscribers,
> and how versioned unlocked-package upgrades differ from contributor source deploys.

Record Health Check ships as a **namespaced 2GP unlocked package** (`rhc`). Subscribers install
promoted package versions and upgrade in place. Contributors deploy source for development and CI.
This reference explains the design of those two paths so you do not mix them.

## Subscriber policy

> **Package-installed Record Health Check components, including test classes and test utilities,
> must not be modified by subscribers.** Subscriber-specific tests and test-data customization belong
> outside the package. Source deployment is supported for contributors and development environments,
> not as the normal upgrade mechanism.

| Do | Do not |
| --- | --- |
| Install promoted `04t` package versions | Clone source and redeploy for every release |
| Upgrade `2.0` → `2.1` → `2.2` in the same org | Edit `RecordHealthCheckTestDataFactory` or other packaged Apex |
| Author Custom Metadata Check Sets and Checks in Setup | Fork packaged classes in the subscriber org |
| Write your own Apex plugins and tests in your repo | Expect `RunLocalTests` to execute packaged RHC tests |

Treat any change to installed package Apex as an unsupported fork. Package upgrades overwrite
packaged metadata.

## Three test layers

| Layer | Location | Runs when | Subscriber edits? |
| --- | --- | --- | --- |
| Package unit tests | `packages/record-health-check/force-app` test classes | Package-version create (`--code-coverage`) and contributor source deploy with `RunLocalTests` | Never |
| Package integration tests | `packages/record-health-check/integration-tests/` | Release gate and maintainer scratch orgs only | Never |
| Customer tests | Subscriber repository | Customer CI and deploy pipelines | Yes |

Package unit tests:

- Exercise Framework classes in isolation.
- Create deterministic data through `RecordHealthCheckTestDataFactory`.
- Use schema tokens and queried `QualifiedApiName` values instead of hardcoded namespace prefixes.
- Must pass before a package version is promoted.

Integration tests:

- Cover sample metadata, demo configuration, persona access, platform events, and upgrade scenarios.
- Stay outside the root `sfdx-project.json` `packageDirectories` so they never ship to subscribers.

Customer tests:

- Cover org-specific Checks, Apex plugins, Validation Rules, and business automation.
- Live in the customer repository, not inside the Record Health Check package.

## How RunLocalTests behaves with installed packages

Normal subscriber deployments that use `RunLocalTests` **do not execute** Apex tests originating
from an installed **namespaced** unlocked package. Those tests run only when explicitly selected or
when the org uses `RunAllTestsInOrg`.

Maintainers run packaged tests during `sf package version create --code-coverage`. Salesforce
stores the resulting coverage on the package version before it can be promoted.

Subscriber sandboxes that install only the unlocked package are therefore not blocked by Framework
package tests during their own metadata deployments.

Contributor source deploys into scratch orgs **do** run local Framework tests because the classes
are org-owned until packaged. That path is for development, not the supported subscriber install.

## Namespace-neutral test utilities

`RecordHealthCheckSchemaTestDataFactory` resolves org-specific API names at runtime;
record construction stays on `RecordHealthCheckTestDataFactory`:

- Custom Metadata identities: query `QualifiedApiName` (never construct `rhc__` + `DeveloperName`).
- Schema tokens: `Record_Health_Check_Set__mdt.SObjectType.getDescribe().getName()` and field
  `getDescribe().getName()` return the correct qualified or unqualified name for the org.
- Global describe helpers: resolve integration sample objects by local API name suffix when sample
  metadata is deployed.

Hardcoded `rhc__` string literals in package Apex under `packages/record-health-check/force-app`
are prohibited. CI enforces this through `npm run check:test-data-factory`.

Prove both shapes before release:

| Shape | Maintainer command | What it proves |
| --- | --- | --- |
| Namespaced development org | `npm run dev:setup` | Unpackaged source deploys and `RunLocalTests` pass with the `rhc` namespace |
| No-namespace portable org | `npm run dev:test-no-namespace` | The same `force-app` deploys without a namespace |

Both commands accept `--dev-hub` and work on Windows, macOS, and Linux. See
[Source development](../../contributing/source-development.md).

## Optional subscriber test-data extension (future)

Some heavily customized orgs may need extra field values when inserting standard objects during an
**optional** subscriber smoke-test path. Do not edit the packaged factory for that case.

When demand exists, provide an optional external class (for example a customer-owned
`MyCompanyRHCTestDataCustomizer`) that the verification invokes when present. Constraints:

- The customizer lives outside the Record Health Check package.
- Package upgrades must not overwrite it.
- Absence of the class is normal.
- Package-version creation must not depend on it.

The core package unit tests do not use this extension.

## Recommended release process

For every version:

1. Run tests in a namespaced scratch org.
2. Deploy source into a non-namespaced scratch org and run tests.
3. Install the previous released `04t` into a validation org with representative subscriber metadata.
4. Upgrade that org to the new `04t`.
5. Verify subscriber-owned Custom Metadata remains intact.
6. Create the package version with `--code-coverage`.
7. Promote only after clean install, upgrade, and smoke tests pass.

Record promoted install URLs and the `04t` ID in `config/package-releases.json`, then update
`CHANGELOG.md`. See [Releasing](../../../.github/RELEASING.md).

## Subscriber upgrade command

Install the newer promoted version over the existing package:

```bash
sf package install \
  --package 04tNEW_VERSION_ID \
  --target-org customer-sandbox \
  --upgrade-type DeprecateOnly \
  --wait 30 \
  --publish-wait 10
```

`DeprecateOnly` is the conservative default while the project is young: it does not aggressively
delete components removed from newer versions. Salesforce also supports `Mixed` (CLI default) and
`Delete`; choose explicitly when your rollback plan requires it.

## Related

- [Install and verify](../../installation/02-install-and-verify.md)
- [Revalidate or upgrade](../../installation/04-upgrading.md)
- [Source development](../../contributing/source-development.md)
- [Configuration identity](06-configuration-identity.md)
- [Contributing](../../../.github/CONTRIBUTING.md)
