# Support

This page explains where to get help with Record Health Check, based on what you need.

## Ways to get help

| I need…                                  | Do this                                                                                                                                                                                                                           |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **To read the documentation**            | Start at the [documentation home](docs/README.md). It routes you to installation, configuration, examples, integration, and reference pages by task.                                                                              |
| **To ask a question or discuss an idea** | Start a [GitHub Discussion](https://github.com/gkolan/record-health-check/discussions), or join the [community Slack](https://recordhealthcheck.com/slack-invite) for faster back-and-forth with maintainers and other users.     |
| **To report a bug**                      | Open a [Bug report](https://github.com/gkolan/record-health-check/issues/new?template=bug_report.yml) issue. Search [existing issues](https://github.com/gkolan/record-health-check/issues) first so you do not file a duplicate. |
| **To request a feature**                 | Open a [Feature request](https://github.com/gkolan/record-health-check/issues/new?template=feature_request.yml) issue.                                                                                                            |
| **To report a security vulnerability**   | Report it privately through GitHub Security Advisories. Do not open a public issue. See the [Security policy](.github/SECURITY.md) for what to include.                                                                           |
| **To contribute code or docs**           | Read [Contributing](.github/CONTRIBUTING.md) for the local checks, testing requirements, and pull request process.                                                                                                                |

## Before you ask

Most questions are answered faster with a bit of preparation:

- Note the **Check Set** and **Rule** Developer Names involved, not just the labels shown on the card.
- Note whether **Show Diagnostics** was on, and capture the `[RHC]` summary from the browser console. See [Troubleshoot with Show Diagnostics](docs/guides/07-troubleshoot-with-show-diagnostics.md).
- Note the org type (Production, Sandbox, or Scratch) and the Salesforce API version.
- Redact record data, Org IDs, session IDs, and access tokens before sharing anything.

## Where to start in the docs

| Situation                             | Start here                                                                                               |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| New to Record Health Check            | [How Record Health Check works](docs/installation/01-how-it-works.md)                                    |
| Installing for the first time         | [Install and verify](docs/installation/02-install-and-verify.md)                                         |
| A Rule is not behaving as expected    | [Troubleshoot with Show Diagnostics](docs/guides/07-troubleshoot-with-show-diagnostics.md)               |
| A result code needs explaining        | [Reason Codes](docs/reference/contracts/01-reason-codes.md)                                              |
| Comparing to Validation Rules or Flow | [Compare Record Health Check to native Salesforce tools](docs/guides/01-compare-to-native-salesforce.md) |
| Quick answers to common questions     | [FAQ](docs/guides/02-faq.md)                                                                             |

## Community Slack

The [community Slack](https://recordhealthcheck.com/slack-invite) is the fastest place to ask a
configuration question, share a Rule pattern, or get a quick sanity check before opening an issue.
It is not a channel for reporting security vulnerabilities; use the [Security policy](.github/SECURITY.md)
for those.

## Related

- [Documentation home](docs/README.md)
- [Contributing](.github/CONTRIBUTING.md)
- [Security policy](.github/SECURITY.md)
- [Code of Conduct](.github/CODE_OF_CONDUCT.md)
