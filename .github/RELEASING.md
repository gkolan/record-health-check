# Release Record Health Check

Record Health Check ships primarily as the namespaced unlocked package `Record Health Check`.
Source deployment is a development workflow and is not the supported subscriber installation path.

## Version model

The Framework follows Semantic Versioning. `package.json` carries the Framework version and
`sfdx-project.json` carries the Salesforce package version as `MAJOR.MINOR.PATCH.NEXT`.
Each package build uses `MAJOR.MINOR.PATCH.BUILD`; later build numbers are immutable candidates for
the same semantic release.

## Required evidence

Before creating a release candidate:

1. Run every local gate, including docs, query shapes, permissions, formatting, lint, and Jest.
2. Run Code Analyzer and resolve every unsuppressed release finding.
3. Deploy the production manifest into a clean scratch org and run all local Apex tests.
4. Run the query-verdict parity comparison and the checked-in scope measurement harness.
5. Create the package version without example Custom Metadata records.
6. Install it into a clean subscriber org, assign the admin permission set, and smoke-test Apex,
   Flow, LWC, permissions, and lifecycle events.
7. Upgrade an org containing the previous released package and repeat the smoke tests.

Never discard deploy, test, package, or install output. Archive JSON results with the release.

## Create a package candidate

```bash
sf package version create \
  --package "Record Health Check" \
  --installation-key-bypass \
  --code-coverage \
  --wait 120 \
  --target-dev-hub gkSfdcDevHub
```

Record the resulting `04t` ID and add its alias to `sfdx-project.json`. Do not promote it until the
clean-install and upgrade gates pass.

## Promote and publish

```bash
sf package version promote \
  --package "Record Health Check@2.0.0-1" \
  --target-dev-hub gkSfdcDevHub
```

Then update `CHANGELOG.md`, commit the exact source used to create the package, create the matching
semantic-version tag, and create the GitHub release. Publish the promoted subscriber package ID in
the install guide and release notes.

## Samples

Example Check Sets and Rules are optional learning assets, not Core defaults. Deliver them through
the documented sample installer or source package after Core is installed. Never make a Core
package candidate depend on example records being packaged.

## Rollback

Salesforce package versions are immutable. Roll forward with a corrected package version when a
schema or installed metadata change cannot be safely reversed. For an application-only regression,
install the previously supported version only when Salesforce package ancestry and upgrade rules
permit it. Document data or configuration remediation separately.
