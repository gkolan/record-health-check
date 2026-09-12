# Release 2.0.10.1 record

This reference records the promoted package behavior, verification evidence, and release-owner
decision for Record Health Check 2.0.10.1.

Salesforce confirmed version **2.0.10.1** (`04tak000000h2wDAAQ`) as released on September 12, 2026.
No installation password is required.

- [Production installation](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak000000h2wDAAQ)
- [Sandbox installation](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak000000h2wDAAQ)

## Verification performed

- The exact package creation commit was `a662133ab7a383830c97a5aec86a72e9abc93aaf`.
- Salesforce package validation was not skipped. Package coverage was 97%, and Salesforce's
  coverage check passed.
- The release owner installed and tested the exact candidate in a subscriber org and confirmed that
  it worked correctly before requesting promotion.
- The repository's guarded promotion workflow verified the package identity, version, creation
  evidence, and commit before releasing the candidate.
- All tracked-source CI gates passed for the release-link update in a clean checkout.

## Related

- [2.0.10 public contract](../reference/release-2.0.10.md)
- [Package testing and upgrades](./package-testing-and-upgrades.md)
- [Manual release-owner checklist](./manual-release-owner-checklist.md)
