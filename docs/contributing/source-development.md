# Source development (contributors only)

> [!NOTE]
> On this page, set up a contributor scratch org that deploys unpackaged Framework source so you can
> change Apex, LWC, and Custom Metadata and prove the change with package `RunLocalTests`.

> [!IMPORTANT]
> This workflow deploys unpackaged Framework source into a development org. Do **not** use it to
> install or upgrade Record Health Check in a subscriber sandbox or production org. Subscribers
> install the promoted unlocked package (`04t`) from [Install and verify](../installation/install-and-verify.md).

Use this guide when you change Framework code in this repository. The packaging project lives at
`packages/record-health-check/`. Commands below work the same on macOS, Linux, and Windows when you
pass `--dev-hub` (see [Windows and shell notes](#windows-and-shell-notes)).

## Prerequisites

Before you start:

- Salesforce CLI (`sf`) installed and on your `PATH`
- A Dev Hub org you can authenticate (example alias: `my-dev-hub`)
- Node.js 22+ and `npm ci` at the repository root

Confirm the CLI, then clone and install dependencies:

```bash
sf --version
git clone https://github.com/gkolan/record-health-check.git
cd record-health-check
npm ci
sf org login web --set-default-dev-hub --alias my-dev-hub
```

## Step 1: Create the contributor org

From the repository root, run:

```bash
npm run dev:setup -- --dev-hub my-dev-hub --alias rhc-dev
```

The command refuses to overwrite an existing alias. Choose a new alias when `rhc-dev` already
exists.

What success looks like:

| Milestone | Expected result |
| --- | --- |
| Scratch org created | Alias `rhc-dev` (or the alias you chose) is Active |
| Framework deployed | `packages/record-health-check/force-app` is in the org |
| Integration fixtures deployed | `packages/record-health-check/integration-tests` is in the org for maintainer gates |
| Local tests ran | Package `RunLocalTests` completed during the Framework deploy |

This command does **not** install the public `04t` subscriber package.

## Step 2: Rerun package tests

After you change Apex or metadata, rerun local tests in the same org:

```bash
npm run dev:test -- --alias rhc-dev
```

## Step 3: Prove portable (no-namespace) source deploy

Before you open a PR that changes package Apex, also prove the same `force-app` deploys into a
scratch org that has **no** namespace. That check catches hardcoded `rhc__` string literals early:

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

Keep `integration-tests/` out of subscriber installs. That directory is CI-only sample metadata.
See the [integration-tests README](../../packages/record-health-check/integration-tests/README.md).

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
| `An org already uses alias '…'` | Choose a new `--alias`, or delete the old scratch org when you no longer need it |
| Deploy fails on currency field planner tests | The org is multi-currency; see the [FAQ](../guides/faq.md#why-did-contributor-source-deploy-fail-apex-tests-in-a-multi-currency-org) |
| `sf` not found on Windows | Confirm the Salesforce CLI install and that your shell session can resolve `sf` |
| Need the subscriber demo instead | Use `npm run setup` and [Create the demo scratch org](../installation/create-rhc-scratch-org.md) |

## Next steps

- Review the local gates in [Contributing](../../.github/CONTRIBUTING.md) before you open a PR
- Read [Package testing and upgrades](../reference/framework/package-testing-and-upgrades.md) for
  test ownership and subscriber upgrade behavior
- Follow [Releasing](../../.github/RELEASING.md) when you are ready to create a package version
