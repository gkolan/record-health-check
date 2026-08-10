# Repository operating checks

These checks apply to every AI coding agent and automated contributor working in this repository.

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

- Always inventory and reuse a suitable existing project scratch org before considering creation.
  Do not create a scratch org merely for convenience, a new alias, or because an automated workflow
  defaults to creation. An explicit need exists only when no compatible existing org is available or
  when reusing one would invalidate a required clean-install, upgrade, namespace, or isolation gate.
- Create a scratch org only after documenting that explicit need. Before creation, run the Dev Hub
  capacity guard; creation must stop when either `ActiveScratchOrgs` or `DailyScratchOrgs` lacks the
  required capacity. Never reuse an org for a gate that explicitly requires a clean org unless its
  recorded state proves that the attempted operation did not install or otherwise contaminate it.
- Use unique, purpose-specific aliases and request the maximum 30-day lifetime. Long lifetimes make
  orgs useful for review; ownership tracking and explicit cleanup protect active-org capacity.
- A workflow must delete every scratch org it creates, including on failure or cancellation. Never
  delete an org merely because its alias matches; track ownership within the creating workflow.
- Prove both supported source shapes before release: a namespaced `rhc` org and a no-namespace
  subscriber-style org. Do not treat one shape as evidence for the other.
- Capture org ID, alias, username, namespace shape, expiration, deployment/test IDs, and outcomes as
  redacted evidence. Do not capture passwords or tokens.

## RHC org roles and development topology

- The Git repository is the authoritative source for the entire Record Health Check project. An org
  must never become the only location of a metadata or code change.
- Use the persistent Dev Hub org at `https://devhubrhc-dev-ed.my.salesforce.com/` as the primary RHC
  development and integration org. Reconcile every intentional org change back into the repository
  before continuing development or creating a package version.
- The namespace-registry org is
  `https://recordhealthcheck-dev-ed.develop.my.salesforce.com/`. Its role is to retain ownership of
  the registered `rhc` namespace and its Namespace Registry relationship with the Dev Hub. Do not
  use this org for ordinary development, source deployment, package installation, test data, or
  release validation.
- Create occasional namespaced scratch orgs from the RHC Dev Hub when isolated `rhc` namespace
  compilation or behavior must be proven. The Dev Hub creates and owns these scratch orgs by using
  the linked namespace; scratch orgs are not created in or owned by the namespace-registry org.
- Continue to use clean no-namespace scratch orgs for subscriber-style source and package-install
  verification. Namespaced and no-namespace evidence are separate release gates.
- Keep the namespace-registry org authenticated only for namespace administration or recovery. Do
  not make routine workflows depend on interactive access to it.

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
- Treat one package-version create per Dev Hub limit window as the default hard ceiling. An
  additional attempt requires an explicit reviewed exception and evidence that the root cause is
  fixed; never spend candidates on speculative packaging changes.
- Never create a package version per commit or in ordinary pull-request CI. Package creation is the
  final release-candidate step after the release branch is committed, source gates pass, and both
  org shapes are proven. Run the explicit release preflight, then create one candidate with
  `--release-ready`; verify that candidate before merge and promotion.
- Retain redacted JSON evidence for create, install, upgrade, test, coverage, promote, and deployment
  operations. A successful command without retained evidence is not a completed release gate.
- Validate the locally converted package artifact before candidate creation, then use installation
  into a clean subscriber org as the authoritative server-artifact gate. Package ZIP retrieval is
  optional diagnostic evidence and must not block installation when Salesforce marks a generated
  ZIP as unretrievable.
