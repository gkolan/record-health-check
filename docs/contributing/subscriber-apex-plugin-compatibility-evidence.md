# Subscriber Apex plugin compatibility evidence

Use this verification-standard ledger to review the evidence behind the 2.0.9 subscriber Apex
plugin repair. It separates source evidence from installed-package evidence so a source test cannot
be mistaken for a released package result.

Originally verified from commit `07d68b607e3998e42cf93d1bcded5e63a6d145ce`; the source evidence
below was refreshed on 2026-09-09, and released package 2.0.9.2 was created from commit
`407dfe6f31c6281d4771b56db36978e89144b410`.

## Red and green regression evidence

| Stage                        | Environment                                                   | Result                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ---------------------------- | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Red inventory                | Existing namespaced source org `rhc-208-ns-20260906`          | Run `707RL00001g1ez7` exposed four stale sibling assertions: the adapter, scope, and configuration-validation paths still expected generic errors instead of the new exact plugin reason contract.                                                                                                                                                                                                                                                                      |
| Corrected siblings           | Same org                                                      | Dry-run `0AfRL00000hY3Fd0AK` passed all 34 affected methods; deployment `0AfRL00000hY3Ir0AK` succeeded.                                                                                                                                                                                                                                                                                                                                                                 |
| Forced platform-load failure | Same org                                                      | The first dry-run, `0AfRL00000hYCXS0A4`, failed because the assertion did not allow the package namespace on the exception type. After making that assertion namespace-portable, dry-run `0AfRL00000hYGG50AO` and deployment `0AfRL00000hYGO90AO` passed all 12 focused methods. The preserved test proves that an exception from platform type loading remains `APEX_CLASS_LOAD_FAILED` and retains the original exception type and message.                           |
| Green complete inventory     | Fresh namespaced LWS release org `rhc-209-lws-codex-20260909` | Final run `707Ru000029xCTZ` passed 182 test classes, 1,257 test methods, and 44 setup methods: 1,301 Salesforce tests with no failures. Production-source coverage was 99.60% (11,826/11,874), and every executable production class exceeded 98%.                                                                                                                                                                                                                      |
| Focused compatibility matrix | Same org                                                      | Run `707RL00001g1UAG` passed 58 methods, including PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, constructor/evaluate counts, and exact diagnostic reason codes.                                                                                                                                                                                                                                                                                                             |
| DLRS fixture red/green       | Reused project-owned namespaced org `rhc-208-ns-20260906`     | The first test run, `707RL00001g2o9H`, failed in the fixture because its selective Custom Metadata query omitted `QualifiedApiName`; it did not reach the product assertion. After adding every field consumed by the evaluator, dry-run `0AfRL00000hYP4s0AG`, deployment `0AfRL00000hYV8f0AG`, and test run `707RL00001g3CVm` succeeded. The preserved test requires the real foreign class to resolve and the evaluator to return exactly `PLUGIN_INTERFACE_INVALID`. |

The complete inventory is the reusable guard: reverting the reason mapping makes the former sibling
assertions fail, while restoring either rejected interface predicate is caught by the seven-case
source mutation guard.

## Installed and external namespace evidence

| Topology                                                              | Evidence                                                                                                                                                                                                                                                                                                                   | Interpretation                                                                                                                                                                                                                                                     |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Released RHC 2.0.9.2 plus subscriber-owned empty-namespace plugin     | In retained Locker subscriber org `rhc-2-0-9-locker`, focused test run `707E200002AydMm` passed against installed `04tak000000gX9FAAU`. The subscriber class was constructed once, `evaluate()` ran once, exact PASS, FAIL, SKIPPED, and UNABLE_TO_EVALUATE outcomes matched, and the subscriber plugin had 100% coverage. | This proves the supported managed-package-to-subscriber interface boundary works in the released artifact. It disproves the proposed conclusion that the direct cast always fails in this topology; a separate managed-package namespace remains a different case. |
| Namespaced RHC source plus installed `SBQQ`                           | CPQ 240.5 install request `0HfRL0000067hrC0AQ`; `SBQQ.ServiceRouter` resolved and produced `PLUGIN_CONSTRUCTOR_FAILED`.                                                                                                                                                                                                    | This proves qualified foreign-namespace lookup and correct failure provenance. The CPQ class does not implement the RHC plugin interface, so it is not an NS-03 success.                                                                                           |
| Namespaced RHC source plus installed `dlrs`                           | [DLRS 2.25](https://github.com/SFDO-Community/declarative-lookup-rollup-summaries/releases/tag/release%2F2.25) (`04tKA000000cCA1YAM`) installed successfully as request `0HfRL0000067uel0AA`. Dependency-isolated fixture `RHCForeignApexNamespaceIT` uses the global `dlrs.RollupService` class.                          | Test run `707RL00001g3CVm` proves the class resolves and produces `PLUGIN_INTERFACE_INVALID`, excluding false `APEX_CLASS_NOT_FOUND` and `PLUGIN_CONSTRUCTOR_FAILED` results. DLRS does not implement the RHC interface and therefore cannot satisfy NS-03.        |
| RHC 2.0.9 candidate plus a plugin owned by a second managed namespace | `namespace-fixture/` contains the repeatable source and install procedure.                                                                                                                                                                                                                                                 | Not run. The Dev Hub inventory contains only the `rhc` namespace. A different registered namespace is still required; a third-party package cannot be relabeled as a compatible RHC plugin.                                                                        |
| Original legacy Advanced Approvals preview                            | No installable SBAA artifact or customer org is available.                                                                                                                                                                                                                                                                 | Not run. The source fixtures deliberately isolate the framework boundary without pretending to validate the unavailable approval product.                                                                                                                          |

## Static and configuration coverage

- Salesforce Code Analyzer scanned the package, integration, subscriber, and partner-fixture Apex
  workspaces with the Recommended rules and `--include-fixes`: zero violations, with 36 configured
  suppressions. The final machine-readable scan is
  `reports/code-analyzer-results-20260909-032500.json`; it was interpreted only through the
  repository's required results parser.
- The added DLRS fixture received a focused Recommended-rules scan with `--include-fixes`:
  `reports/code-analyzer-results-20260909-012011.json` contains zero violations and was also
  interpreted only through the required results parser.
- `RHC_Plugin_Compatibility` is the source integration Check Set. Its four records produce PASS,
  FAIL, SKIPPED, and UNABLE_TO_EVALUATE, and its Apex test proves one construction and one
  evaluation for the bulk scope.
- `Subscriber_Smoke_Extension` exercises the same four outcomes through the installed package's
  global interface. The focused subscriber test also compiles every public type and factory method
  it consumes.
- Bad-configuration fixtures and Agentforce/MCP surface tests assert the exact reasons
  `APEX_CLASS_NOT_FOUND`, `PLUGIN_INTERFACE_INVALID`, `PLUGIN_CONSTRUCTOR_FAILED`, and
  `INVALID_APEX_PARAMETERS`.

## Release and upgrade boundary

The stable released artifact is 2.0.9.2 (`04tak000000gX9FAAU`). Candidate 2.0.9.1
(`04tak000000gEmXAAU`) was superseded before promotion because documentation and packaged-example
review found unsafe event/diagnostic defaults and non-deployable AI guidance. Salesforce reports
2.0.9.2 as released with 99% package coverage and no skipped validation.

Clean installation of 2.0.9.2 succeeded in both retained 30-day subscriber release orgs. The Locker
org also passed subscriber metadata deployment, exact Apex inventory, MCP-to-Apex contract testing,
and the focused subscriber plugin compatibility test. The automated browser lifecycle then failed
to find Salesforce's Edit dialog, so the reset and exact 2.0.8.1-to-2.0.9.2 upgrade stages did not
complete in that run. The release owner separately confirmed that the reported subscriber plugin
works correctly and explicitly approved promotion. This approval is recorded as an exception; the
incomplete automated stages are not represented as passing evidence.

## Related

- [Release 2.0.9.2 record](../quality-gates/release-2.0.9.2-record.md)
- [Compatibility implementation specification](./subscriber-apex-plugin-compatibility-spec.md)
- [Plugin compatibility integration fixtures](../../packages/record-health-check/integration-tests/plugin-compatibility-fixtures.md)
- [Package testing and upgrades](../quality-gates/package-testing-and-upgrades.md)
