# Repository operating rules

These rules apply to every AI coding agent and automated contributor working in this repository.

## Salesforce toolchain

- Use `sf` CLI commands only. Do not introduce legacy `sfdx` commands.
- Salesforce CLI 2.146.3 is the pinned, verified release. Run `npm run check:toolchain` before any
  Salesforce mutation. Update `config/toolchain.json`, CI pins, this file, and the operations record
  together when adopting a newer official `latest` release.
- Run `npm run check:toolchain-latest` before release work or any long-lived Salesforce operation;
  stop and update the reviewed pin when the official npm `latest` release has advanced.
- Do not silently install an unpinned `latest` CLI in CI. Reproducible builds require an exact
  version; upgrading is a reviewed repository change.
- Never print, commit, copy into the repository, or archive access tokens, refresh tokens, SFDX auth
  URLs, client secrets, or passwords.

## Scratch-org lifecycle

- Before creating an org, run the Dev Hub capacity guard. Creation must stop when either
  `ActiveScratchOrgs` or `DailyScratchOrgs` lacks the required capacity.
- Reuse a suitable project org when doing so cannot invalidate clean-install, upgrade, namespace, or
  isolation evidence. Never reuse an org for a gate that explicitly requires a clean org.
- Use unique, purpose-specific aliases and request the maximum 30-day lifetime. Long lifetimes make
  orgs useful for review; ownership tracking and explicit cleanup protect active-org capacity.
- A workflow must delete every scratch org it creates, including on failure or cancellation. Never
  delete an org merely because its alias matches; track ownership within the creating workflow.
- Prove both supported source shapes before release: a namespaced `rhc` org and a no-namespace
  subscriber-style org. Do not treat one shape as evidence for the other.
- Capture org ID, alias, username, namespace shape, expiration, deployment/test IDs, and outcomes as
  redacted evidence. Do not capture passwords or tokens.

## Package release management

- `config/package-releases.json` is the only source of truth for stable and previous subscriber
  package versions and install URLs.
- Package versions are immutable candidates. Create, verify clean install, verify N-1 upgrade,
  verify subscriber-owned Custom Metadata preservation, run both org-shape gates, capture coverage,
  and only then promote.
- Never point `stable` at an unpromoted `04t`. Move the old stable entry to `previous`, update install
  URLs, commit the exact package source, and create the matching semantic-version tag and release.
- Check `Package2VersionCreates` before creating a candidate. Do not consume package-version or
  scratch-org capacity for documentation-only or local UI-only changes.
- Never create a package version per commit or in ordinary pull-request CI. Package creation is the
  final release-candidate step after the release branch is committed, source gates pass, and both
  org shapes are proven. Run the explicit release preflight, then create one candidate with
  `--release-ready`; verify that candidate before merge and promotion.
- Retain redacted JSON evidence for create, install, upgrade, test, coverage, promote, and deployment
  operations. A successful command without retained evidence is not a completed release gate.
