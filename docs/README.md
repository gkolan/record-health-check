# Record Health Check documentation

Record Health Check shows whether a Salesforce record meets requirements configured by an
administrator. For example, an Account readiness review can confirm that the Account has a billing
address, an active owner, and at least one Contact with an email address.

An administrator groups related requirements in a **Check Set** and creates one **Check** for each
requirement. Users can see the results on a Lightning record page. Flow and Apex can run the same
Checks automatically.

Record Health Check reports what it finds. It does not stop a record from being saved and does not
change the record being checked.

## Recommended path for new users

| Step | Task | Expected result |
| ---: | --- | --- |
| 1 | [Learn how Record Health Check works](installation/how-it-works.md) | Understand Check Sets, Checks, and the results users see |
| 2 | [Install and verify the package](installation/install-and-verify.md) | Add the Record Health Check card to a record page in a sandbox |
| 3 | [Create your first Check](installation/create-your-first-check.md) | Configure and run one Check from Setup |
| 4 | [Choose an example that matches your requirement](examples/README.md) | Select Formula, Query, Compare Two Queries, or Apex based on where the required data lives |
| 5 | [Configure a complete Check Set](guides/configure-check-sets-and-checks.md) | Prepare the Check Set and its Checks for testing with users |

Salesforce developers who want a separate test org with prepared examples can
[create a Record Health Check scratch org](installation/create-rhc-scratch-org.md).

## What do you want to do?

| I want to… | Start here | What you will learn |
| --- | --- | --- |
| Decide whether Record Health Check fits a requirement | [Compare Record Health Check with standard Salesforce features](guides/compare-to-native-salesforce.md) | When to use Record Health Check, Validation Rules, Required Fields, Flow, or reports |
| Install, choose a version, upgrade, or remove the package | [Installation](installation/README.md) | Installation paths, immutable versions, and safe recovery guidance |
| Configure a Check Set and its Checks | [Configuration guides](guides/README.md) | Check behavior, action links, card design, testing, and troubleshooting |
| Start with an example | [Examples](examples/README.md) | Complete Formula, Query, Compare Two Queries, and Apex configurations |
| Run Checks from Flow or Apex | [Integration overview](integration/README.md) | How to start a run and receive its results |
| Respond to Platform Events | [Platform Event guides](platform-events/README.md) | How a Flow, Apex trigger, or external system receives published results |
| Monitor and maintain an installed package | [Production operations](guides/operate-in-production.md) | Upgrades, monitoring, diagnostics, backups, and removal |
| Look up a Setup field or its API name | [Metadata reference](metadata/README.md) | Check Set, Check, and Platform Event field definitions |
| Look up exact technical behavior | [Technical reference](reference/README.md) | Limits, result codes, security, compatibility, and Apex implementation details |

## Learn by example

| Your data is… | Evaluation Type | Examples |
| --- | --- | --- |
| On the current record or a parent | Verify with a formula | [Formula examples](examples/formula/README.md) |
| On related records | Verify with a query | [Query examples](examples/query/README.md) |
| Returned by two queries that must be compared | Compare Two Queries | [Compare Two Queries examples](examples/compare-two-queries/README.md) |
| Part of a decision that needs custom code | Verify with Apex | [Apex examples](examples/apex/README.md) |

## Behavior that applies to every Check

- Record Health Check reports readiness; it does **not** block a Salesforce record from being saved.
- `PASS` means the record met a Check. `FAIL` means it did not meet the requirement. A `FAIL` is a
  health result, not a Salesforce error.
- `SKIPPED` means the Check did not apply to that record. `UNABLE_TO_EVALUATE` means required data
  was unavailable. `ERROR` means an unexpected problem prevented a normal result.
- Formula and Query Checks can use only the records and fields the person running the Check can
  access.
- Check Set Run and Check Result Platform Events are off by default. Error Log Platform Events are
  on by default. Enable result events only after the receiving Flow, Apex trigger, or integration
  is ready.
- The installed package includes four example Check Sets. Their Qualified API Names begin with
  `rhc__Example_`, and their card titles begin with `Example:`. Use them for learning; create Check
  Sets with names and requirements that belong to your org before using Record Health Check in a
  business process.

## Related

- [Installation paths](installation/README.md)
- [Guides](guides/README.md)
- [Integration overview](integration/README.md)
- [Technical references](reference/README.md)
- [Documentation writing standard](contributing/api-documentation-standard.md)
- [Support](../SUPPORT.md)
- [Release notes](../CHANGELOG.md)
