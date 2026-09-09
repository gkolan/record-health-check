# Draft: Open Opportunities Have Products

## Plain-language summary

This Check compares the number of open Opportunities on an Account against the number of open Opportunities that have at least one Opportunity Product (line item). It **passes** when both counts are equal—every open Opportunity has at least one product. It **fails** when the counts differ—one or more open Opportunities have no products. It **skips** when the Account has no open Opportunities, because there is nothing to check.

## Clarifying questions

None. The requirement supplies all API names and business logic.

## Check Set table

| Setup label              | API field name            | Proposed value                          | Why                                              |
| ------------------------ | ------------------------- | --------------------------------------- | ------------------------------------------------ |
| Label                    | MasterLabel               | Account Opportunity Products            | Describes this Check Set's purpose               |
| Developer Name           | DeveloperName             | account_opportunity_products            | Administrator-created name; no rhc\_\_ prefix    |
| Object                   | ObjectApiName\_\_c        | Account                                 | Base object for the card                         |
| Active                   | IsActive\_\_c             | ✓ (checked)                             | Default is true; Check Set is active             |
| Card Title               | CardTitle\_\_c            | Opportunity Product Coverage            | Titles the card on the Account page              |
| Card Subtitle            | CardSubtitle\_\_c         | Verify open opportunities have products | Explains what the card covers for this object    |
| Card Run Mode            | CardRunMode\_\_c          | RUN_ON_REQUEST                          | User clicks Run to trigger the check             |
| Card Reveal Mode         | CardRevealMode\_\_c       | ONE_BY_ONE                              | Default reveal mode; Checks appear one at a time |
| Summary Display          | SummaryDisplay\_\_c       | BOTTOM                                  | Summary shows below the Checks                   |
| Passed Checks Display    | PassedChecksDisplay\_\_c  | SHOW_EACH_CHECK                         | Default; show each passed Check row              |
| Skipped Checks Display   | SkippedChecksDisplay\_\_c | SHOW_EACH_CHECK                         | Default; show each skipped Check row             |
| Found / Expected Display | FoundExpectedDisplay\_\_c | ON_DEMAND                               | Default; display on demand                       |
| Run Button Display       | RunButtonDisplay\_\_c     | LABEL_AND_ICON                          | Default; show both label and icon                |
| Run Button Label         | RunButtonLabel\_\_c       | Run                                     | Default label; explicit to make it editable      |
| Rerun Button Label       | RerunButtonLabel\_\_c     | Rerun                                   | Default label; explicit to make it editable      |
| Run Button Icon          | RunButtonIcon\_\_c        | utility:refresh                         | Standard SLDS refresh icon                       |
| Stop on System Error     | StopOnSystemError\_\_c    | (unchecked)                             | Default is false; continue on error              |
| Show Diagnostics         | ShowDiagnostics\_\_c      | (unchecked)                             | Default is false; diagnostics off in production  |
| Publish User Run Event   | PublishUserRunEvent\_\_c  | (unchecked)                             | Default is false; no platform events             |
| Publish Error Log Event  | PublishErrorLogEvent\_\_c | (unchecked)                             | Default is false; no platform events             |

## Check table

| Setup label                   | API field name                   | Proposed value                                                                                                                                         | Why                                                                                    |
| ----------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| Check Set                     | Record_Health_Check_Set\_\_c     | account_opportunity_products                                                                                                                           | Links to the Check Set Developer Name                                                  |
| Label                         | MasterLabel                      | Open Opportunities Have Products                                                                                                                       | Names this Check; appears on the card                                                  |
| Developer Name                | DeveloperName                    | open_opportunities_have_products                                                                                                                       | Administrator-created name; no rhc\_\_ prefix                                          |
| Check Title                   | CheckTitle\_\_c                  | Open Opportunities Have Products                                                                                                                       | States the claim being tested                                                          |
| Check Description             | CheckDescription\_\_c            | Passes when all open Opportunities have at least one product. Fails when one or more open Opportunities have no products.                              | Explains what the Check compares and when it passes                                    |
| Evaluation Type               | EvaluationType\_\_c              | COMPARE_TWO_QUERIES                                                                                                                                    | Required; compares two SOQL queries                                                    |
| Category                      | Category\_\_c                    | RELATIONSHIP_COVERAGE                                                                                                                                  | Relationship coverage between Opportunity and OpportunityLineItem                      |
| Failure Severity              | FailureSeverity\_\_c             | WARNING                                                                                                                                                | Optional; default is WARNING                                                           |
| Evaluation Order              | EvaluationOrder\_\_c             | 100                                                                                                                                                    | Default; determines run order                                                          |
| Active                        | IsActive\_\_c                    | ✓ (checked)                                                                                                                                            | Default is true; Check is active                                                       |
| Failure Message               | FailureMessage\_\_c              | {!record.Name fallback="this record"} has {!rhcResult.failedRecordCount} open Opportunit{!rhcResult.foundValuePluralSuffix} with no products.          | Tells the user what is wrong and how many. Uses merge tokens for record name and count |
| Unable to Evaluate Message    | UnableToEvaluateMessage\_\_c     | Check that you have Read access to the Opportunity and OpportunityLineItem objects and their IsClosed and OpportunityId fields.                        | Names what could not be reached; does not blame the user                               |
| Fix Message                   | FixMessage\_\_c                  | Add at least one product to each open Opportunity on {!record.Name fallback="this record"}.                                                            | Tells the user what to do next                                                         |
| Action Label                  | ActionLabel\_\_c                 | View Opportunities                                                                                                                                     | Label for the action button                                                            |
| Action URL                    | ActionUrl\_\_c                   | /lightning/r/Account/{!record.Id}/related/Opportunities/view                                                                                           | Links to the Account's Opportunities related list                                      |
| Applicability Mode            | ApplicabilityMode\_\_c           | WHEN_COUNT_QUERY_MATCHES                                                                                                                               | Skip if no open Opportunities exist                                                    |
| Applicability Count Query     | ApplicabilityCountQuery\_\_c     | SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false                                                                    | Counts open Opportunities; if zero, the Check skips                                    |
| Applicability Count Operator  | ApplicabilityCountOperator\_\_c  | GREATER_THAN                                                                                                                                           | Skip if count is not greater than zero                                                 |
| Applicability Count Threshold | ApplicabilityCountThreshold\_\_c | 0                                                                                                                                                      | Threshold for applicability operator                                                   |
| Applicability Not Met Message | ApplicabilityNotMetMessage\_\_c  | {!record.Name fallback="this record"} has no open Opportunities to check.                                                                              | Explains why the Check did not apply                                                   |
| Prerequisite Check            | PrerequisiteCheck\_\_c           | (blank)                                                                                                                                                | No prerequisite; this Check runs independently                                         |
| Comparison Display Mode       | ComparisonDisplayMode\_\_c       | AUTOMATIC                                                                                                                                              | Default; automatic display of found and expected                                       |
| Display Value Format          | DisplayValueFormat\_\_c          | NUMBER                                                                                                                                                 | Format counts as numbers                                                               |
| Display Found Text            | DisplayFoundText\_\_c            | {!rhcResult.foundValue} open Opportunit{!rhcResult.foundValuePluralSuffix}                                                                             | Describes the found value; uses result token and plural suffix                         |
| Display Expected Text         | DisplayExpectedText\_\_c         | {!rhcResult.expectedValue} open Opportunit{!rhcResult.foundValuePluralSuffix} with products                                                            | Describes the expected value; uses result token and plural suffix                      |
| Source Query                  | SourceQuery\_\_c                 | SELECT COUNT() openCount FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false                                                          | Counts all open Opportunities for the Account                                          |
| Source Query Field            | SourceQueryField\_\_c            | openCount                                                                                                                                              | Aggregate alias from the source query                                                  |
| Comparison Query              | ComparisonQuery\_\_c             | SELECT COUNT_DISTINCT(OpportunityId) coveredCount FROM OpportunityLineItem WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false | Counts open Opportunities that have at least one product                               |
| Comparison Query Field        | ComparisonQueryField\_\_c        | coveredCount                                                                                                                                           | Aggregate alias from the comparison query                                              |
| Query Result Handling         | QueryResultHandling\_\_c         | ONE_RESULT                                                                                                                                             | Both queries return one aggregate row; compare them directly                           |
| Comparison Operator           | ComparisonOperator\_\_c          | EQUALS                                                                                                                                                 | Pass when the counts are equal                                                         |
| No Rows Result                | NoRowsResult\_\_c                | (omit from metadata)                                                                                                                                   | Not used; ONE_RESULT aggregate comparisons are always one row                          |
| Empty Value Handling          | EmptyValueHandling\_\_c          | AS_NO_MATCH                                                                                                                                            | Default; treat empty values as no match                                                |
| Max Query Rows                | MaxQueryRows\_\_c                | 200                                                                                                                                                    | Default; both queries are aggregates and return one row                                |
| Comparison Display Mode       | ComparisonDisplayMode\_\_c       | AUTOMATIC                                                                                                                                              | Default; automatic                                                                     |
| Display Found Formula         | DisplayFoundFormula\_\_c         | (omit from metadata)                                                                                                                                   | Not used; this is COMPARE_TWO_QUERIES, not FORMULA                                     |
| Display Expected Formula      | DisplayExpectedFormula\_\_c      | (omit from metadata)                                                                                                                                   | Not used; this is COMPARE_TWO_QUERIES, not FORMULA                                     |
| Pass Condition Formula        | PassConditionFormula\_\_c        | (omit from metadata)                                                                                                                                   | Not used; comparison operator defines pass condition for COMPARE_TWO_QUERIES           |
| Formula Result Type           | FormulaResultType\_\_c           | AUTO                                                                                                                                                   | Portable cross-cutting default for every Evaluation Type                               |
| Find In List Formula          | FindInListFormula\_\_c           | (omit from metadata)                                                                                                                                   | Not used; this is COMPARE_TWO_QUERIES, not FORMULA                                     |
| Apex Class                    | ApexClass\_\_c                   | (omit from metadata)                                                                                                                                   | Not used; this is COMPARE_TWO_QUERIES, not APEX                                        |
| Apex Parameters JSON          | ApexParametersJson\_\_c          | (omit from metadata)                                                                                                                                   | Not used; this is COMPARE_TWO_QUERIES, not APEX                                        |
| Expected Value Source         | ExpectedValueSource\_\_c         | (omit from metadata)                                                                                                                                   | Not used; the Comparison Query is the expected side                                    |
| Expected Fixed Value          | ExpectedFixedValue\_\_c          | (omit from metadata)                                                                                                                                   | Not used; the Comparison Query is the expected side                                    |
| Expected Record Formula       | ExpectedRecordFormula\_\_c       | (omit from metadata)                                                                                                                                   | Not used; the Comparison Query is the expected side                                    |
| Expected Currency ISO Code    | ExpectedCurrencyIsoCode\_\_c     | (omit from metadata)                                                                                                                                   | Not used; the Comparison Query is the expected side                                    |
| Publish User Result Event     | PublishUserResultEvent\_\_c      | (unchecked)                                                                                                                                            | Default is false; no platform events                                                   |

## What users see

| Result             | Card display                                                                                                                                                                                                                                                                          |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PASS               | Title: "Open Opportunities Have Products" / Subtitle: "Passes" / Found: "5 open Opportunities" / Expected: "5 open Opportunities with products"                                                                                                                                       |
| FAIL               | Title: "Open Opportunities Have Products" / Subtitle: "Fails" with severity "⚠ Warning" / Found: "8 open Opportunities" / Expected: "6 open Opportunities with products" / Message: "{!record.Name} has 2 open Opportunities with no products." / Action button: "View Opportunities" |
| SKIPPED            | Title: "Open Opportunities Have Products" / Subtitle: "Skipped" / Message: "{!record.Name} has no open Opportunities to check."                                                                                                                                                       |
| UNABLE_TO_EVALUATE | Title: "Open Opportunities Have Products" / Subtitle: "Unable to evaluate" / Message: "Check that you have Read access to the Opportunity and OpportunityLineItem objects and their IsClosed and OpportunityId fields."                                                               |
| ERROR              | Title: "Open Opportunities Have Products" / Subtitle: "Error" / Message: A system error occurred while evaluating this check. Contact your administrator.                                                                                                                             |

## Permissions and sharing assumptions

An administrator must verify that the running user (sales operations personnel) has:

- **Read access to Opportunity object**: Required to query open Opportunities.
- **Read access to OpportunityLineItem object**: Required to query Opportunity Products and count distinct covered Opportunities.
- **Read access to Opportunity.IsClosed field**: Required by both the applicability query and the source query to filter for open Opportunities.
- **Read access to Opportunity.AccountId field**: Required by both queries to relate the Opportunity to the Account record being checked.
- **Read access to OpportunityLineItem.OpportunityId field**: Required by the comparison query to count distinct Opportunities that have products.
- **Read access to Account.Name field**: Required to render the merge token {!record.Name} in messages.

If the running user lacks any of these, the Check returns UNABLE_TO_EVALUATE with the message naming the missing access.

## Sandbox test cases

### Test 1: Account with open Opportunities, all with products (PASS)

**Setup:**

- Create an Account named "Test Account 1".
- Create three open Opportunities (IsClosed = false) on the Account named "Opp 1", "Opp 2", "Opp 3".
- Create at least one OpportunityLineItem on each Opportunity.

**Action:**

- Open the Test Account 1 record.
- Open the "Account Opportunity Products" Check Set card.
- Click Run.

**Expected result:**

- The Check returns PASS.
- Found: "3 open Opportunities"
- Expected: "3 open Opportunities with products"
- No failure message.

---

### Test 2: Account with open Opportunities, some without products (FAIL)

**Setup:**

- Create an Account named "Test Account 2".
- Create four open Opportunities (IsClosed = false) on the Account named "Opp 1", "Opp 2", "Opp 3", "Opp 4".
- Create at least one OpportunityLineItem on "Opp 1", "Opp 2", and "Opp 3"; leave "Opp 4" with no products.

**Action:**

- Open the Test Account 2 record.
- Open the "Account Opportunity Products" Check Set card.
- Click Run.

**Expected result:**

- The Check returns FAIL with Warning severity.
- Found: "4 open Opportunities"
- Expected: "3 open Opportunities with products"
- Failure message: "Test Account 2 has 1 open Opportunity with no products."
- Action button "View Opportunities" links to the Account's Opportunities related list.

---

### Test 3: Account with no open Opportunities (SKIP)

**Setup:**

- Create an Account named "Test Account 3".
- Create one or more closed Opportunities (IsClosed = true) on the Account, or create no Opportunities at all.

**Action:**

- Open the Test Account 3 record.
- Open the "Account Opportunity Products" Check Set card.
- Click Run.

**Expected result:**

- The Check returns SKIPPED.
- Message: "Test Account 3 has no open Opportunities to check."

---

### Test 4: Missing field access (UNABLE_TO_EVALUATE)

**Setup:**

- Create an Account named "Test Account 4" with open Opportunities and products.
- Create a Permission Set that grants Read access to the Opportunity and OpportunityLineItem objects but denies Read access to the Opportunity.IsClosed field.
- Assign the Permission Set to a test user.

**Action:**

- Log in as the test user.
- Open the Test Account 4 record.
- Open the "Account Opportunity Products" Check Set card.
- Click Run.

**Expected result:**

- The Check returns UNABLE_TO_EVALUATE.
- Message: "Check that you have Read access to the Opportunity and OpportunityLineItem objects and their IsClosed and OpportunityId fields."

---

### Test 5: Plural suffix handling in messages (PASS, edge case)

**Setup:**

- Create an Account named "Single Opp Account".
- Create one open Opportunity (IsClosed = false) on the Account.
- Create one OpportunityLineItem on that Opportunity.

**Action:**

- Open the Single Opp Account record.
- Open the "Account Opportunity Products" Check Set card.
- Click Run.

**Expected result:**

- The Check returns PASS.
- Found: "1 open Opportunity" (singular; no "s")
- Expected: "1 open Opportunity with products" (singular)
- The merge token {!rhcResult.foundValuePluralSuffix} correctly renders as blank (no suffix) for one record.

---

### Test 6: Plural suffix handling in failure messages (FAIL, edge case)

**Setup:**

- Create an Account named "Multiple Opp Account".
- Create three open Opportunities (IsClosed = false) on the Account.
- Create products on two Opportunities; leave one with no products.

**Action:**

- Open the Multiple Opp Account record.
- Open the "Account Opportunity Products" Check Set card.
- Click Run.

**Expected result:**

- The Check returns FAIL.
- Failure message: "Multiple Opp Account has 1 open Opportunity with no products." (singular, because only one is missing)
- The merge token {!rhcResult.foundValuePluralSuffix} correctly renders as blank (no suffix) for one record.

---

### Test 7: Large Opportunity count (boundary)

**Setup:**

- Create an Account named "Large Account".
- Create 205 open Opportunities (IsClosed = false) on the Account.
- Create products on 200 of them; leave 5 with no products.

**Action:**

- Open the Large Account record.
- Open the "Account Opportunity Products" Check Set card.
- Click Run.

**Expected result:**

- The Check respects MaxQueryRows\_\_c = 200.
- Both queries return their first 200 rows; the 201st and beyond are not counted.
- The Check may return PASS or FAIL depending on whether the comparison and source queries both respect the row limit consistently.
- This boundary test confirms that the row limit is enforced and understood by the administrator.

## Fields and values that still require confirmation in Salesforce Setup

None. The requirement supplies all necessary API names, field paths, and business logic. No field needs a placeholder.
