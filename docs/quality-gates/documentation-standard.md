# Documentation quality and accuracy standard

Maintainer reference for documentation contributors and reviewers.

This page is for documentation contributors.

Use this standard for every page in `docs`. [Create your first Check](../step-by-step-guide/create-your-first-check.md)
is the administrator-task reference for Setup labels, ordered steps, expected results, and recovery.
The [Batch Apex guide](../developer-guides/async-apex/batch.md) is the developer-task reference for complete code and
explicit decisions. Match their clarity, but use the page structure that fits the reader's task. An
installation guide, worked example, metadata reference, and Apex guide should not have identical
sections.

This page is for documentation contributors and should appear only in contributor navigation, not
as a normal administrator next step.

## Prerequisites

Before editing one page:

1. Read that page from beginning to end without editing it.
2. Follow its local links and identify information that the reader must understand on the current
   page instead of behind a link.
3. Verify technical claims against the current package source, configuration, release file, or
   script that owns the behavior. Do not use another documentation page as the only proof.
4. Read the administrator or developer reference page that matches the intended audience.
5. Edit and validate this page before starting another page.

Confirm exact Setup labels, API names, defaults, supported values, limits, permissions, method
signatures, returned IDs, and result behavior. If the repository does not prove a claim, do not
guess.

## Step 1: Write for a Salesforce administrator first

Place an audience statement near the top when a page is for a Flow administrator, Agentforce
administrator, developer, integration engineer, package maintainer, or restricted support owner.
Give administrators an explicit off-ramp before code or infrastructure prerequisites.

- Start with the Salesforce task the reader wants to complete.
- Use familiar Salesforce terms such as record, Flow, Apex job, Permission Set, Custom Permission,
  Platform Event, and Qualified API Name.
- Introduce a technical term only when the reader must see it in Setup, Flow Builder, Apex, an
  error, or monitoring. Explain it where it first appears.
- Do not use internal engineering terms when normal Salesforce language says the same thing.
- Do not use personas, assumed team structures, or unexplained sample variables.

## Use the right page order

For a task guide, use these sections when they apply:

1. A title that states the outcome.
2. A short introduction explaining when and why to use the API.
3. Concrete examples labeled **Example:**.
4. **Before you start**, including access, Qualified API Name, record limits, and result handling.
5. Complete steps in the order the reader performs them.
6. Complete code with comments explaining package names, inputs, result choices, and returned IDs.
7. A plain-language explanation of every code argument and output that is not obvious.
8. Monitoring, testing, troubleshooting, and related guides.

Do not place a test or scheduling step before the class it uses. Define a sample class once and
reuse it instead of showing competing versions of the same class.

For other page types:

- A worked example starts with a familiar Salesforce requirement, explains why its Evaluation Type
  fits, shows every configuration value, states what the user sees, and includes positive and
  negative tests.
- An installation or operations guide states prerequisites, gives ordered steps with expected
  results, explains how to verify the change, and provides recovery steps when it fails.
- A metadata reference uses the exact Setup label and API name, explains what the field changes,
  gives its default and allowed values, and links to a task guide that shows when to use it.
- A technical reference defines the contract precisely, separates public behavior from internal
  implementation, and gives examples only where they make the contract easier to apply.
- A folder overview helps the reader choose a page by Salesforce goal. It does not merely list
  filenames or repeat every child page.

Keep independent decisions separate. For a background job, distinguish how records are selected,
when the job starts, how many records run in one transaction, and where results go. When one
complete example combines those choices, list the selected values and state that they are example
choices rather than universal recommendations.

## Give every user task one owner

Each supported user job must have one primary maintained page. Update that page when behavior
changes instead of adding a second end-to-end procedure elsewhere. Folder indexes and the
[documentation home](../README.md) route readers to the owner; reference pages can supply exact
field, API, event, or reason-code contracts without becoming competing walkthroughs.

Before publishing a new task guide or materially changing an existing one:

1. identify the current owner page and reconcile overlapping procedures;
2. verify the complete path with the permissions and environment named by the guide;
3. prove the expected outcome and at least one relevant negative, fault, or access outcome;
4. exercise the documented troubleshooting and recovery or cleanup path; and
5. update the owning folder index and primary navigation when discoverability changes.

Production installation, upgrade, uninstall, external event delivery, Agentforce, and hosted MCP
procedures require an approved representative environment and owner. A desk review or passing link
check does not replace that runtime walkthrough. Record any unverified environment-specific claim
as a limitation instead of presenting it as completed evidence.

## Make Salesforce names unmistakable

Label names by their purpose:

- **Permission Set:** Record Health Check Card User
- **Custom Permission label:** Record Health Check Run
- **Custom Permission API name:** `rhc__Record_Health_Check_Run`
- **Check Set Qualified API Name:** `My_Account_Checks`

Explain that `rhc.` identifies a packaged Apex type and `rhc__` is the namespace prefix on an API
name delivered by the installed package. Tell readers to copy the exact Qualified API Name from
Setup and never add or remove `rhc__` themselves.

## Make examples safe to follow

- Use an administrator-created Check Set such as `My_Account_Checks` in active code.
- Mention an installed-package name such as `rhc__Example_Account_Check_Builder_Guide` only as an alternative in a
  comment or explanation.
- State where every sample variable comes from.
- In Setup examples, give the complete navigation path and use the label the administrator sees.
- In Custom Metadata examples, separate the field label from its API name.
- When example custom objects or fields are required, say that they are not included with Record
  Health Check, list what must be created, and warn that the code will not compile first.
- Use comments to explain `NONE`, `ACTIONABLE`, and `ALL` where the publication argument appears.
- State whether a returned ID identifies a scheduled job, Apex job, Record Health Check run, or
  Salesforce record.

## Explain results before monitoring

Always distinguish these outcomes:

- `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` are health results.
- **Setup → Apex Jobs** shows whether an Apex job completed; it does not show individual health
  results.
- `FAIL` means a record did not meet a Check. It does not mean the Apex job failed.
- Platform Events are messages, not permanent storage. A Flow, Apex trigger, or integration must
  receive them.
- `NONE` is useful when custom code reads and saves the returned response directly. With a packaged
  background class that returns only a job ID, `NONE` retains no individual health results.

## State limits as decisions

Do not list a limit without explaining what the reader should do:

- State the allowed value.
- Give a starting value.
- Explain when to lower or raise it.
- Keep the total record limit separate from the number processed in one transaction.
- Use a numerical example when several limits interact.

## Review one page before moving to the next

Before completing a documentation change, read every affected page from beginning to end and ask:

- Can a junior Salesforce administrator identify the correct option without guessing?
- Is every Setup name labeled and every path complete?
- Does each example say where its inputs come from?
- Can the reader tell where results go and where job status appears?
- Are required custom objects, event receivers, permissions, and tests stated before use?
- Does any paragraph repeat code comments without adding useful context?
- Does a link replace detail the reader needs at the current step?
- Are examples and limits consistent with the package source and with every already-reviewed page?
- Does the page use links for optional depth rather than to avoid an explanation needed now?
- Could any sentence be read in two reasonable ways?

Run the formatter and documentation checks for the page. Then read the rendered Markdown structure
from title to final link. Only after that page passes should the next document be opened for review.

After every page in a folder has passed individually, reread the folder in navigation order. Remove
contradictions and unnecessary repetition, but keep information that a reader needs to use each
page without searching another page first.

## Troubleshooting the review

If a documentation check fails, correct the page structure or broken statement instead of weakening
the check. If source behavior is unclear, stop and verify the Apex implementation before describing
it. Do not guess at a permission, limit, object, field, return value, or Setup path.

## Related

- [Source development](../contributing/source-development.md)
- [Documentation home](../README.md)
- [API documentation](../developer-guides/README.md)
- [Batch Apex reference example](../developer-guides/async-apex/batch.md)
