# Find your way around the configuration forms

Start with [Configure Check Sets and Checks](./configure-check-sets-and-checks.md) for a complete
Account example. This guide explains which parts of the Setup forms you need for that work.

## Create the Check Set first

A Check Set names one review on one object. Its settings control the card and how users run it.

1. **Name the review and choose its object.** Label is the administrator's name; the API name is its
   stable identifier. Choose the object and leave Active cleared while building the review.
2. **Describe the card to users.** Enter its title and optional subtitle. The title is still required
   when the heading is hidden. Keep the default heading display for a first card.
3. **Choose how users start the review.** Keep the default manual run and visible button initially.
   Do not hide the button when the card waits for a user to click Run.
4. **Customize the Run button (optional).** Blank labels and icon use built-in choices. You can skip
   this section when creating your first review.
5. **Choose how results appear.** The defaults are a useful starting point. Passed and skipped row
   choices sit together; reveal mode controls timing, while summary controls the summary's position.
6. **Advanced settings and troubleshooting.** Leave these at their defaults unless you have a
   specific error-handling, diagnostic, or event-publishing requirement.

Package information is at the bottom. You do not need to change it to configure an ordinary review.

## Add a Check and choose one rule path

In **Name and organize the Check**, enter its Label, API name, Check Set and Evaluation Order, then
choose Evaluation Type. Keep Active cleared until the configuration is ready to test.

The unnumbered rule sections are alternative paths. Salesforce's native Setup form displays all of
these sections; selecting an Evaluation Type does not hide the others.

| Evaluation Type       | Complete these rule sections                                                                       | Leave these rule sections alone                                    |
| --------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Verify with a formula | Formula rule: enter a Pass Condition that returns true or false                                    | Query and Apex                                                     |
| Verify with a query   | All three Query sections, using only the inputs required by the selected operator and value source | Formula rule and Apex                                              |
| Compare two queries   | All three Query sections, including Source Query and Comparison Query                              | Formula rule, Apex, and fixed/record-formula expected-value inputs |
| Verify with Apex      | Apex rule, using a deployed class and its documented parameters                                    | Formula rule and Query                                             |

For Query rules, work from top to bottom:

1. **Find and read records.** Enter Source Query, the field to read when needed, and how to read the
   results. Use the list-search formula only for a mode that needs it. Bare `COUNT()` needs no Source
   Query Field.
2. **Compare with the expected value.** Choose the operator before the expected-value inputs.
   For Verify with a query, choose the expected source and fill only that source's inputs.
   Is empty and Is not empty need no expected value. For Compare two queries, fill Comparison Query
   and its field when required, and leave Expected Value Comes From unset.
3. **Decide what empty results mean.** Consider no returned records separately from an empty field
   value. These choices can affect the outcome, so do not pick a value merely to fill a blank.
   See [Query fields and empty-result behavior](../reference/custom-metadata/check-fields.md).

Then continue through the numbered sections:

- **Explain the result to users:** give the Check a recognizable title, explain what failed, and
  say how to fix it. An unable-to-evaluate message describes a check that could not be completed;
  it must not imply that the business rule failed.
- **Group and prioritize results:** choose the failure severity. Category is optional.
- **Add a fix link (optional):** provide a destination only when it gives the user a useful next
  action. Leave both fields blank when no link is needed.
- **Limit when this Check applies (optional):** keep the default applicability for a Check that
  applies to every record. Otherwise configure only the selected applicability path. Add a
  prerequisite only when the Check should depend on another Check passing.
- **Customize Found and Expected (optional):** keep defaults and leave overrides blank initially.
  Found text/formula and Expected text/formula are grouped together. Consult the
  [display rules](../reference/configuration/display-found-and-expected.md) before combining overrides.
- **Advanced settings:** leave Formula Result Type at Automatic unless the Query comparison
  formulas need a verified shared type. Leave the query row limit and event publishing at their
  defaults unless the use case requires a change.

Before activating the review, follow the test steps in the
[configuration walkthrough](./configure-check-sets-and-checks.md). Verify one record that should pass
and one that should fail, using the access of the intended card user.

## Verify the layout change

The executable layout fixtures live in `scripts/lib/card-presentation.test.mjs`. Run
`node --test scripts/lib/card-presentation.test.mjs`. They cover both field journeys, exhaustive
field placement, full-width long editors, package information placement, and formula-type guidance.
The revised journey and long-editor tests failed against the preceding layouts; the help-text test
failed against the preceding help. All must pass against the revised source.

No new Check or Check Set outcome fixtures are needed: this change rearranges authoring controls and
corrects help text; it does not alter evaluation, defaults, field requirements, or stored records.
Use the existing Account Formula and Contact-count Query examples in the configuration walkthrough
for the following manual checks after deployment to an existing authorized test org.

| Scenario                                 | Expected evidence                                                                                                                                          |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| New Check Set and New Check              | Section order matches this guide; required markers remain; Active is easy to find at the top                                                               |
| Formula and Contact-count Query examples | Each can be configured without entering fields from an unrelated evaluation path; PASS/FAIL results match the walkthrough                                  |
| Compare two queries and Apex             | Open existing examples of each type; locate both queries or class/JSON without filling unrelated rule fields; save a test copy without changing its rule   |
| Empty and optional inputs                | Optional blank overrides remain blank after save; both empty-result choices remain visible beside the Query configuration                                  |
| Invalid required input                   | Omitting Label or another required field still prevents save; an inactive saved draft remains inactive                                                     |
| Existing configuration                   | Open and cancel editing an existing Check and Check Set; no record values change merely because the layout changed                                         |
| Keyboard and narrow window               | Tab follows the displayed row order; long editors remain readable; headings identify the relevant rule path                                                |
| Access and namespace                     | In available namespaced/non-namespaced test environments, authorized administrators see the same journey; ordinary card users gain no configuration access |

Browser rendering, Salesforce deployment/readback, and manual scenario results must be recorded
separately. Source tests do not establish those results. Bulk limits, locale, currency, and LWS/Locker
execution behavior are unchanged; this change contains no evaluator or record-page component code.

## Related

- [Configure Check Sets and Checks](./configure-check-sets-and-checks.md)
- [Check fields](../reference/custom-metadata/check-fields.md)
- [Check Set fields](../reference/custom-metadata/check-set-fields.md)
