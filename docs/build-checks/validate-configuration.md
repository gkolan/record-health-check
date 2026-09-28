# Build the configuration-validation Flow

Create one reusable autolaunched Flow that checks all Record Health Check configuration before you
activate a new or changed Check. The packaged action reads active records and inactive drafts; it
does not evaluate business records.

## Before you start

- Assign **Record Health Check Admin** to the person who runs the Flow.
- Keep new Check Sets and Checks inactive until validation succeeds.
- Open **Setup → Flows**.

## Create the Flow

1. Select **New Flow**.
2. Select **Autolaunched Flow (No Trigger)**.
3. Add an **Action** element.
4. Search for and select **Validate Record Health Check Configuration**.
5. Name the element `Validate configuration`.
6. Add a **Debug Details** screen or temporary assignments that let you inspect these outputs:

| Output                 | What success looks like               |
| ---------------------- | ------------------------------------- |
| Configuration Is Valid | `True`                                |
| Error Count            | `0`                                   |
| Warning Count          | Review each warning before activation |
| Validation Report JSON | No unresolved error finding           |

7. Save the Flow as **Validate Record Health Check Configuration**.

You can keep this Flow inactive and use **Debug** when reviewing configuration. Activate it only if
your organization has a reviewed way to run it outside Flow Builder.

## Validate a change

1. Save the Check Set and Check with **Active** unchecked.
2. Open this Flow and select **Debug**.
3. Run it and review all four outputs.
4. Correct every error in Custom Metadata.
5. Run Debug again.
6. Activate the Check Set and Check only after Configuration Is Valid is true and warnings have
   been reviewed.

## Related

- [Create your first Check](../step-by-step-guide/create-your-first-check.md)
- [Flow action inputs and outputs](../flow-guides/action-inputs-and-outputs.md#validate-record-health-check-configuration)
- [Configure Check Sets and Checks](./configure-check-sets-and-checks.md)
