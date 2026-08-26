# Flow guides

Use this folder when a Flow must run an existing Check or Check Set and make an immediate decision.
No custom Apex is required.

| Task | Guide |
| --- | --- |
| Build and test the Flow path | [Run a Check from Flow](./run-a-check.md) |
| Look up every action input and output | [Flow action inputs and outputs](./action-inputs-and-outputs.md) |
| Translate `PASS`, `FAIL`, `ERROR`, and other statuses | [Understand result labels and statuses](../reference/results/statuses-and-labels.md) |

Prove the Check Set on the Lightning card before debugging it in Flow. A `FAIL` result means the
business condition was not met; it does not use the Flow fault connector.

## Related

- [Choose how a Check starts](../start-here/choose-how-checks-run.md)
- [Save results](../save-results/README.md)
