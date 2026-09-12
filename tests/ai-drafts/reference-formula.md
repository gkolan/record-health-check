# Draft: Billing Address Completeness Check for Account

## Plain-Language Summary

This Check verifies that all five billing address fields on an Account record are populated. It **passes** when all of these fields contain values:

- Billing Street
- Billing City
- Billing State
- Billing Postal Code
- Billing Country

It **fails** when any one or more of these fields are blank. The Check **never skips** because it applies to every Account record in your organization.

---

## Clarifying Questions

Before configuration, confirm:

1. **Check Set naming**: Propose MasterLabel as "Account Billing Address" and DeveloperName as "Account_Billing_Address". Confirm these are acceptable, or provide your preferred administrator-created names (without rhc\_\_ prefix).

2. **Check naming**: Propose MasterLabel as "Billing Address Completeness" and DeveloperName as "Billing_Address_Completeness". Confirm these are acceptable, or provide your preferred names.

3. **Card title and subtitle**: Propose CardTitle**c as "Account Billing Information" and CardSubtitle**c as "Verify all billing address fields are populated". Confirm these suit your requirements.

4. **Run button display**: Confirm you want the default "Run" and "Rerun" button labels with a refresh icon, or specify alternatives.

---

## Execution and result-delivery plan

- **Entry:** Lightning record card, running the complete Check Set synchronously when the user
  selects Run. The complete Set preserves any sibling prerequisite behavior added later.
- **Principal and scope:** The interactive Account user evaluates one Account with that user's
  sharing and object, field, and record access.
- **Exit:** The card displays the result and action. Platform Event publication remains off and no
  durable result history is required.
- **Failure and recovery:** Health statuses stay on the card. Unexpected browser or Apex failures
  follow administrator diagnostics and do not become business FAIL results.

---

## Check Set Configuration

| Setup Label              | API Field Name            | Proposed Value                                  | Why                                                                                 |
| ------------------------ | ------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------------------- |
| Label                    | MasterLabel               | Account Billing Address                         | Administrator-created name for this Check Set.                                      |
| Developer Name           | DeveloperName             | Account_Billing_Address                         | API identifier without rhc\_\_ prefix.                                              |
| Object                   | ObjectApiName\_\_c        | Account                                         | The record page where this card appears.                                            |
| Active                   | IsActive\_\_c             | false                                           | Keep the draft Check Set inactive until human sandbox review.                       |
| Card Title               | CardTitle\_\_c            | Account Billing Information                     | Names what this card covers for Account records.                                    |
| Card Subtitle            | CardSubtitle\_\_c         | Verify all billing address fields are populated | Explains the card's purpose to users.                                               |
| Card Heading Display     | CardHeadingDisplay\_\_c   | TITLE_AND_SUBTITLE                              | The default; show the title and subtitle independently of the Run button.           |
| When to run              | CardRunMode\_\_c          | RUN_ON_REQUEST                                  | Card runs when the user clicks Run, not on page load.                               |
| Reveal                   | CardRevealMode\_\_c       | ONE_BY_ONE                                      | The default; Checks appear one at a time.                                           |
| Summary display          | SummaryDisplay\_\_c       | BOTTOM                                          | Summary shows below the Checks.                                                     |
| Show passed Checks       | PassedChecksDisplay\_\_c  | SHOW_EACH_CHECK                                 | The default; passed Checks appear individually.                                     |
| Show skipped Checks      | SkippedChecksDisplay\_\_c | SHOW_EACH_CHECK                                 | The default; skipped Checks (if any) appear individually.                           |
| Show Found/Expected      | FoundExpectedDisplay\_\_c | ON_DEMAND                                       | The default; users click to see Found and Expected values.                          |
| Run button               | RunButtonDisplay\_\_c     | LABEL_AND_ICON                                  | The default; show both the label and icon.                                          |
| Run button label         | RunButtonLabel\_\_c       | Run                                             | Button text when the card is ready to run.                                          |
| Rerun button label       | RerunButtonLabel\_\_c     | Rerun                                           | Button text when a run has completed.                                               |
| Button icon              | RunButtonIcon\_\_c        | utility:check                                   | SLDS icon identifier; check-mark is appropriate for completeness.                   |
| Stop on error            | StopOnSystemError\_\_c    | false                                           | The default; do not halt the run on system errors.                                  |
| Show diagnostics         | ShowDiagnostics\_\_c      | false                                           | The default; hide formula and query text from users (sandbox troubleshooting only). |
| Publish user run events  | PublishUserRunEvent\_\_c  | false                                           | Not needed; no receiving automation.                                                |
| Publish error log events | PublishErrorLogEvent\_\_c | false                                           | Not needed; no receiving automation.                                                |

---

## Check Configuration

| Setup Label                 | API Field Name                  | Proposed Value                                                                                                                                                                                                                   | Why                                                                               |
| --------------------------- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Check Set                   | Record_Health_Check_Set\_\_c    | Account_Billing_Address                                                                                                                                                                                                          | Links this Check to the Check Set named above.                                    |
| Label                       | MasterLabel                     | Billing Address Completeness                                                                                                                                                                                                     | Name for this Check; appears in the Check Set.                                    |
| Developer Name              | DeveloperName                   | Billing_Address_Completeness                                                                                                                                                                                                     | API identifier without rhc\_\_ prefix.                                            |
| Check title                 | CheckTitle\_\_c                 | Complete Billing Address                                                                                                                                                                                                         | States the claim being tested; reads as a result on the card.                     |
| Check description           | CheckDescription\_\_c           | Passes when all five billing address fields are populated.                                                                                                                                                                       | Explains what the Check verifies and when it passes.                              |
| Evaluation type             | EvaluationType\_\_c             | FORMULA                                                                                                                                                                                                                          | Evaluates a Salesforce formula on the record.                                     |
| Category                    | Category\_\_c                   | COMPLETENESS                                                                                                                                                                                                                     | Groups this Check in the card summary.                                            |
| Severity                    | FailureSeverity\_\_c            | WARNING                                                                                                                                                                                                                          | Sets the priority when the Check fails.                                           |
| Order                       | EvaluationOrder\_\_c            | 100                                                                                                                                                                                                                              | The default presentation order; prerequisite dependencies determine scheduling.   |
| Active                      | IsActive\_\_c                   | false                                                                                                                                                                                                                            | Keep the draft Check inactive until human sandbox review.                         |
| Failure message             | FailureMessage\_\_c             | {!record.Name fallback="this record"} is missing part of its billing address.                                                                                                                                                    | Tells the user what is wrong.                                                     |
| Unable to evaluate message  | UnableToEvaluateMessage\_\_c    | Check that you have Read access to Account and all five billing address fields (Billing Street, Billing City, Billing State, Billing Postal Code, Billing Country).                                                              | Explains why the Check could not run if access is blocked.                        |
| Fix message                 | FixMessage\_\_c                 | Edit the Account and populate all five billing address fields: Street, City, State, Postal Code, and Country.                                                                                                                    | Tells the user how to fix the problem.                                            |
| Action label                | ActionLabel\_\_c                | Edit Account                                                                                                                                                                                                                     | Button text for the action link.                                                  |
| Action URL                  | ActionUrl\_\_c                  | /lightning/r/Account/{!record.Id}/edit                                                                                                                                                                                           | Opens the Account edit page in Lightning.                                         |
| Applies when                | ApplicabilityMode\_\_c          | ALL_RECORDS                                                                                                                                                                                                                      | The default; the Check applies to every Account.                                  |
| Applicability message       | ApplicabilityNotMetMessage\_\_c | (blank)                                                                                                                                                                                                                          | Not used; ApplicabilityMode is ALL_RECORDS.                                       |
| Prerequisite Check          | PrerequisiteCheck\_\_c          | (blank)                                                                                                                                                                                                                          | No prerequisite; this Check runs independently.                                   |
| Found/Expected display mode | ComparisonDisplayMode\_\_c      | AUTOMATIC                                                                                                                                                                                                                        | The default; show Found and Expected together.                                    |
| Display value format        | DisplayValueFormat\_\_c         | AUTO                                                                                                                                                                                                                             | The default; no special number or date formatting.                                |
| Display Found text          | DisplayFoundText\_\_c           | (omit from metadata)                                                                                                                                                                                                             | FORMULA type Checks use DisplayFoundFormula\_\_c instead.                         |
| Display Expected text       | DisplayExpectedText\_\_c        | (omit from metadata)                                                                                                                                                                                                             | FORMULA type Checks use DisplayExpectedFormula\_\_c instead.                      |
| Publish result events       | PublishUserResultEvent\_\_c     | false                                                                                                                                                                                                                            | Not needed; no receiving automation.                                              |
| Pass condition (formula)    | PassConditionFormula\_\_c       | AND(NOT(ISBLANK(BillingStreet)), NOT(ISBLANK(BillingCity)), NOT(ISBLANK(BillingState)), NOT(ISBLANK(BillingPostalCode)), NOT(ISBLANK(BillingCountry)))                                                                           | Returns true when all five address fields are populated; false when any is blank. |
| Formula result type         | FormulaResultType\_\_c          | AUTO                                                                                                                                                                                                                             | The portable field default; Preview verifies the Boolean Pass Condition.          |
| Display Found formula       | DisplayFoundFormula\_\_c        | IF(AND(NOT(ISBLANK(BillingStreet)), NOT(ISBLANK(BillingCity)), NOT(ISBLANK(BillingState)), NOT(ISBLANK(BillingPostalCode)), NOT(ISBLANK(BillingCountry))), "All billing address fields populated", "Billing address incomplete") | Shows the user what was found: either complete or incomplete.                     |
| Display Expected formula    | DisplayExpectedFormula\_\_c     | "All billing address fields populated"                                                                                                                                                                                           | Shows the user what is expected.                                                  |
| Source query                | SourceQuery\_\_c                | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| Source query field          | SourceQueryField\_\_c           | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| Comparison query            | ComparisonQuery\_\_c            | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| Comparison query field      | ComparisonQueryField\_\_c       | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| Query result handling       | QueryResultHandling\_\_c        | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| Comparison operator         | ComparisonOperator\_\_c         | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| Expected value source       | ExpectedValueSource\_\_c        | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| Expected fixed value        | ExpectedFixedValue\_\_c         | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| Expected record formula     | ExpectedRecordFormula\_\_c      | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| Expected currency code      | ExpectedCurrencyIsoCode\_\_c    | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| Find in list formula        | FindInListFormula\_\_c          | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| No rows result              | NoRowsResult\_\_c               | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| Empty value handling        | EmptyValueHandling\_\_c         | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| Max query rows              | MaxQueryRows\_\_c               | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run queries.                                 |
| Apex class                  | ApexClass\_\_c                  | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run Apex.                                    |
| Apex parameters (JSON)      | ApexParametersJson\_\_c         | (omit from metadata)                                                                                                                                                                                                             | Not used; FORMULA type Checks do not run Apex.                                    |

---

## What Users See

**PASS**

- Card row: "Complete Billing Address" with a green checkmark.
- Found text: "All billing address fields populated"
- Expected text: "All billing address fields populated"

**FAIL**

- Card row: "Complete Billing Address" with an orange warning badge.
- Message: "{!record.Name fallback="this record"} is missing part of its billing address."
- Found text: "Billing address incomplete"
- Expected text: "All billing address fields populated"
- Action button: "Edit Account" (opens the Account record in edit mode).
- Fix guidance: "Edit the Account and populate all five billing address fields: Street, City, State, Postal Code, and Country."

**SKIPPED**

- Never; this Check applies to every Account.

**UNABLE_TO_EVALUATE**

- Card row: "Complete Billing Address" with a gray "unable to evaluate" badge.
- Message: "Check that you have Read access to Account and all five billing address fields (Billing Street, Billing City, Billing State, Billing Postal Code, Billing Country)."
- Occurs if the running user lacks Read access to the Account object or any of the five billing address fields.

**ERROR**

- Card row: "Complete Billing Address" with a red error badge.
- Message: A system error details the failure. No user action can resolve this; the running user's administrator must investigate.

---

## Permissions and Sharing Assumptions

- **Running user must have Read access** to the Account object and to all five billing address fields: BillingStreet, BillingCity, BillingState, BillingPostalCode, and BillingCountry. If any are blocked, the Check returns UNABLE_TO_EVALUATE.
- **Sharing model**: The Check evaluates only the current Account record, so it respects the running user's existing sharing and visibility. If the user can view the record, they can run this Check.
- **Billing specialists** are expected to have Read access to at least Account and Write access to run Edits through the action button. Confirm that their permission sets grant Read access to all five billing address fields before deploying.
- **Field-level security (FLS)**: All five billing address fields must be visible to the running user's profile or permission set. If any field is hidden by FLS, the Check returns UNABLE_TO_EVALUATE.

---

## Sandbox Test Cases

### Test 1: All Billing Address Fields Populated (PASS)

- **Setup**: Create an Account with:
  - BillingStreet: "123 Main Street"
  - BillingCity: "San Francisco"
  - BillingState: "CA"
  - BillingPostalCode: "94105"
  - BillingCountry: "United States"
- **Action**: Run the Check.
- **Expected**: PASS. Found: "All billing address fields populated". Expected: "All billing address fields populated". No action button shown.

### Test 2: One Billing Address Field Blank (FAIL)

- **Setup**: Create an Account with BillingStreet, BillingCity, BillingState, and BillingCountry populated, but leave BillingPostalCode blank.
- **Action**: Run the Check.
- **Expected**: FAIL (WARNING severity). Message: "{!Account Name} is missing part of its billing address." Found: "Billing address incomplete". Fix message: "Edit the Account and populate all five billing address fields: Street, City, State, Postal Code, and Country." Edit Account button visible and functional.

### Test 3: Multiple Billing Address Fields Blank (FAIL)

- **Setup**: Create an Account with only BillingCity populated; leave BillingStreet, BillingState, BillingPostalCode, and BillingCountry blank.
- **Action**: Run the Check.
- **Expected**: FAIL (WARNING severity). Same messages and action button as Test 2.

### Test 4: All Billing Address Fields Blank (FAIL)

- **Setup**: Create an Account with all five billing address fields blank.
- **Action**: Run the Check.
- **Expected**: FAIL (WARNING severity). Same messages and action button as Test 2.

### Test 5: User Without Read Access to a Billing Address Field (UNABLE_TO_EVALUATE)

- **Setup**: Create a permission set that grants Read access to Account but hides one of the five billing address fields (e.g., BillingPostalCode). Assign this permission set to a test user along with their other permissions.
- **Action**: Have the test user run the Check on an Account where all billing address fields are populated.
- **Expected**: UNABLE_TO_EVALUATE. Message: "Check that you have Read access to Account and all five billing address fields (Billing Street, Billing City, Billing State, Billing Postal Code, Billing Country)."

### Test 6: User Without Read Access to Account Object (UNABLE_TO_EVALUATE)

- **Setup**: Create a permission set that grants no Read access to Account. Assign this permission set to a test user.
- **Action**: Attempt to access an Account record detail page.
- **Expected**: The user cannot see the Account record or the Check Set card (visibility is blocked before the Check runs).

### Test 7: Action Button Opens Edit Page

- **Setup**: Create an Account with one or more billing address fields blank.
- **Action**: Run the Check, observe FAIL, and click "Edit Account".
- **Expected**: The browser navigates to /lightning/r/Account/{!Account.Id}/edit. The Account edit page opens with all fields editable.

---

## Fields and Values Requiring Confirmation in Salesforce Setup

1. **Check Set DeveloperName**: Proposed "Account_Billing_Address". Confirm this API name is available and acceptable.
2. **Check DeveloperName**: Proposed "Billing_Address_Completeness". Confirm this API name is available and acceptable.
3. **CardTitle\_\_c**: Proposed "Account Billing Information". Confirm the card title suits your business language and is 255 characters or shorter.
4. **CardSubtitle\_\_c**: Proposed "Verify all billing address fields are populated". Confirm this explains the card's purpose or provide alternative wording.
5. **RunButtonIcon\_\_c**: Proposed "utility:check". Confirm that this icon (a checkmark) is appropriate, or choose an alternative SLDS icon in category:name form (e.g., utility:refresh, utility:search).

---

**This proposal is submitted for review and is not ready for production deployment. Please validate the formulas, API names, and messages with your organization's billing specialist team and your Salesforce administrator before saving to Custom Metadata.**
