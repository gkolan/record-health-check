# Custom metadata

> [!NOTE]
> On this page, choose the Custom Metadata field reference that matches the Setup label or API name
> you need to verify.

Record Health Check configuration uses two Custom Metadata Types. The **Record Health Check Set**
controls the card and groups related Checks. The **Record Health Check** defines one question
inside that card.

Start with the name you see in Salesforce Setup. Each reference also supplies the API name needed
for metadata XML, Apex, automation, and generated configuration.

If you are creating your first configuration, leave this reference and follow
[Create your first Check](../../step-by-step-guide/create-your-first-check.md). Return here only to look up a
field not covered by that walkthrough.

Custom Metadata records are configuration that administrators manage under **Setup → Custom
Metadata Types** and move through change sets or source control. See
[Back up and restore configuration](../../production-operations/back-up-configuration.md) for movement between orgs.

**Label** is the human name, **Developer Name** is the stable record identity, and **Qualified API
Name** is the exact identity callers copy after save, including `rhc__` only for package-owned
records. Card-only users normally receive **Record Health Check Card User**; automation principals
receive the permission set required by the way they run checks. Editing Custom Metadata requires
**Record Health Check Admin** plus Salesforce Setup permissions such as **Customize Application**;
the packaged Admin permission set does not grant that Salesforce system permission.

## Choose a reference

| Reference | What it covers |
| --- | --- |
| [Check Set fields](./check-set-fields.md) | Every field on **Record Health Check Set** (`Record_Health_Check_Set__mdt`) |
| [Check fields](./check-fields.md) | Every field on **Record Health Check** (`Record_Health_Check__mdt`) |

These pages define configuration fields; they are not setup walkthroughs.

## Related

- [Configure Check Sets and Checks](../../build-checks/configure-check-sets-and-checks.md)
- [Platform Event metadata](../platform-event-metadata/README.md)
- [Reason Codes](../results/reason-codes.md)
- [Examples library](../../examples/README.md)
