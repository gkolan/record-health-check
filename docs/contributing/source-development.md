# Develop the repository source

Use this workflow when changing the package implementation.

> [!NOTE]
> On this page, create a scratch org for changing the Record Health Check package source. The setup
> deploys Apex, Lightning Web Components, and Custom Metadata and runs the package's local Apex
> tests.

> [!IMPORTANT]
> This workflow deploys unpackaged package source into a development org. Do **not** use it to
> install or upgrade Record Health Check in a subscriber sandbox or production org. Subscribers
> install the promoted unlocked package (`04t`) from [Install and verify](../install/install-in-a-sandbox.md).

`npm run setup` creates an installed-package demo. `npm run dev:setup` deploys unpackaged contributor
source. They are different workflows; do not substitute one command for the other.

Use this guide only when contributing changes to this repository. The package project is in
`packages/record-health-check/`. If the goal is to evaluate the installed package as an
administrator or user, follow [Create a demo scratch org](../install/install-demo-in-a-scratch-org.md)
instead.

## Prerequisites

Before you start:

- Git
- Salesforce CLI 2.148.3 (`sf`) installed and on your `PATH`
- A Dev Hub org you can authenticate (example alias: `my-dev-hub`)
- Node.js 22

Clone the repository, install its pinned dependencies, authenticate the Dev Hub, and verify the
required Salesforce CLI version:

```bash
git clone https://github.com/gkolan/record-health-check.git
cd record-health-check
npm ci
sf org login web --set-default-dev-hub --alias my-dev-hub
npm run check:toolchain
```

The final command must report that the local and CI toolchains use Salesforce CLI 2.148.3. The
repository intentionally stops contributor commands when another CLI version is installed.

## Step 1: Create the contributor org

From the repository root, run:

```bash
npm run dev:setup -- --dev-hub my-dev-hub --alias rhc-dev
```

Before creating the org, the command confirms that the Dev Hub has both an available active scratch
org and an available scratch-org creation for the day. It then creates a 30-day scratch org. The
command refuses to overwrite an existing alias, so choose a new alias when `rhc-dev` already
exists.

What success looks like:

| Milestone | Expected result |
| --- | --- |
| Scratch org created | Alias `rhc-dev` (or the alias you chose) is Active |
| Package source deployed | `packages/record-health-check/force-app` is in the org |
| Integration fixtures deployed | `packages/record-health-check/integration-tests` is in the org for maintainer gates |
| Local tests ran | Package `RunLocalTests` completed during the package-source deploy |

This command does **not** install the public `04t` subscriber package.

Rollback for this workflow means deleting the exact disposable scratch org alias after preserving
any needed test evidence. It never means deleting source or packages from a sandbox or production
org.

## Step 2: Rerun package tests

After changing Apex or metadata, deploy those changes to `rhc-dev`, then rerun local tests in the
same org. The command below runs every local Apex test and requests code coverage; it does not
deploy unsaved source changes.

```bash
npm run dev:test -- --alias rhc-dev
```

## Seed the current-source Acme demo

Contributor and portable-test orgs deploy source, so they do not run the installed-package demo
setup automatically. Seed and verify the documented Acme hierarchy in either a namespaced or
no-namespace source scratch org with:

```bash
npm run demo:setup-source -- --alias rhc-dev
```

The command detects the source namespace, runs the committed safe-to-rerun
`scripts/subscriber/data/setupDemoData.apex` seed, and evaluates all 25 current-source Checks using
`scripts/contributor/verifyDemoSource.apex`. For the 2.0.5 source, success reports **14 Passed, 8
Failed, 3 Skipped, and 0 Unable to Check**. The data shape remains three Accounts, 44 Contacts, two
Opportunities, three Opportunity Contact Roles, two Tasks, and 16 Cases.

Rerunning the command replaces only the tagged Acme demo's related records. To remove the complete
demo, delete the three Accounts whose Account Number begins with `RHC-DEMO-`, starting with Acme and
then its parents so Salesforce relationship constraints are respected.

## Step 3: Prove portable (no-namespace) source deploy

Before opening a pull request that changes package Apex, also prove that the same `force-app`
deploys into a scratch org with **no** namespace. The command checks Dev Hub capacity, creates a
30-day org, deploys the package source, and runs local Apex tests. This catches source that
incorrectly assumes the `rhc` namespace is always present.

```bash
npm run dev:test-no-namespace -- --dev-hub my-dev-hub --alias rhc-portable
```

| Check | Command | Org shape |
| --- | --- | --- |
| Namespaced package development | `npm run dev:setup` | Uses the nested project's `rhc` namespace |
| No-namespace portable deploy | `npm run dev:test-no-namespace` | Creates a scratch org with `--no-namespace` |

## Manual package-project commands

When you need finer control, work from the nested project:

```bash
cd packages/record-health-check

sf project deploy start \
  --manifest manifest/package.xml \
  --target-org rhc-dev \
  --test-level RunLocalTests \
  --wait 30
```

The manifest deploy runs the package's local Apex tests but does not deploy the separate
`integration-tests` directory. Deploy those test fixtures only when the change requires the
maintainer integration gates.

Keep `integration-tests/` out of subscriber installs. That directory contains maintainer test
fixtures, not package metadata.
See the [integration-tests README](../../packages/record-health-check/integration-tests/README.md).

## Step 4: Delete scratch orgs when testing is complete

Delete every scratch org created for the change after its evidence is no longer needed:

```bash
sf org delete scratch --target-org rhc-dev --no-prompt
sf org delete scratch --target-org rhc-portable --no-prompt
```

Replace the aliases when different names were supplied. These commands delete the Salesforce
scratch orgs; they do not delete repository files. Do not delete a shared org or an org that this
workflow did not create.

## Windows and shell notes

`npm run dev:setup`, `npm run dev:test`, and `npm run dev:test-no-namespace` use Node and work the
same on Windows, macOS, and Linux. You still need the Salesforce CLI installed and authenticated to
a Dev Hub.

Pass the Dev Hub with `--dev-hub`, which behaves the same in bash, zsh, PowerShell, and cmd. The
`DEV_HUB_ALIAS` environment variable is still honoured, but the `VAR=value command` prefix form is
bash/zsh-only and does nothing on Windows:

```bash
npm run dev:setup -- --dev-hub my-dev-hub --alias rhc-dev
```

On Windows, prefer **PowerShell**, **cmd**, or **Git Bash** for these `npm` entry points. Do not
call the Windows `sf` CLI from WSL bash.

Shell scripts under `scripts/*.sh` (for example display-format fixtures) remain bash/zsh. On
Windows, run those from **Git Bash**, or use the Node `npm run` entry points documented on this page
when both options exist.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| `An org already uses alias '…'` | Confirm which org owns the alias. Choose a new `--alias`, or delete the old scratch org only when this work created it and it is no longer needed. |
| Scratch-org capacity is insufficient | Reuse a suitable contributor org, delete an owned org that is no longer needed, or wait for the daily limit to reset |
| Toolchain check reports another CLI version | Install the exact version shown in `config/toolchain.json`, then rerun `npm run check:toolchain` |
| Deploy fails on currency field planner tests | The org is multi-currency; see the [setup and troubleshooting FAQ](../faqs/setup-and-troubleshooting.md#why-did-source-deployment-fail-a-currency-planner-test) |
| `sf` not found on Windows | Confirm the Salesforce CLI install and that your shell session can resolve `sf` |
| Need the subscriber demo instead | Use `npm run setup` and [Create the demo scratch org](../install/install-demo-in-a-scratch-org.md) |
| Acme Corporation is missing from a source org | Run `npm run demo:setup-source -- --alias <source-org-alias>` |

## Next steps

- Follow the [documentation quality and accuracy standard](../quality-gates/documentation-standard.md) when
  editing any page in `docs`
- Review the local gates in [Contributing](../../.github/CONTRIBUTING.md) before you open a PR
- Read [Package testing and upgrades](../quality-gates/package-testing-and-upgrades.md) for
  test ownership and subscriber upgrade behavior
- Follow [Releasing](../../.github/RELEASING.md) when you are ready to create a package version
