# Salesforce operations standard

This record defines the repository's Salesforce CLI, scratch-org, and package-release operating
standard. `AGENTS.md` makes the same requirements mandatory for AI coding agents.

## Toolchain migration record

On 2026-08-08, the workstation and CI baseline moved from Salesforce CLI 2.139.6 to 2.146.3, the
official npm `latest` release at verification time. `config/toolchain.json` records the adopted
version, and `npm run check:toolchain` prevents workstation, CI, and agent instructions from
drifting apart. A scheduled workflow runs `npm run check:toolchain-latest` daily; when Salesforce
publishes a newer official release, the baseline must be reviewed and advanced as one change.
The same policy file pins Node.js 22 and Code Analyzer 5.14.0 for release reproducibility.

The migration also exposed legacy authorization records under `.sfdx` while current CLI commands
use `.sf` and the operating-system credential store. Legacy records may be used once to restore an
org through `sf org login sfdx-url`; secrets must pass through stdin and must never be printed or
stored in this repository. A successful migration is verified with `sf org display --json` using
the new CLI. Do not preserve credential files as evidence.

## Redacted verification evidence

| Shape                   | Alias               | Org ID               | Namespace | Expiration | LWC deployment       |
| ----------------------- | ------------------- | -------------------- | --------- | ---------- | -------------------- |
| Namespaced source       | `rhc-ns-20260808`   | `00DO400000bbGtJMAU` | `rhc`     | 2026-08-09 | `0AfO400000dXUKDKA4` |
| Subscriber-style source | `rhc-nons-20260807` | `00DRK00000XkqiC2AR` | none      | 2026-08-08 | `0AfRK00000sby7l0AA` |

Both targeted LWC validations and deployments succeeded with zero component errors. The verified
theme contract is:

- SLDS 1: gray card header, 0.75rem radius, and card shadow.
- SLDS 2: transparent card header, no border, and no card shadow.

This table contains no reusable credential. Future evidence must follow the same check.

## Scratch-org capacity and cleanup

Every create path checks `ActiveScratchOrgs` and `DailyScratchOrgs` before consuming capacity. A
clean-install or upgrade gate must create a clean org; ordinary continuation work should reuse a
suitable active org. All project scratch orgs request the maximum 30-day lifetime so they remain
useful for review. CI and temporary verification workflows still delete owned orgs in an `always()`
step or an equivalent process-exit cleanup; expiration is a safety net, not the cleanup strategy.

Run the guard directly with:

```bash
npm run check:scratch-capacity -- --dev-hub <dev-hub> --required <org-count>
```

At the 2026-08-08 audit, the Dev Hub had 29 of 40 active slots but 0 of 5 daily creates remaining.
That is why checking only the active-org list is insufficient.

## Release sequence

1. Run local structural, documentation, JavaScript, SLDS, security, and coverage gates.
2. Prove namespaced and no-namespace source shapes and refresh measured coverage.
3. Commit the exact release branch and run the complete release preflight.
4. Check `Package2VersionCreates` capacity and create one immutable candidate with
   `npm run package:create -- --dev-hub <dev-hub> --release-ready`. Never create per commit.
5. Verify a clean no-namespace subscriber install and smoke test.
6. Verify previous-to-candidate upgrade and subscriber-owned configuration preservation.
7. Attach redacted evidence to the pull request and complete release review.
8. Promote the verified candidate at the approved release point.
9. Move the former stable version to `previous`, publish the new stable version and install URLs,
   tag the exact source, and create the release.

See `RELEASING.md` for the command-level procedure.
