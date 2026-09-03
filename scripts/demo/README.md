# Record Health Check demo

Use [Try the demo in a scratch org](../../docs/install/install-demo-in-a-scratch-org.md) for the complete setup instructions, runnable Apex files, Check Set selection, expected results, and cleanup.

Run the commands in **PowerShell**, **Command Prompt**, or **Git Bash** on **Windows**, or in a terminal on **macOS or Linux**.

Use the data scripts and Check definitions from the same source checkout or release. The guide explains how to evaluate the latest released package or test all four example Check Sets with current source.

## Seed an existing current-source scratch org

After deploying the current source, run:

```bash
npm run demo:setup-source -- --alias your-scratch-org
```

The command creates or reuses the synthetic Jordan Blake user, seeds the Acme hierarchy and readiness scenarios, and leaves Jordan inactive. The four Apex scripts are also available to run separately in the order documented in the guide. Reseeding replaces the named demo records; keep manual experiments on separate records.

## Test diagnostics

The data scripts do not assign permissions. To inspect diagnostics as a Card User or User, add **Record Health Check Diagnostics Viewer** and enable **Show Diagnostics** on the Check Set. **Record Health Check Admin** already includes diagnostic access. Follow [the assignment and verification steps](../../docs/install/install-demo-in-a-scratch-org.md#try-the-other-permission-sets), including the alternative if Diagnostics Viewer is absent from Setup.

## Verify without changing data

```bash
npm run demo:verify-source -- --alias your-scratch-org
```

Verification covers all four updated example Check Sets. It supports namespaced and no-namespace source orgs, but requires matching Check definitions. It does not update an older installed package.

## Related

- [Full dataset, expected results, and cleanup](../../docs/install/install-demo-in-a-scratch-org.md)
- [Create a source development org](../../docs/contributing/source-development.md)
- [Install the published package in a sandbox](../../docs/install/install-in-a-sandbox.md)
