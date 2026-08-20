# Record Health Check

[![License: Apache 2.0](assets/img/badge-license.svg)](LICENSE)
[![CI](https://github.com/gkolan/record-health-check/actions/workflows/ci.yml/badge.svg)](https://github.com/gkolan/record-health-check/actions/workflows/ci.yml)
[![Namespaced Apex coverage: 99.60%](https://img.shields.io/badge/Namespaced_Apex_coverage-99.60%25-brightgreen)](config/quality-metrics.json)
[![LWC line coverage: 98.55%](https://img.shields.io/badge/LWC_lines-98.55%25-brightgreen)](config/quality-metrics.json)
[![Salesforce API](assets/img/badge-salesforce-api.svg)](packages/record-health-check/sfdx-project.json)

[![Install in Sandbox](https://img.shields.io/badge/Install_in_Sandbox-032D60?style=for-the-badge)](https://recordhealthcheck.com/install/sandbox)
[![Install in Production](https://img.shields.io/badge/Install_in_Production-0176D3?style=for-the-badge)](https://recordhealthcheck.com/install/production)

> **Make informed decisions before taking action on Salesforce data.**

Record Health Check is a metadata-driven framework that evaluates a Salesforce record directly on its record page. It provides read-only guidance about what needs attention, why it matters, and how to resolve it, without modifying the record or blocking users.

Every Check returns **Pass**, **Fail**, **Skipped**, **Unable to Check**, or **System Error** on the
card. Fail rows show **Failed**, **Warning**, or **Info** by severity. When a record needs attention,
the card explains what was **Found** and **Expected**, and provides fix instructions with an optional
read-only action link.

**Check Sets** and **Checks** are defined in Custom Metadata. The framework evaluates them at read time, so one card can review the current record, related records, aggregate results, and data that existed before the Checks were created, all without writing to the record.

> Questions and feedback can be shared in a GitHub [discussion](https://github.com/gkolan/record-health-check/discussions). To report a bug or request a feature, open an [issue](https://github.com/gkolan/record-health-check/issues). You can also [join the community on Slack](https://recordhealthcheck.com/slack-invite). Already a member? [Open Slack](https://recordhealthcheck.com/slack). Prefer email? Reach out at [feedback@recordhealthcheck.com](mailto:feedback@recordhealthcheck.com).

**Quick links:** [Documentation](docs/README.md) ·
[Install and verify in your org](docs/installation/install-and-verify.md) ·
[Deploy to a demo scratch org](docs/installation/create-rhc-scratch-org.md) ·
[Examples](docs/examples/README.md)

## Demo

<table>
  <tr>
    <td width="48%" valign="top">
      <p><b>Example:</b><br /><b>Account Relationship &amp; Risk Health Check</b></p>
      <p>An account team can review relationship strength, ownership, engagement, revenue coverage, and customer risk without leaving the record page.</p>
      <ul>
        <li><b>Review the whole relationship.</b> Checks evaluate the Account together with Opportunity Contact Roles, Contacts, Opportunities, Cases, Activities, ownership, and parent-account context.</li>
        <li><b>See business evidence.</b> Found and Expected values explain results such as three reachable Executive Sponsors, six contacts missing email, four high-priority cases, and a dynamically calculated 75% revenue-coverage target.</li>
        <li><b>Understand every outcome.</b> Passed Checks remain compact, issues include severity and corrective guidance, and skipped Checks explain the business reason they do not apply to this Account.</li>
        <li><b>Act on the risk.</b> Remediation guidance directs the account team toward the ownership, relationship, pipeline, or service action that closes the gap.</li>
      </ul>
      <p><b>Administrators control the experience</b></p>
      <ul>
        <li>Each check shown on the card is a Check in the selected Check Set.</li>
        <li>Custom Metadata defines what each Check evaluates, when it applies, and whether the card runs when the page opens or when the user selects <b>Run</b>.</li>
        <li>The same component can be configured for any Salesforce object with a record page.</li>
      </ul>
    </td>
    <td width="52%" valign="top">
      <img src="assets/img/Example_Account_Relationship_Risk_Screenshot.png" alt="Account Relationship and Risk Health Check showing executive sponsorship, ownership, engagement, revenue coverage, customer issues, descriptive Found and Expected values, and an intentional business-specific skip" width="100%" />
    </td>
  </tr>
</table>

### What this example demonstrates

- **Formula Checks** evaluate fields on the current Account, such as whether the owner is still
  an active user.
- **Query Checks** measure related records and aggregates. Found and Expected values explain
  results such as reachable Executive Sponsors, contacts missing email, open pipeline against a
  75% revenue target, and high-priority Cases.
- **Custom Apex** evaluates recent Tasks and Events within a configurable 90-day window to
  confirm customer engagement is current.
- **Applicability conditions** skip Checks that do not apply to this Account. Channel-partner
  governance is skipped for a direct Customer, and the card explains why.

## Built for decisions at the record

Record Health Check keeps the result, evidence, and next step together on the Lightning record page:

- **Clear outcomes:** every Check reports Pass, Fail, Skipped, Unable to Check, or System Error; issues are classified as Failed, Warning, or Info.
- **Useful evidence:** Found and Expected values explain the gap instead of leaving users to interpret a score or dashboard.
- **Guided resolution:** fix instructions and an optional read-only action link point users toward the next step without changing the record.

## Framework capabilities

| Capability                    | What it provides                                                                                                                       |
| ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Custom Metadata configuration | Version, review, and deploy Check Sets and Checks with the rest of your Salesforce metadata                                            |
| Evaluation methods            | Evaluate the current record with a Formula, query related data, compare two queries, or use custom Apex                                |
| Applicability conditions      | Skip Checks that do not apply and explain why, such as a partner-only check on a customer Account                                      |
| Display and run controls      | Run automatically or on demand and control how passed and skipped Checks appear                                                        |
| Automation and observability  | Use Apex and Flow entry points, optional Platform Events, and permission-controlled diagnostics for automation and operational insight |

## Framework Snapshot

| Measure               | Details                                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| 2GP unlocked package  | `rhc` namespace                                                                                                          |
| Apex                  | 211 classes, including 103 test classes · 99.60% namespaced package coverage · 99.53% subscriber-style floor             |
| LWC                   | 1 Lightning Web Component (`recordHealthCheck`) · 208 Jest tests · 98.55% line coverage · 92.56% branch coverage         |
| Packaged examples     | 4 packaged Example Check Sets containing 21 Checks                                                                       |
| Permission sets       | Card User, User, Admin, and Error Log Publisher                                                                          |
| Custom permissions    | Record Health Check Run and Record Health Check View Diagnostics                                                         |
| Custom Metadata Types | Record Health Check Set (17 fields) and Record Health Check (44 fields)                                                  |
| Platform Events       | Record Health Check Log (14 fields), Record Health Check Result (13 fields), and Record Health Check Set Run (18 fields) |
| Documentation         | 106 maintained pages, including 19 documented Check examples                                                             |

## Contributing

See the [contribution guide](.github/CONTRIBUTING.md) for local checks, testing requirements, and pull request guidance. For questions and bug reports, see [Support](SUPPORT.md).

## License

Licensed under the [Apache License, Version 2.0](LICENSE). See [NOTICE](NOTICE) for attribution.
