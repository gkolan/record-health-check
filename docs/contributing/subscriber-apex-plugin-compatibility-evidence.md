# Subscriber Apex plugin compatibility evidence

Use this verification-standard ledger to review the evidence behind the 2.0.9 subscriber Apex
plugin repair. It separates source evidence from installed-package evidence so a source test cannot
be mistaken for a released package result.

Verified on 2026-09-08 from commit `07d68b607e3998e42cf93d1bcded5e63a6d145ce` plus the tracked
2.0.9 working-tree changes described here. No scratch org or package version was created.

## Red and green regression evidence

| Stage | Environment | Result |
| --- | --- | --- |
| Red inventory | Existing namespaced source org `rhc-208-ns-20260906` | Run `707RL00001g1ez7` exposed four stale sibling assertions: the adapter, scope, and configuration-validation paths still expected generic errors instead of the new exact plugin reason contract. |
| Corrected siblings | Same org | Dry-run `0AfRL00000hY3Fd0AK` passed all 34 affected methods; deployment `0AfRL00000hY3Ir0AK` succeeded. |
| Forced platform-load failure | Same org | The first dry-run, `0AfRL00000hYCXS0A4`, failed because the assertion did not allow the package namespace on the exception type. After making that assertion namespace-portable, dry-run `0AfRL00000hYGG50AO` and deployment `0AfRL00000hYGO90AO` passed all 12 focused methods. The preserved test proves that an exception from platform type loading remains `APEX_CLASS_LOAD_FAILED` and retains the original exception type and message. |
| Green complete inventory | Fresh namespaced LWS release org `rhc-209-lws-codex-20260909` | Final run `707Ru000029xCTZ` passed 182 test classes, 1,257 test methods, and 44 setup methods: 1,301 Salesforce tests with no failures. Production-source coverage was 99.60% (11,826/11,874), and every executable production class exceeded 98%. |
| Focused compatibility matrix | Same org | Run `707RL00001g1UAG` passed 58 methods, including PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, constructor/evaluate counts, and exact diagnostic reason codes. |

The complete inventory is the reusable guard: reverting the reason mapping makes the former sibling
assertions fail, while restoring either rejected interface predicate is caught by the seven-case
source mutation guard.

## Installed and external namespace evidence

| Topology | Evidence | Interpretation |
| --- | --- | --- |
| Released RHC plus subscriber-owned empty-namespace plugin | Focused dry-run `0Afdh000009zYKXCA2` passed against installed RHC 2.0.6.2. | This is a valid public-surface compatibility control. It does not reproduce the reported customer failure and does not prove the separate-managed-namespace topology. |
| Namespaced RHC source plus installed `SBQQ` | CPQ 240.5 install request `0HfRL0000067hrC0AQ`; `SBQQ.ServiceRouter` resolved and produced `PLUGIN_CONSTRUCTOR_FAILED`. | This proves qualified foreign-namespace lookup and correct failure provenance. The CPQ class does not implement the RHC plugin interface, so it is not an NS-03 success. |
| RHC 2.0.9 candidate plus a plugin owned by a second managed namespace | `namespace-fixture/` contains the repeatable source and install procedure. | Not run. It requires a registered partner namespace, a real 2.0.9 candidate `04t`, and release-owner authorization to create the two candidate artifacts. |
| Original legacy Advanced Approvals preview | No installable SBAA artifact or customer org is available. | Not run. The source fixtures deliberately isolate the framework boundary without pretending to validate the unavailable approval product. |

## Static and configuration coverage

- Salesforce Code Analyzer scanned the package, integration, subscriber, and partner-fixture Apex
  workspaces with the Recommended rules and `--include-fixes`: zero violations, with 36 configured
  suppressions. The final machine-readable scan is
  `reports/code-analyzer-results-20260909-032500.json`; it was interpreted only through the
  repository's required results parser.
- `RHC_Plugin_Compatibility` is the source integration Check Set. Its four records produce PASS,
  FAIL, SKIPPED, and UNABLE_TO_EVALUATE, and its Apex test proves one construction and one
  evaluation for the bulk scope.
- `Subscriber_Smoke_Extension` exercises the same four outcomes through the installed package's
  global interface. The focused subscriber test also compiles every public type and factory method
  it consumes.
- Bad-configuration fixtures and Agentforce/MCP surface tests assert the exact reasons
  `APEX_CLASS_NOT_FOUND`, `PLUGIN_INTERFACE_INVALID`, `PLUGIN_CONSTRUCTOR_FAILED`, and
  `INVALID_APEX_PARAMETERS`.

## Upgrade boundary

The stable released artifact is 2.0.8.1 (`04tak000000g1R7AAI`). The repository now describes
2.0.9 development source; no 2.0.9 package candidate exists yet. Therefore an exact
2.0.8.1-to-2.0.9 installed-package upgrade cannot be claimed. Once a release owner authorizes
candidate creation, run the documented subscriber upgrade workflow and append the candidate ID,
install request, pre/post results, and rollback evidence here before promotion.

## Related

- [Compatibility implementation specification](./subscriber-apex-plugin-compatibility-spec.md)
- [Plugin compatibility integration fixtures](../../packages/record-health-check/integration-tests/plugin-compatibility-fixtures.md)
- [Package testing and upgrades](../quality-gates/package-testing-and-upgrades.md)
