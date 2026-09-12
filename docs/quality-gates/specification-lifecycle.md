# Specification lifecycle

Use this standard when completing or retiring a local feature specification under `specs/`.
Feature specs are ignored working documents. They help resolve a design and its proof obligations;
they are not the permanent owner of shipped product behavior.

## Completion is evidence-based

A feature spec is complete only when every requirement and scenario is in one of these states:

- verified at every boundary the contract requires, with exact source/environment identity and
  preserved evidence; or
- explicitly transferred as pending to a tracked backlog or release contract that names the owner,
  authorization needed, procedure, expected result, and consequence of remaining unverified.

A merged implementation, successful source deployment, package candidate, coverage percentage, or
passing aggregate suite does not by itself complete a spec. Source, package-build, clean-install,
upgrade, restricted-persona, transport, LWS/Locker, browser, and human boundaries remain distinct.

## Promotion before deletion

Before deleting a completed feature folder:

1. Move durable public behavior and API contracts into the applicable tracked architecture,
   reference, administrator, developer, and release documentation.
2. Move reusable code/test lessons into tracked quality standards and keep short required pointers
   in `AGENTS.md` where future agents must act on them.
3. Preserve each regression with executable automated tests, static policy gates, deterministic
   fixtures, and administrator verification procedures as applicable.
4. Correct or supersede every tracked claim contradicted by the final implementation or platform
   evidence. Search for older vocabulary and access-mode assumptions; link checks alone are not a
   semantic review.
5. Preserve immutable red/green, package, org, browser, and analyzer evidence in its release-owned
   location. Never move credentials, session URLs, passwords, or transient caches into the repo.
6. Create a retirement manifest outside the feature folder mapping every requirement, decision,
   scenario, test, fixture, evidence item, limitation, and amendment to its tracked durable owner or
   explicit pending owner. No entry may map only to the folder being deleted.
7. Validate the tracked owners from a clean Git-derived checkout, validate ignored specs explicitly,
   and make the retirement check fail for a missing mapping, missing target, unresolved contradiction,
   or pending item without an owner.
8. Delete only the exact completed feature folder after the manifest and checks pass. Preserve other
   active specs and unrelated local evidence.

## Root directory rule

Do not delete the entire `specs/` directory while `AGENTS.md` or another tracked instruction requires
`specs/spec-authoring-standard.md`. If the repository no longer needs a local specification
workspace, first move the authoring standard into tracked documentation, update all pointers and
validators, prove a clean checkout has the successor, and then remove the root in the same reviewed
change.

## Handoff language

At retirement, report separately:

- what was promoted and where;
- which executable guards own regressions;
- which evidence was preserved;
- which boundaries remain pending and their tracked owner; and
- exactly which ignored feature folder was deleted.

Never say “all lessons were documented” from a topic list alone. The retirement manifest and
semantic review must account for every binding clause and discovered contradiction.

## Related

- [Regression testing standard](./regression-testing-standard.md)
- [Documentation standard](./documentation-standard.md)
- [Check and Check Set outcome verification](./check-outcome-verification.md)
- [Release runtime matrix](./release-runtime-matrix.md)
