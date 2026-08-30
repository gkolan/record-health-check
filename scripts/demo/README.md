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

`setupDemoData.apex` creates the complete Acme scenario in one repeatable seed step. The user who
runs setup owns Acme; the examples do not create or deactivate Salesforce users.

It does **not** deploy unpackaged Framework source or `integration-tests` samples.

The deterministic Acme data seeded by `setupDemoData.apex` includes:

- `Asteron Global Holdings → Asteron Industrial Systems → Acme Corporation`
- 38 realistic contacts, including six without email addresses
- four Opportunity Contact Roles on one open Opportunity: one `Decision Maker`, two `Executive Sponsor` roles, and one unreachable `Business User`; no `Technical Buyer`
- two open Opportunities, three recent Closed Lost Opportunities, and one historical Closed Won Opportunity without Amount or primary Contact
- two completed activities in the last 60 days
- 16 Cases: 4 open High, 4 open Medium, 4 open Low, and 4 closed Cases; 6 of the 12 open Cases have no Contact
- six Parent Account Contacts across five cities for realistic list comparisons
- 38 Acme Contacts across four different cities, with no city overlap with the Parent Account

The deterministic Check Set result is 5 Passed, 18 Failed, 1 Skipped, and 1 Unable. Failed rows
include Critical, Warning, and Info examples. The full 25-Check outcome and quality-score tables are in
[Install the demo in a scratch org](../../docs/install/install-demo-in-a-scratch-org.md#what-the-demo-prepares).

`setupDemoData.apex` is safe to run again for the named Acme demo records. On rerun, it replaces
Acme's Contacts, Opportunities, Opportunity Contact Roles, Tasks, Events, and Cases so the scenario
does not get out of sync or accumulate duplicates.

For the full walkthrough, including Windows shell notes, see
[Create the demo scratch org](../../docs/install/install-demo-in-a-scratch-org.md).

Contributors changing Framework source use
[`npm run dev:setup`](../../docs/contributing/source-development.md) instead.
After source deployment, run `npm run demo:setup-source -- --alias <source-org-alias>` to seed Acme
and verify the current source in either namespace mode.
