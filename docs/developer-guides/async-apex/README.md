# Asynchronous Apex

Choose one background execution pattern:

| Need | Guide |
| --- | --- |
| Up to 200 known record IDs can run later | [Queueable Apex](./queueable.md) |
| Many records must run in smaller groups | [Batch Apex](./batch.md) |
| Work must start on a schedule | [Scheduled Apex](./scheduled.md) |
| Existing code still uses a future method | [Replace Future with Queueable](./replace-future-with-queueable.md) |

Background job completion does not mean every record passed. Choose where results go before
submitting the job.

## Related

- [Developer guides](../README.md)
- [Save results](../../save-results/README.md)
