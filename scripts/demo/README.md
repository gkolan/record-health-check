# Account relationship and risk demo

> [!NOTE]
> On this page, create the subscriber demo scratch org with one command and confirm the deterministic
> Acme outcomes that maintainers use for first-run verification.

Create a subscriber demo scratch org with one command. Pass your Dev Hub org alias with `--dev-hub`.
The same command works on Windows, macOS, and Linux:

```bash
npm run setup -- --dev-hub my-dev-hub --alias rhc-demo
```

Use a different scratch-org alias when needed:

```bash
npm run setup -- --dev-hub my-dev-hub --alias my-demo-alias
```

The setup installs the promoted **Record Health Check** package (`04t` from
`config/package-releases.json`), assigns `Record_Health_Check_Admin`, deploys subscriber-owned
metadata from `subscriber-app`, seeds demo Account data from `scripts/subscriber/data/`, and runs
`RHCSubscriberSmokeTest`.

It does **not** deploy unpackaged Framework source or `integration-tests` samples.

The deterministic Acme data seeded by `setupDemoData.apex` includes:

- `Asteron Global Holdings → Asteron Industrial Systems → Acme Corporation`
- Jordan Blake assigned as owner and then deactivated in a separate transaction
- 38 realistic contacts, including six without email addresses
- three reachable Opportunity Contact Roles with `Executive Sponsor`
- two open opportunities totaling $70,000 against $500,000 annual revenue
- two completed activities in the last 90 days
- four open high-priority cases

`setupDemoData.apex` is safe to run again for the named Acme demo records. On rerun, it replaces
Acme's Contacts, Opportunities, Opportunity Contact Roles, Tasks, Events, and Cases so the scenario
does not drift or accumulate duplicates.

For the full walkthrough, including Windows shell notes, see
[Create the demo scratch org](../../docs/installation/05-create-rhc-scratch-org.md).

Contributors changing Framework source use
[`npm run dev:setup`](../../docs/contributing/source-development.md) instead.
