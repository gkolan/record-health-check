# Reference: Configuration identity and package boundary

> [!NOTE]
> On this page, preserve one exact Custom Metadata identity contract and keep shipped Example
> Check Sets clearly labeled so administrators can distinguish starter content from org policy.

Apply this standard whenever code, Flow, Lightning, events, tests, examples, or documentation
identifies a Check Set or Check.

## What ships where

| Surface | What it contains | Who installs it |
| --- | --- | --- |
| Framework unlocked package (`rhc`) | Engine, Lightning card, Permission Sets, Custom Metadata Types, public Apex/Flow APIs, four `Example_…` Check Sets | Subscribers (supported path) |
| `packages/record-health-check/force-app` | Same Framework metadata used to build the package | Contributors (`npm run dev:setup`) |
| `packages/record-health-check/integration-tests/` | Integration-test metadata, including mirrors of the packaged Example records | CI and local verification only (not subscriber installs) |
| `subscriber-app/` | External subscriber smoke tests and optional subscriber-owned verification metadata | Subscriber demo setup (`npm run setup`) after package install |

Example Check Set `CardTitle__c` values start with `Example:` so Lightning App Builder and the card make
starter status obvious. Subscriber policy should use different Developer Names and titles.

The package namespace is `rhc`. Metadata **owned by** the package receives an `rhc__` prefix on its
`QualifiedApiName`. Subscriber-owned Custom Metadata records do not.

## Use Qualified API Name at every Framework boundary

Every external entry point accepts the exact `QualifiedApiName` returned by Salesforce. Do not ask
a caller to construct it, remove a namespace, or try multiple forms.

| Record ownership | `DeveloperName` | `QualifiedApiName` supplied to the Framework |
| --- | --- | --- |
| Subscriber-owned metadata | `Account_Readiness` | `Account_Readiness` |
| Metadata owned by the `rhc` package | `Account_Readiness` | `rhc__Account_Readiness` |
| Metadata owned by another package | `Account_Readiness` | `other__Account_Readiness` |

The namespace belongs to the package that owns the Custom Metadata record. It is not necessarily
the namespace of the Framework's Custom Metadata Type. Salesforce is the source of truth.

Discover the value instead of constructing it:

```sql
SELECT DeveloperName, QualifiedApiName
FROM rhc__Record_Health_Check_Set__mdt
ORDER BY QualifiedApiName
```

Use the corresponding Check query for Check entry points. Store or pass the returned
`QualifiedApiName` exactly.

> [!NOTE]
> The `rhc__` in the `FROM` clause names the packaged Custom Metadata **Type**, which subscriber code
> must always qualify. That is a separate matter from the record **identity** checks below: never add
> or remove a namespace on the `QualifiedApiName` value itself.

## Prohibited identity behavior

Do not:

- prepend `rhc__` or any other namespace;
- strip a namespace;
- retry a failed `QualifiedApiName` lookup with `DeveloperName`;
- accept qualified or unqualified input and guess which the caller meant;
- substitute a label, display title, or Master Label for record identity;
- use `qualifiedApiName || developerName` at a client boundary; or
- describe a Developer Name as sufficient input for Apex, Flow, Lightning, or an integration.

Fail clearly when the exact identity is absent or unknown. A deterministic configuration error is
safer than selecting a different record whose short name happens to match.

`DeveloperName` still has legitimate internal uses: displaying a short name, resolving a
same-package Custom Metadata relationship, and keying dependencies within one already-loaded Check
Set. It is not the public selection contract.

## Keep Example starter configuration explicit

`packages/record-health-check/force-app` contains the engine, Lightning component, permissions,
Custom Metadata Type definitions, public APIs, reusable evaluator code, and the four shipped
`Example_` Check Sets (with their Checks). Those records are teaching and sandbox-ready starters.

The same Example records are mirrored under
`packages/record-health-check/integration-tests/main/default/customMetadata` so local and CI sample
deploys stay identical to the package content.

Do not add unlabeled business-policy records to the Framework package. Keep `All` list views
unfiltered. The `Examples (Example_)` list views may filter by the `Example_` DeveloperName prefix
for Setup browsing.

Subscribers must not modify packaged test classes or `RecordHealthCheckTestDataFactory`. See
[Package testing and upgrades](package-testing-and-upgrades.md).

Contributors changing Example metadata or identity code: follow
[Contributing: Configuration identity](../../../.github/CONTRIBUTING.md#configuration-identity-and-package-boundary)
and run `npm run check:configuration-identity` plus `npm run check:package-boundary`.

## Related

- [Install and verify](../../installation/install-and-verify.md)
- [Security and data access](security.md)
- [Integration overview](../../integration/README.md)
- [Flow actions](../../integration/flow-actions.md)
- [Glossary](../glossary.md)
- [Contributing](../../../.github/CONTRIBUTING.md)
