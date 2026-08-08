# Record Health Check

[![License: Apache 2.0](assets/img/badge-license.svg)](LICENSE)
[![CI](https://github.com/gkolan/record-health-check/actions/workflows/ci.yml/badge.svg)](https://github.com/gkolan/record-health-check/actions/workflows/ci.yml)
[![Apex coverage: 99.41%](https://img.shields.io/badge/Apex%20coverage-99.41%25-brightgreen)](https://github.com/gkolan/record-health-check/actions/workflows/ci.yml)
[![Salesforce API](assets/img/badge-salesforce-api.svg)](packages/record-health-check/sfdx-project.json)

[![Install in Sandbox](https://img.shields.io/badge/Install_in_Sandbox-032D60?style=for-the-badge)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak000000ZXVlAAO)
[![Install in Production](https://img.shields.io/badge/Install_in_Production-0176D3?style=for-the-badge)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak000000ZXVlAAO)

> **Make informed decisions before taking action on Salesforce data.**

Record Health Check is a metadata-driven framework that evaluates a Salesforce record directly on its record page. It provides read-only guidance about what needs attention, why it matters, and how to resolve it, without modifying the record or blocking users.

Every Rule returns **Pass**, **Fail**, **Skipped**, **Unable to Check**, or **System Error** on the
card. Fail rows show **Failed**, **Warning**, or **Info** by severity. When a record needs attention,
the card explains what was **Found** and **Expected**, and provides fix instructions with an optional
read-only **Fix it** link.

**Check Sets** and **Rules** are defined in Custom Metadata. The framework evaluates them at read time, so one card can review the current record, related records, aggregate results, and data that existed before the Rules were created, all without writing to the record.

> Questions and feedback can be shared in a GitHub [discussion](https://github.com/gkolan/record-health-check/discussions). To report a bug or request a feature, open an [issue](https://github.com/gkolan/record-health-check/issues). You can also [join the community on Slack](https://recordhealthcheck.com/slack-invite). Already a member? [Open Slack](https://recordhealthcheck.com/slack). Prefer email? Reach out at [feedback@recordhealthcheck.com](mailto:feedback@recordhealthcheck.com).

**Quick links:** [Documentation](docs/README.md) ·
[Install](docs/installation/02-install-and-verify.md) ·
[Try the demo](docs/installation/05-create-rhc-scratch-org.md) ·
[Support](SUPPORT.md) ·
[Examples](docs/examples/README.md)

## Demo

<table>
  <tr>
    <td width="48%" valign="top">
      <p><b>Example:</b><br /><b>Account Relationship &amp; Risk Health Check</b></p>
      <p>An account team can review relationship strength, ownership, engagement, revenue coverage, and customer risk without leaving the record page.</p>
      <ul>
        <li><b>Review the whole relationship.</b> Rules evaluate the Account together with Opportunity Contact Roles, Contacts, Opportunities, Cases, Activities, ownership, and parent-account context.</li>
        <li><b>See business evidence.</b> Found and Expected values explain results such as three reachable Executive Sponsors, six contacts missing email, four high-priority cases, and a dynamically calculated 75% revenue-coverage target.</li>
        <li><b>Understand every outcome.</b> Passed Rules remain compact, issues include severity and corrective guidance, and skipped Rules explain the business reason they do not apply to this Account.</li>
        <li><b>Act on the risk.</b> Remediation guidance directs the account team toward the ownership, relationship, pipeline, or service action that closes the gap.</li>
      </ul>
      <p><b>Administrators control the experience</b></p>
      <ul>
        <li>Each check shown on the card is a Rule in the selected Check Set.</li>
        <li>Custom Metadata defines what each Rule evaluates, when it applies, and whether the card runs when the page opens or when the user selects <b>Run</b>.</li>
        <li>The same component can be configured for any Salesforce object with a record page.</li>
      </ul>
    </td>
    <td width="52%" valign="top">
      <img src="assets/img/Example_Account_Relationship_Risk_Screenshot.png" alt="Account Relationship and Risk Health Check showing executive sponsorship, ownership, engagement, revenue coverage, customer issues, descriptive Found and Expected values, and an intentional business-specific skip" width="100%" />
    </td>
  </tr>
</table>

### What this example demonstrates

- **Formula Rules** evaluate fields on the current Account, such as whether the owner is still
  an active user.
- **Query Rules** measure related records and aggregates. Found and Expected values explain
  results such as reachable Executive Sponsors, contacts missing email, open pipeline against a
  75% revenue target, and high-priority Cases.
- **Custom Apex** evaluates recent Tasks and Events within a configurable 90-day window to
  confirm customer engagement is current.
- **Applicability conditions** skip Rules that do not apply to this Account. Channel-partner
  governance is skipped for a direct Customer, and the card explains why.

## Built for decisions at the record

Record Health Check keeps the result, evidence, and next step together on the Lightning record page:

- **Clear outcomes:** every Rule reports Pass, Fail, Skipped, Unable to Check, or System Error; issues are classified as Failed, Warning, or Info.
- **Useful evidence:** Found and Expected values explain the gap instead of leaving users to interpret a score or dashboard.
- **Guided resolution:** fix instructions and an optional read-only **Fix it** link point users toward the next action without changing the record.

Administrators define Check Sets and Rules as Custom Metadata, choose when a Rule applies, and control whether the card runs on open or on demand. Evaluation can use a Formula, a Query, two compared queries, or custom Apex.

### Framework capabilities

| Capability                    | What it provides                                                                                                                                                                   |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Custom Metadata configuration | Version, review, and deploy Check Sets and Rules with the rest of your Salesforce metadata                                                                                         |
| Applicability conditions      | Skip Rules that do not apply and explain why, such as a partner-only check on a customer Account                                                                                   |
| Display and run controls      | Run automatically or on demand and control how passed and skipped Rules appear                                                                                                     |
| Demo configuration            | Four packaged Demo Check Sets for Account, Contact, and Opportunity                                                                                                                |
| Permission sets               | **Record Health Check User** (`Record_Health_Check_User`) for running checks and **Record Health Check Admin** (`Record_Health_Check_Admin`) for configuration and troubleshooting |
| Automation and observability  | Apex and Flow entry points, opt-in platform events, and permission-gated diagnostics                                                                                               |

## Framework Snapshot

| Measure              | Current profile                                                                   |
| -------------------- | --------------------------------------------------------------------------------- |
| 2GP unlocked package | `rhc` namespace                                                                   |
| Apex                 | 173 classes, including 74 test classes · 99.41% CI coverage                       |
| LWC                  | 1 component (`recordHealthCheck`) · 98%+ Jest coverage                            |
| Packaged examples    | 4 Demo Check Sets · 21 Rules                                                      |
| Security access      | 2 permission sets: **Record Health Check User** and **Record Health Check Admin** |
| Evaluation model     | 4 types: Formula, Query, Compare two queries, and Apex                            |
| Documentation        | 90 maintained pages, including 19 worked Rule examples                            |

## Contributing

See the [contribution guide](.github/CONTRIBUTING.md) for local checks, testing requirements, and pull request guidance. For questions and bug reports, see [Support](SUPPORT.md).

## License

Licensed under the [Apache License, Version 2.0](LICENSE). See [NOTICE](NOTICE) for attribution.
