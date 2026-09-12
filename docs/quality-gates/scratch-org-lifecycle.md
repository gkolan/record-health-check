# Scratch org lifecycle and release plan

Use this page as the authority for creating, reusing, verifying, and deleting Record Health Check
scratch orgs. Read it before creating an org locally or changing an org-consuming workflow.

Record Health Check is released as a second-generation unlocked package with the `rhc` namespace.
An ordinary subscriber org usually has no namespace of its own, but an installed Record Health
Check package still uses `rhc`. A no-namespace deployment of unpackaged source is therefore a
contributor portability check, not another package shape.

## Rules that apply to every scratch org

1. Check the Dev Hub's `ActiveScratchOrgs` and `DailyScratchOrgs` limits before creating anything.
2. Reuse an existing project org when its purpose, source revision, package version, and Lightning
   security mode match the work. Do not create an org merely because a new agent or terminal is
   doing the work.
3. Give every local org an alias containing its purpose and owner, such as
   `rhc-dev-gautam-20260907`. CI uses the fixed aliases declared in its workflow.
4. Local development and demonstration orgs live for at most seven days. Release and one-time
   compatibility orgs live for one day.
5. Record the alias, creator, purpose, source commit or `04t`, security mode, creation date, expiry,
   and whether the org must be kept before sharing it with another person or agent.
6. Delete a disposable org as soon as its evidence has been saved. The creator owns cleanup even
   when another person or agent uses the org later.
7. Never delete an unfamiliar org based only on its age or generated username. Confirm its owner
   and purpose first. If ownership cannot be established, a Dev Hub administrator decides whether
   it can be removed.
8. Deleting an active org returns an active slot. It does not return that day's scratch-org
   creation allowance.

## The approved org set

| Org use                         | Salesforce shape                                                        | Normal lifetime | Cleanup owner                   | Contents                                                                                                                                 |
| ------------------------------- | ----------------------------------------------------------------------- | --------------: | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Namespaced source development   | `rhc`, LWS                                                              |          7 days | Person or agent that created it | Package source, package tests, integration-test Check Sets and Checks, optional deterministic demo data; not part of a release pair      |
| Installed-package demonstration | Subscriber org without its own namespace, LWS                           |          7 days | Person or agent that created it | Exact promoted or candidate `04t`, subscriber-owned test harness, packaged examples, deterministic demo data; not part of a release pair |
| Source Locker check             | `rhc`, Locker                                                           |           1 day | Creating command or workflow    | Package source, required integration fixture, browser tests                                                                              |
| Optional portability check      | No namespace, normally LWS                                              |           1 day | Creating command or workflow    | Unpackaged source and focused tests only                                                                                                 |
| Hosted candidate release pair   | Two subscriber orgs without their own namespace: one LWS and one Locker |   Up to 30 days | Release owner                   | Clean-install evidence, reset, exact stable-to-candidate upgrade, subscriber-owned fixtures, browser and API checks                      |

One reusable source-development org and one installed-package demonstration org are normally enough
for everyday work. A new agent uses the existing aliases when they still match the work. Integration
fixtures belong only in source-development and hosted source-validation orgs; they are not package
content and must not be deployed to a customer-style installed-package org.

## How a person or agent verifies current source

Use a namespaced source org when reviewing code, documentation examples, and integration fixtures.

```bash
npm run dev:setup -- --dev-hub my-dev-hub --alias rhc-dev-owner-date
npm run dev:test -- --alias rhc-dev-owner-date
npm run demo:setup-source -- --alias rhc-dev-owner-date
npm run demo:verify-source -- --alias rhc-dev-owner-date
```

The setup deploys package source and the integration-test metadata. `dev:test` then runs the package
and integration Apex tests together after those fixtures exist. The deterministic demo setup
then creates the Accounts, Contacts, Opportunities, Cases, Tasks, Product, Opportunity Product, and
inactive owner required by the four example Check Sets. The verifier runs every active example
against its expected result. Every active packaged Check must have an expected passing record and
an expected needs-review record. Checks with a meaningful not-applicable or no-data path must also
have the corresponding skipped or unable-to-check record.

Each packaged Check Set must also have one record with no failed Checks and one record with at
least one failed Check. A skipped Check is reported separately and never counted as a pass.

The `check:demo-outcome-coverage` source
gate rejects an incomplete matrix before an org is created, and the org verifier proves that the
declared outcomes are the outcomes Salesforce returns. A reviewer can then open the prepared list
views and exercise the
record-page card by following [Create a demo scratch org](../install/install-demo-in-a-scratch-org.md).
The complete reusable standard is [Check and Check Set outcome verification](./check-outcome-verification.md).

Before reusing this org after a code change, deploy the current checkout, rerun the relevant Apex
tests, and rerun both demo commands. Do not rely on results produced by an older commit.

## How a person or agent verifies an installed package

Source deployment does not prove the package artifact. After a candidate `04t` exists, create a
customer-style subscriber org and install that exact ID:

```bash
npm run package:verify -- \
  --package 04tCANDIDATE \
  --dev-hub my-dev-hub \
  --alias rhc-candidate-owner-date \
  --security-mode LWS \
  --skip-upgrade \
  --keep-org
```

Omit `--keep-org` for an automated run. Without that flag, the verifier deletes every org it
created on normal exit and on interrupt. With the flag, the creator must delete the org after human
review. The verifier installs the namespaced package into an org without a namespace of its own,
deploys only subscriber-owned fixtures, seeds the deterministic demo unless explicitly disabled,
and verifies the package, APIs, permissions, examples, and browser behavior.

Do not deploy `packages/record-health-check/integration-tests` into this org. Those fixtures test
the repository source boundary; packaged examples and `subscriber-app` test the installed package
boundary.

## Lightning Web Security and Lightning Locker

Source validation can use two clean `rhc` orgs during contributor work:

| Org                          | What it proves                                                                                               |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Namespaced LWS source org    | Production package source, Apex, integration fixtures, APIs, demo Check Sets, and browser behavior under LWS |
| Namespaced Locker source org | The record-page browser behavior remains compatible with Lightning Locker                                    |

LWS versus Locker is an org setting. Although the setting can be changed, release evidence uses a
fresh org for each mode so metadata, sessions, browser state, and cached Lightning resources cannot
leak from one run to the other. Both orgs use the `rhc` namespace. The optional no-namespace source
deployment remains a contributor check and does not block creation of the namespaced 2GP artifact.

Those disposable source orgs are not a release pair and must not be created as an additional release
stage. A release uses only the two ordinary subscriber orgs created by the subscriber release-pair
workflow. The installed package continues to use `rhc` even though those orgs have no namespace of
their own.

## Rolling two-release org window

Every release owns exactly two retained scratch-org slots: one LWS org and one Locker org. The
release-pair workflow uses each org first for a clean candidate installation, removes the subscriber
harness, uninstalls the candidate, installs the exact current stable version, and then upgrades that
same org to the candidate. Clean-install and upgrade evidence therefore do not require separate
orgs.

Keep at most two release pairs, or four retained scratch orgs, at one time:

1. Release `N` creates its LWS and Locker pair, validates the candidate, and retains the pair.
2. Release `N+1` creates a new pair, installs promoted `N` as its upgrade base, upgrades to `N+1`,
   and retains both release pairs.
3. When work starts on `N+2`, delete the `N` pair before authorizing creation of the `N+2` pair.
4. For example, 2.0.9 retains two orgs; 2.0.10 creates two more and verifies the 2.0.9-to-2.0.10
   upgrade; when 2.0.11 work starts, delete both 2.0.9 orgs before creating the 2.0.11 pair.

Scratch orgs expire after at most 30 days. If a retained pair expires before `N+2` begins, record the
expiry and do not recreate it merely to satisfy the retention window. Use sandboxes instead when a
release comparison must remain available longer than 30 days.

The executable values live in `config/release-org-policy.json`. Any exception or replacement still
requires explicit release-owner authorization. Never create a third active org for the same release;
retire the unusable member of the pair first.

## Cleanup and orphan recovery

Every hosted job must put deletion in an `always()` cleanup step. Every release org uses a one-day
expiry as a second line of defense. Those controls cannot cover every failure: a runner can be
cancelled, its authorization can be lost, or Salesforce can create an org after the CLI times out.
Salesforce documents that these orphaned orgs still consume the active allocation.

Before a release, a Dev Hub administrator must open **App Launcher → Active Scratch Orgs** and
review every active org. Use **Scratch Org Infos** to see the request history. Classify each active
org as:

- actively owned development or demonstration work with an agreed deletion date;
- a current release org whose workflow is still running;
- abandoned or orphaned work that the administrator has confirmed can be deleted.

Delete confirmed abandoned orgs from **Active Scratch Orgs**. Deleting the active record frees an
active slot. Keep the Scratch Org Info request when its history is useful; deleting the request also
deletes an associated active org. Save release evidence before deletion because scratch-org data is
not recoverable.

Local `sf org list` output is not the Dev Hub inventory. It shows authorizations available to that
workstation and can contain stale files after an org is gone. Conversely, an orphaned active org can
exist in the Dev Hub without usable local authorization. The Dev Hub's **Active Scratch Orgs** list
is authoritative.

## Release stop conditions

Stop before creating another org when any of these is true:

- an existing matching org can be reused safely;
- an active org has no known owner or purpose;
- fewer fresh creations remain than the current stage requires;
- cleanup from the previous stage is unconfirmed;
- the source commit, candidate `04t`, namespace shape, or security mode is ambiguous;
- required no-org checks have not passed.

Package creation and promotion do not require scratch-org workflow evidence. The sandbox and production installation URLs are produced only from
the exact promoted `04t` recorded in `config/package-releases.json`.

## Related

- [Source development](../contributing/source-development.md)
- [Create a demo scratch org](../install/install-demo-in-a-scratch-org.md)
- [Package testing and upgrades](./package-testing-and-upgrades.md)
- [Check and Check Set outcome verification](./check-outcome-verification.md)
- [Release runtime matrix](./release-runtime-matrix.md)
- [Release instructions](../../.github/RELEASING.md)
