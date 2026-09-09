# Apex plugin compatibility fixtures

`RHC_Plugin_Compatibility` is the valid, integration-only companion to the deliberately broken
`RHC_Diagnostic_Bad_Apex` catalog. It proves that plugin configuration validation hands one typed
instance to execution, that a multi-record scope invokes `evaluate` once, and that plugin-authored
outcomes and reason codes survive the public Apex response.

## Deterministic scenario matrix

| Account name                                     | Expected status      | Expected reason                         |
| ------------------------------------------------ | -------------------- | --------------------------------------- |
| `RHC Plugin Compatibility Healthy`               | `PASS`               | `PLUGIN_COMPATIBILITY_PASS`             |
| `RHC Plugin Compatibility [FAIL] Needs Review`   | `FAIL`               | `PLUGIN_COMPATIBILITY_NEEDS_REVIEW`     |
| `RHC Plugin Compatibility [SKIP] Not Applicable` | `SKIPPED`            | `PLUGIN_COMPATIBILITY_NOT_APPLICABLE`   |
| `RHC Plugin Compatibility [UNABLE] Missing Data` | `UNABLE_TO_EVALUATE` | `PLUGIN_COMPATIBILITY_DATA_UNAVAILABLE` |

The healthy Account gives the Check Set no failed or unable Checks. The needs-review Account gives
it a business failure. The marker states provide explicit skip and missing-data paths without
depending on locale, time zone, currency, or an external package. `RHCPluginCompatibilityTest`
creates all four Accounts, evaluates them in one public Check Set request, asserts each exact
status/reason pair, and asserts constructor count 1 plus evaluate count 1.

## Automated verification

Deploy the complete integration bundle to an existing authorized namespaced source org, then run:

```bash
sf apex run test \
  --tests RHCPluginCompatibilityTest,RHCDiagnosticBadConfigurationTest \
  --target-org <alias> \
  --result-format human \
  --wait 30
```

The diagnostic test separately proves that a missing class, an incompatible interface, malformed
parameters, and a throwing constructor retain distinct reason codes. Do not deploy the integration
bundle to a customer org or an installed-package subscriber org.

## Administrator verification

1. Create the four Accounts above in an existing contributor validation org.
2. Put a Record Health Check card configured with `RHC_Plugin_Compatibility` on the Account page.
3. Run the card on each Account and compare its status and reason with the table.
4. Confirm Found is 1 and Expected is 1 on the healthy Account; Found is 0 and Expected is 1 on the
   needs-review Account; the skipped and unable Accounts do not masquerade as passing.
5. Run `RHC_Diagnostic_Bad_Apex` separately as an administrator and confirm the incompatible class
   reports `PLUGIN_INTERFACE_INVALID`, while the throwing constructor reports
   `PLUGIN_CONSTRUCTOR_FAILED`.

For an installed package, use the equivalent `Subscriber_Smoke_Extension` fixture documented in
the repository-level [subscriber verification guide](../../../subscriber-app/README.md). That
fixture remains subscriber-owned and references only the package's global `rhc` API.
