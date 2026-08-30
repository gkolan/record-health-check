# Record Health Check

[![License: Apache 2.0](./assets/img/badge-license.svg)](./LICENSE)
[![CI](https://github.com/gkolan/record-health-check/actions/workflows/ci.yml/badge.svg)](https://github.com/gkolan/record-health-check/actions/workflows/ci.yml)
[![Namespaced Apex coverage: 99.64%](https://img.shields.io/badge/Namespaced_Apex_coverage-99.64%25-brightgreen)](./config/quality-metrics.json)
[![LWC line coverage: 98.73%](https://img.shields.io/badge/LWC_lines-98.73%25-brightgreen)](./config/quality-metrics.json)
[![Salesforce API](./assets/img/badge-salesforce-api.svg)](./packages/record-health-check/sfdx-project.json)

[![Install in Sandbox](https://img.shields.io/badge/Install_in_Sandbox-032D60?style=for-the-badge)](https://recordhealthcheck.com/install/sandbox)
[![Install in Production](https://img.shields.io/badge/Install_in_Production-0176D3?style=for-the-badge)](https://recordhealthcheck.com/install/production)

> **Make informed decisions before taking action on Salesforce data.**

Think of Record Health Check as a coach sitting on the record page. It checks the record against rules your organization defines, explains what looks good and what needs attention, and tells users what they can do next.

**It provides guidance, not enforcement.** It never changes your data and never prevents someone from saving a record.

Free and open source. Distributed as a namespaced Salesforce 2GP unlocked package.

## How it works

**Check Sets** and **Checks** are defined in Custom Metadata. When the card runs, Record Health Check combines the record context with the business rules your organization defines to evaluate what is true now. That context can include the current record, related records, aggregate results, and data that existed before the Checks were created. It does all of this without writing to the record.

Every Check returns **Pass**, **Fail**, **Skipped**, **Unable to Check**, or **System Error**. For a **Fail** result, the row is labeled **Failed**, **Warning**, or **Info** based on its severity.

When a record needs attention, the card explains what was **Found**, what was **Expected**, why it matters, and how to resolve it. It can also provide an optional read-only action link.

## Get started

[Documentation](./docs/README.md) ·
[Install and verify in your org](./docs/install/install-in-a-sandbox.md) ·
[Deploy to a demo scratch org](./docs/install/install-demo-in-a-scratch-org.md) ·
[Examples](./docs/examples/README.md)

## See it in action

<table>
  <tr>
    <td width="48%" valign="top">
      <p><b>Example:</b><br /><b>Account Check Builder Guide</b></p>
      <p>Administrators can inspect 25 working patterns on one Account and learn what each configuration does without leaving the record page.</p>
      <ul>
        <li><b>Review the whole relationship.</b> Checks evaluate the Account together with Opportunity Contact Roles, Contacts, Opportunities, Cases, Activities, ownership, and parent-account context.</li>
        <li><b>Understand why.</b> Hover help teaches the pattern, while Found and Expected show concrete evidence such as matching Account and parent bill-to addresses, decision-maker and Technical Buyer roles, four priority Cases against a capacity of three, and $70,000 total pipeline against a $40,000 largest deal.</li>
        <li><b>Know what to do next.</b> Remediation guidance directs the account team toward the ownership, relationship, pipeline, or service action that closes the gap.</li>
      </ul>
      <p><b>Administrators control the experience</b></p>
      <ul>
        <li>Each check shown on the card is a Check in the selected Check Set.</li>
        <li>Custom Metadata defines what each Check evaluates, when it applies, and whether the card runs when the page opens or when the user selects <b>Run</b>.</li>
        <li>The same component can be configured for any Salesforce object with a record page.</li>
      </ul>
    </td>
    <td width="52%" valign="top">
      <img src="assets/img/Example_Account_Relationship_Risk_Screenshot.png" alt="Account Check Builder Guide showing Account results, Found and Expected values, remediation guidance, and a summary on the existing demo Lightning page" width="100%" />
    </td>
  </tr>
</table>

### What this demo shows

- **Formula Checks** evaluate current engagement, full Account-versus-Parent bill-to alignment, and
  conditional governance policies while showing the actual values compared.
- **Query Checks** measure related records, row values, lists, and aggregates. The seeded Account has
  a realistic mix of High-, Medium-, and Low-priority Cases.
- **Compare Two Queries Checks** teach number, currency, Date, text, aggregate, list-overlap,
  list-containment, exact-list, and no-row patterns.
- **Custom Apex** evaluates whether completed Tasks and Events meet a configurable engagement-volume
  minimum within a 60-day window, separately from the Formula-based latest-activity SLA.
- **Applicability conditions** skip a Check below its Annual Revenue threshold, and a deliberate
  no-row comparison demonstrates Unable to Check.

## Framework capabilities

| Capability                    | What it provides                                                                                                                                 |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Custom Metadata configuration | Version, review, and deploy Check Sets and Checks with the rest of your Salesforce metadata                                                      |
| Evaluation methods            | Evaluate current-record fields, related records, aggregate results, comparisons, or custom Apex logic                                            |
| Applicability conditions      | Skip Checks that do not apply and explain why, such as a partner-only Check on a customer Account                                                |
| Display and run controls      | Run Checks when the card loads or on demand, and control how passed and skipped Checks appear                                                    |
| Automation and diagnostics    | Use Apex and Flow entry points, optional Platform Events, and permission-controlled diagnostics for automation, integration, and troubleshooting |

<details>
<summary><strong>What's included</strong></summary>

<br />

| Area                  | Details                                                                                                                                                                                                              |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Package               | Salesforce 2GP unlocked package with the `rhc` namespace                                                                                                                                                             |
| Apex                  | 223 classes, including 114 test classes · [size breakdown](./docs/architecture/apex-implementation/README.md#codebase-size-and-verification) · 99.64% namespaced package coverage · 99.57% subscriber-style coverage |
| LWC                   | 1 Lightning Web Component · 236 Jest tests · 98.73% line coverage · 91.81% branch coverage                                                                                                                           |
| Packaged examples     | 4 active Example Check Set records containing 50 Check records; 49 Checks are active                                                                                                                                 |
| Permission sets       | Card User, User, Admin, MCP Integration, and Error Log Publisher                                                                                                                                                     |
| Custom permissions    | Record Health Check Run and Record Health Check View Diagnostics                                                                                                                                                     |
| Custom Metadata Types | Record Health Check Set (18 fields) and Record Health Check (44 fields)                                                                                                                                              |
| Platform Events       | Record Health Check Log (14 fields), Record Health Check Result (13 fields), and Record Health Check Set Run (18 fields)                                                                                             |
| Documentation         | 127 maintained pages, including 19 documented Check examples                                                                                                                                                         |

</details>

## Contributing

See the [contribution guide](.github/CONTRIBUTING.md) for local checks, testing requirements, and pull request guidance.

## Questions and feedback

Questions and feedback can be shared in a GitHub [discussion](https://github.com/gkolan/record-health-check/discussions). To report a bug or request a feature, open an [issue](https://github.com/gkolan/record-health-check/issues). You can also [join the community on Slack](https://recordhealthcheck.com/slack-invite). Already a member? [Open Slack](https://recordhealthcheck.com/slack). Prefer email? Reach out at [feedback@recordhealthcheck.com](mailto:feedback@recordhealthcheck.com).

## License

Licensed under the [Apache License, Version 2.0](./LICENSE). See [NOTICE](./NOTICE) for attribution.
