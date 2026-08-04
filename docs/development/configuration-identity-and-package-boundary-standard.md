# Configuration identity and package boundary standard

> [!NOTE]
> On this page, preserve one exact Custom Metadata identity contract and keep shipped Demo
> Check Sets clearly labeled so administrators can distinguish starter content from org policy.

Apply this standard whenever code, Flow, Lightning, events, tests, examples, or documentation
identifies a Check Set or Rule.

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
FROM Record_Health_Check_Set__mdt
ORDER BY QualifiedApiName
```

Use the corresponding Rule query for Rule entry points. Store or pass the returned
`QualifiedApiName` exactly.

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

## Keep Demo starter configuration explicit

`force-app` contains the engine, Lightning component, permissions, Custom Metadata Type
definitions, public APIs, reusable evaluator code, and the four shipped `Example_` Demo Check Sets
(with their Rules). Those records are teaching and sandbox-ready starters. Their `CardTitle__c`
values start with `Demo:` so Lightning App Builder and the card make the starter status obvious.

The same 25 records are mirrored under `integration-tests/main/default/customMetadata` so local
and CI fixture deploys stay identical to the package content. Additional teaching packs and
learning-path metadata may still live in
[`RecordHealthCheck-Examples`](https://github.com/gkolan/RecordHealthCheck-Examples).

Do not add unlabeled business-policy records to the Framework package. Keep `All` list views
unfiltered. The `Examples (Example_)` list views may filter by the `Example_` DeveloperName prefix
for Setup browsing.

## Change procedure

When adding or changing Demo starter metadata:

1. Change the record in `force-app/main/default/customMetadata`.
2. Copy the same record into `integration-tests/main/default/customMetadata`.
3. Keep filenames and XML content identical between the two locations.
4. Keep Check Set `CardTitle__c` values prefixed with `Demo:`.
5. Update `manifest/package.xml` CustomMetadata members.
6. Confirm only the intended Demo Example_ records exist under `force-app` Custom Metadata.
7. Deploy `force-app` alone to a clean org and run package tests.
8. Deploy `integration-tests` separately when exercising the broader fixture suite.
9. Test subscriber-owned, `rhc`-owned, and other-package identities when lookup behavior changes.

## Review checklist

Before accepting a change, answer yes to every question:

1. Does every public input say **Qualified API Name**?
2. Does each caller pass the exact value Salesforce returned?
3. Is namespace guessing absent from Apex and JavaScript?
4. Does a missing qualified identity fail closed with a useful error?
5. Are Framework Check Set card titles for Demo sets prefixed with `Demo:`?
6. Are force-app and integration-tests Demo Example_ records identical?
7. Do manifests, documentation, setup scripts, and tests describe the same boundary?
8. Did a Framework-only deployment pass before broader fixture deployment?
9. Did the integration suite pass after fixture deployment?

Run `npm run check:configuration-identity` and `npm run check:package-boundary` for the repository
guards.

## Lessons retained

- A valid Apex parameter rename can still break Lightning when the JavaScript object key no longer
  matches the Apex argument. Test the serialized boundary, not only each side.
- `QualifiedApiName` is discovered from Salesforce; it is not a string-formatting convention.
- A convenience retry hides configuration mistakes and creates namespace-specific behavior. Reject
  ambiguity.
- Unlabeled example records in the main package silently turn sample policy into installed customer
  policy. Prefix Demo card titles and keep DeveloperNames under `Example_`.
- Moving files is incomplete until list views, manifests, demo scripts, generated inventories,
  tests, and public documentation agree with the new boundary.
- Automated documentation scores do not establish editorial quality. Human review and executable
  release gates answer different questions; keep both.

## Related

- [Salesforce naming and metadata writing standard](salesforce-naming-and-metadata-writing-standard.md)
- [Deployment readiness standard](deployment-readiness-standard.md)
- [Integration overview](../integration/README.md)
- [Flow actions](../integration/flow-actions.md)
