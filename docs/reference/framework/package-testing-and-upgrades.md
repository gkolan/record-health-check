# Package testing and upgrades

> [!NOTE]
> This page separates the steps an administrator follows to upgrade an installed package from the
> release checks that package contributors must complete.

Record Health Check is delivered as a namespaced second-generation unlocked package. An
administrator installs a promoted package version in a sandbox and then upgrades the existing
installation. Package contributors use source deployments only while developing and testing the
package.

## For Salesforce administrators

If you only install and operate the package, follow this section and then return to
[Revalidate or upgrade](../../installation/upgrading.md). The contributor sections below do not
apply to a subscriber org.

### Use a package version, not a source deployment

| Use this approach | Do not use this approach |
| --- | --- |
| Install the promoted package version whose ID begins with `04t` | Clone the repository and deploy package source into a production org |
| Test the upgrade in a sandbox first | Edit installed Apex classes or package test utilities |
| Create your own Check Sets and Checks in Setup | Rename or repurpose installed example metadata as your business configuration |
| Keep org-specific Apex and tests in your team's repository | Add org-specific code to the Record Health Check package source |

Custom Metadata records created by an administrator in your org belong to your team. The release
process tests that those records remain after an upgrade. The four `Example_` Check Sets included
with the package remain package content and can change in a later package version.

### Before an upgrade

1. Read the release notes and identify configuration or permission changes.
2. Confirm the current package version in **Setup → Installed Packages**.
3. Back up Check Sets and Checks created by your team by following
   [Back up configuration](../../guides/back-up-configuration.md).
4. Install the new promoted version in a sandbox that represents production.
5. Reassign or verify the installed Permission Sets.
6. Run the checks and automation used in everyday workflows.
7. Confirm that your team's Check Sets, Checks, Apex classes, Flows, and saved result records still
   behave as expected.

Follow [Revalidate or upgrade](../../installation/upgrading.md) for the complete administrator
procedure and current installation link.

### CLI upgrade example

The normal administrator path is **Setup → Installed Packages** and the approved upgrade link.
Use this optional command only if your team already manages package installations with Salesforce
CLI.

Administrators who use Salesforce CLI can install the new promoted version over the existing one:

```bash
sf package install \
  --package 04tNEW_VERSION_ID \
  --target-org customer-sandbox \
  --upgrade-type DeprecateOnly \
  --wait 30 \
  --publish-wait 10 \
  --no-prompt
```

Replace `04tNEW_VERSION_ID` with the promoted package version ID recorded as `stable` in
[`config/package-releases.json`](../../../config/package-releases.json). Replace `customer-sandbox`
with the alias for your sandbox.

This repository uses `DeprecateOnly` as its reviewed default so an upgrade does not delete package
components merely because they are absent from the newer version. Do not change the upgrade type
without reviewing Salesforce's behavior and your rollback plan.

## Which tests run where?

| Tests | Location | Who runs them? | Purpose |
| --- | --- | --- | --- |
| Package unit tests | Test classes inside `packages/record-health-check/force-app` | Package maintainers during source validation and package-version creation | Verify the Apex and Lightning package code |
| Package integration tests | `packages/record-health-check/integration-tests` | Package maintainers in release scratch orgs | Verify installed examples, access, events, and end-to-end behavior |
| Org-specific tests | Your team's Salesforce repository | Your team in its normal deployment pipeline | Verify Check Sets, custom Apex Checks, Flows, and other business automation created for your org |

An ordinary `RunLocalTests` deployment in an org with the namespaced package installed does not run
the package's namespaced test classes. `RunAllTestsInOrg` or explicitly selected test classes can run
them. Your own tests must not depend on or modify `RecordHealthCheckTestDataFactory`; that class is a
package test utility, not a public extension point.

## For package contributors

### Why two Salesforce org shapes are tested

The source must compile and work in both forms:

| Test org | What it proves |
| --- | --- |
| Namespaced `rhc` scratch org | Package source compiles when Salesforce applies the package namespace |
| No-namespace scratch org | The same source remains portable for the repository's no-namespace verification gate |

Never build a Qualified API Name by adding `rhc__`. Tests query Salesforce for
`QualifiedApiName`, and Apex uses schema describe results when an object or field name can differ by
org shape.

Run the documented source-development commands in
[Source development](../../contributing/source-development.md). The repository checks also reject
hard-coded `rhc__` strings in package Apex where the code should discover the name.

### Required release checks

For each proposed version, maintainers must:

1. Run the repository release preflight on the exact committed source.
2. Prove the source in a namespaced scratch org.
3. Prove the source in a clean no-namespace scratch org.
4. Confirm Dev Hub scratch-org and package-version capacity.
5. Create one package candidate with code coverage enabled.
6. Retrieve the package artifact and confirm that every Custom Metadata member has a physical file.
7. Install the candidate in a clean org and run the installation smoke tests.
8. Install the previous promoted version in a separate clean org, create representative
   customer-owned Check Sets and Checks, and upgrade that org to the candidate.
9. Confirm that the customer-owned Custom Metadata remains intact and rerun the smoke tests.
10. Promote the candidate only after all checks pass.
11. Move the former stable version to `previous`, record the new promoted `04t` and installation
    links in `config/package-releases.json`, update `CHANGELOG.md`, and create the matching release
    tag.

These are separate checks. A successful clean installation does not prove that an upgrade preserves
an administrator's Custom Metadata, and a successful source deployment does not prove that the
package artifact contains every intended file.

See [Releasing](../../../.github/RELEASING.md) for commands, required evidence, and scratch-org
cleanup rules.

## Related

- [Install and verify](../../installation/install-and-verify.md)
- [Revalidate or upgrade](../../installation/upgrading.md)
- [Source development](../../contributing/source-development.md)
- [Configuration identity](configuration-identity.md)
- [Contributing](../../../.github/CONTRIBUTING.md)
