# Foreign-namespace field conformance

This fixture proves that namespaced Record Health Check source can evaluate fields owned by a
second package. It is intentionally outside `integration-tests/main/default` because ordinary
contributor and release orgs do not install Salesforce CPQ.

The maintained proof topology is:

- Record Health Check source deployed in the `rhc` namespace;
- Salesforce CPQ installed in the `SBQQ` namespace; and
- an Account where `SBQQ__AssetQuantitiesCombined__c` is `false`.

The three Checks prove the same fully qualified field through Formula, Query, and record merge
surfaces. The fixture never permits an unqualified fallback such as `AssetQuantitiesCombined__c`.

## Run the gate

Use a disposable namespaced scratch org. Deploy current Framework source before this fixture and
assign the Framework user permission set to the scratch-org user.

```bash
sf package install \
  --package 04t4N000000N6EMQA0 \
  --target-org <alias> \
  --security-type AdminsOnly \
  --wait 30 \
  --no-prompt

sf project deploy start \
  --source-dir packages/record-health-check/integration-tests/foreign-namespace/main/default \
  --target-org <alias> \
  --wait 30

sf org assign permset \
  --name Record_Health_Check_User \
  --target-org <alias>

sf apex run test \
  --class-names RHCForeignNamespaceFieldIT \
  --target-org <alias> \
  --result-format human \
  --code-coverage \
  --wait 30
```

The package version ID is the Salesforce CPQ Winter '23 build used by the maintained proof org. If
that version becomes unavailable, replace it only after recording the new package name, namespace,
version, and field API name in this file.

Do not deploy this fixture to subscribers, production, or an org without CPQ. Its hard dependency
on `SBQQ__AssetQuantitiesCombined__c` is deliberate conformance evidence, not a core product
dependency.
