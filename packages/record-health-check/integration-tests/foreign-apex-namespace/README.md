# Foreign Apex namespace conformance

This dependency-isolated fixture proves that namespaced Record Health Check source resolves a
real class owned by a different managed-package namespace and reports the exact compatibility
reason when that class does not implement `rhc.RecordHealthCheckPlugin`.

The fixture uses stable DLRS 2.25 (`04tKA000000cCA1YAM`) and its global `dlrs.RollupService`
class. DLRS is intentionally a negative interface control: it proves that the qualified class was
found, but it is not an RHC plugin and must return `PLUGIN_INTERFACE_INVALID`. Do not record this
as an NS-03 compatible-plugin success.

## Automated verification

Use an existing, explicitly authorized disposable namespaced source org. Install DLRS before
deploying this directory:

```bash
sf package install \
  --package 04tKA000000cCA1YAM \
  --target-org <alias> \
  --security-type AdminsOnly \
  --wait 30

sf project deploy start \
  --source-dir packages/record-health-check/integration-tests/foreign-apex-namespace/main/default \
  --target-org <alias> \
  --wait 30

sf apex run test \
  --tests RHCForeignApexNamespaceIT \
  --target-org <alias> \
  --result-format human \
  --wait 30
```

The test requires the DLRS type and the RHC resolver to find the same class, evaluation to return
`UNABLE_TO_EVALUATE` with `PLUGIN_INTERFACE_INVALID`, and the administrator-facing fixture to
keep diagnostics and event publication off.

## Administrator verification

After the automated test is green, place the integration-only `RHC_DLRS_Foreign_Namespace` Check
Set on an Account page and run it. The Check should be unable to evaluate with reason
`PLUGIN_INTERFACE_INVALID`. The fixture is not a customer example and must not be deployed
without DLRS.
