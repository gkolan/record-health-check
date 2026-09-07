# Verify Check and Check Set outcomes

Use this standard whenever a release changes a packaged example, adds Record Health Check behavior,
or changes how an existing Check is evaluated. It turns the expected Salesforce results into
repeatable release evidence instead of relying on one successful demonstration.

## Required outcomes

Every active packaged example Check must run against:

- a Salesforce record expected to produce **PASS**;
- a Salesforce record expected to produce **FAIL**;
- a record expected to produce **SKIPPED** when applicability or no-row behavior can skip the Check;
- a record expected to produce **UNABLE_TO_EVALUATE** when missing comparison data is an intended
  result.

Every packaged example Check Set must run against:

- a healthy record whose results contain no failed or unable-to-check Checks; and
- a needs-review record whose results contain at least one failed Check.

A skipped Check remains skipped. Do not count it as passing merely to make a healthy Check Set.
Some Checks describe business conditions that cannot all apply to the same record. Use additional
named records so each condition is tested honestly.

## One source of expected results

[readiness-scenarios.json](../../scripts/subscriber/data/readiness-scenarios.json) is the expected-result
contract for the four packaged example Check Sets. Each named record lists every active Check in
that Check Set and its exact expected status.

The deterministic setup scripts create only the named Salesforce records and relationships needed
by that contract. The verification runner evaluates the complete Check Set, rejects missing or
duplicate results, compares every returned status, and confirms that user-facing Found and Expected
values do not contain unresolved merge fields.

Do not put an expected result in the JSON file unless the Salesforce verifier evaluates it. Do not
put a demo assertion in a separate script when it can be represented in the shared expected-result
contract.

## Development sequence

For a bug fix or new feature that affects Check behavior:

1. Write the ordinary, needs-review, empty, invalid, permission, bulk, namespace, and relevant
   platform-variation scenarios before changing the behavior.
2. Add or identify an automated test that fails for the missing or incorrect behavior.
3. Add or update the applicable Check and Check Set metadata under `integration-tests`.
4. Add deterministic Salesforce data and exact expected results for user-visible packaged examples.
5. Make the smallest implementation change that satisfies the expected behavior.
6. Run the focused tests, `npm run check:demo-outcome-coverage`, and then `npm run ci:gates`.
7. Deploy current source to the namespaced LWS and Locker validation orgs and run the complete demo
   verifier.
8. Create the package candidate, install that exact `04t`, and rerun the same expected-result
   contract in the subscriber validation orgs.

Repository-only work may not have a meaningful Check or Check Set. In that case, provide an
equivalent executable self-test and record why Salesforce Custom Metadata does not apply.

## What the source gate proves

`npm run check:demo-outcome-coverage` reads the packaged example metadata and the expected-result
contract. It fails when:

- an active Check lacks PASS or FAIL coverage;
- a relevant skipped or unable-to-check outcome is missing;
- a record omits an active Check from its Check Set;
- a record names an inactive or unknown Check;
- an expected status is misspelled;
- a packaged Check Set lacks a healthy or needs-review record; or
- a packaged Check Set has no executable scenario.

This source gate proves completeness and consistency without consuming a scratch org. It does not
prove that Salesforce returns the declared result. The source and installed-package Salesforce
jobs provide that evidence.

## Release review

Before approving a release, confirm all of the following for the exact commit and package candidate:

- all source gates pass from a clean checkout;
- the namespaced source verifier returns every declared outcome under LWS;
- the focused card verification passes under Locker;
- the exact package candidate returns the same outcomes after a clean installation;
- required upgrade paths retain subscriber-owned Check Sets and Checks; and
- a person opens the prepared records and confirms the Check Set summaries and guidance make sense.

Do not approve a release from counts alone. Save the exact Check name, record name, expected status,
actual status, source commit, package ID when applicable, security mode, and Salesforce job result.

## Related

- [Scratch org lifecycle and release plan](./scratch-org-lifecycle.md)
- [Package testing and upgrades](./package-testing-and-upgrades.md)
- [Source development](../contributing/source-development.md)
- [Create a demo scratch org](../install/install-demo-in-a-scratch-org.md)

