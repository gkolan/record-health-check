# Check Set fields (`Record_Health_Check_Set__mdt`)

This page preserves the exact contract for every Check Set field: the label shown in Setup, API
name, type, default, allowed values, and runtime behavior. Use the short decision path first, then
open an individual field only when you need its exact details.

## Make the Check Set decisions

| Decision | Ask | Configure |
| --- | --- | --- |
| Where does this card belong? | Which record-page object will it evaluate? | [Object](#object-objectapiname__c) |
| When should checks run? | Automatically, on request, or both? | [When Checks Run](#when-checks-run-cardrunmode__c) |
| What should users see first? | All checks immediately, or a summary they can reveal? | [Reveal Mode](#reveal-mode-cardrevealmode__c) |
| How much result detail is useful? | Should Found, Expected, passed, and skipped results always appear, appear conditionally, or stay hidden? | [Found/Expected Display](#foundexpected-display-foundexpecteddisplay__c), [Passed Checks](#passed-checks-passedchecksdisplay__c), and [Skipped Checks](#skipped-checks-skippedchecksdisplay__c) |
| What happens during a problem? | Should later checks continue, and do administrators temporarily need diagnostics? | [Stop after a system error](#stop-after-a-system-error-stoponsystemerror__c) and [Show Diagnostics](#show-diagnostics-showdiagnostics__c) |
| Does another process need the completed run? | Should a deliberate run publish one summary event? | [Publish User Run Event](#publish-user-run-event-publishuserrunevent__c) |
| Should Framework errors publish automatically? | Keep the default error-event stream, or opt this Check Set out? | [Publish Error Log Event](#publish-error-log-event-publisherrorlogevent__c) |

For the complete creation flow, use [Create your first Rule](../installation/03-create-your-first-rule.md).

## Field index

| Setup label | API name | Group |
| --- | --- | --- |
| [Developer Name](#developer-name-developername) | `DeveloperName` | Identity and execution |
| [Label](#label-masterlabel) | `MasterLabel` | Identity and execution |
| [Object](#object-objectapiname__c) | `ObjectApiName__c` | Identity and execution |
| [Active](#active-isactive__c) | `IsActive__c` | Identity and execution |
| [Card Title](#card-title-cardtitle__c) | `CardTitle__c` | Card text |
| [Card Subtitle](#card-subtitle-cardsubtitle__c) | `CardSubtitle__c` | Card text |
| [When Checks Run](#when-checks-run-cardrunmode__c) | `CardRunMode__c` | Run behavior |
| [Reveal Mode](#reveal-mode-cardrevealmode__c) | `CardRevealMode__c` | Run behavior |
| [Stop after a system error](#stop-after-a-system-error-stoponsystemerror__c) | `StopOnSystemError__c` | Run behavior |
| [Found/Expected Display](#foundexpected-display-foundexpecteddisplay__c) | `FoundExpectedDisplay__c` | Result display |
| [Passed Checks](#passed-checks-passedchecksdisplay__c) | `PassedChecksDisplay__c` | Result display |
| [Skipped Checks](#skipped-checks-skippedchecksdisplay__c) | `SkippedChecksDisplay__c` | Result display |
| [Show Diagnostics](#show-diagnostics-showdiagnostics__c) | `ShowDiagnostics__c` | Troubleshooting |
| [Publish User Run Event](#publish-user-run-event-publishuserrunevent__c) | `PublishUserRunEvent__c` | Lifecycle events |
| [Publish Error Log Event](#publish-error-log-event-publisherrorlogevent__c) | `PublishErrorLogEvent__c` | Error events |

## Read an individual field

| If you need to know… | Read these rows |
| --- | --- |
| What Salesforce calls it | Setup label and API name |
| Whether you must configure it | Always required and Default |
| What you can enter | Type, Capacity, and Allowed values |
| When it affects the Check Set | Used when |
| What users or the Framework experience | Description and Help text |
| What a realistic value looks like | Example |

## 1. Identity and execution

### Developer Name (`DeveloperName`)

| Attribute | Value |
| --- | --- |
| Setup label | **Developer Name** |
| API name | `DeveloperName` |
| Type | Text |
| Capacity | 40 characters |
| Always required | Yes |
| Default | No default |
| Used when | Every Check Set; Lightning, Apex, Flow, and events use this stable name. |
| Description | Stable API identifier for the Custom Metadata record. |
| Help text | Used by the Lightning component, Apex, Flow, and lifecycle events. |
| Allowed values | Any value valid for the field type |
| Example | `Account_Readiness` |

### Label (`MasterLabel`)

| Attribute | Value |
| --- | --- |
| Setup label | **Label** |
| API name | `MasterLabel` |
| Type | Text |
| Capacity | 80 characters |
| Always required | Yes |
| Default | No default |
| Used when | Every Check Set; identifies the Custom Metadata record in Setup. |
| Description | Setup list label for the Custom Metadata record. |
| Help text | This is separate from the Card Title shown to users. |
| Allowed values | Any value valid for the field type |
| Example | `Account readiness` |

### Object (`ObjectApiName__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Object** |
| API name | `ObjectApiName__c` |
| Type | Text |
| Capacity | 80 characters |
| Always required | Yes |
| Default | No default |
| Used when | Every Check Set; must match the object of the Lightning record page and evaluated record. |
| Description | <p>The API name of the object this Check Set runs on. Required. It must exactly match the object of the record page where you place the component, or the component shows nothing.</p><p>Example: Account, Opportunity, or a custom object like `SBQQ__Quote__c`.</p> |
| Help text | <p>Required. The object's API name, e.g. Account or Opportunity. Must match the record page exactly, or the component shows nothing.</p> |
| Allowed values | Any value valid for the field type |
| Example | `Account` |

### Active (`IsActive__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Active** |
| API name | `IsActive__c` |
| Type | Checkbox |
| Capacity | Checkbox |
| Always required | No |
| Default | **Checked**: `true` |
| Used when | Every Check Set; uncheck to disable the entire Set. |
| Description | <p>When checked, this Check Set is live. When unchecked, the entire Check Set is disabled without deleting metadata - no checks load or run, and the component shows a "Health Check Unavailable" message.</p> |
| Help text | <p>Checked = the Check Set is live. Uncheck to disable the whole set without deleting it (users see "Health Check Unavailable").</p> |
| Allowed values | **Checked**: `true`<br>**Unchecked**: `false` |


## 2. Card text

### Card Title (`CardTitle__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Card Title** |
| API name | `CardTitle__c` |
| Type | Text |
| Capacity | 255 characters |
| Always required | Yes |
| Default | No default |
| Used when | Every Check Set; displayed at the top of the card. |
| Description | <p>The title shown at the top of the Record Health Check card on the Lightning record page. Required. Example: "Account Data Quality".</p> |
| Help text | Required. The big title at the top of the card, e.g. "Account Data Quality". |
| Allowed values | Any value valid for the field type |
| Example | `Account readiness` |

### Card Subtitle (`CardSubtitle__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Card Subtitle** |
| API name | `CardSubtitle__c` |
| Type | Text |
| Capacity | 255 characters |
| Always required | No |
| Default | No default |
| Used when | Optional for every Check Set; displayed below Card Title. |
| Description | <p>Optional one-line text shown under the "Card Title" to explain what the card checks. Keep it to a sentence or two.</p> |
| Help text | Optional. A short line under the "Card Title" explaining what the card checks. |
| Allowed values | Any value valid for the field type |
| Example | `Review data quality before the weekly pipeline meeting.` |


## 3. Run behavior

### When Checks Run (`CardRunMode__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **When Checks Run** |
| API name | `CardRunMode__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | **When the user clicks Run**: `RUN_ON_REQUEST` |
| Used when | Every Check Set; controls automatic page-load versus user-requested runs. |
| Description | <p>Decides whether checks run on their own when the page opens, or only after the user clicks Run.</p><ul><li>"When the page opens" runs them automatically on load.</li><li>"When the user clicks Run" shows a Run button and runs nothing until it is clicked - choose this for checks that are slow or should run on demand.</li></ul><p>Defaults to "When the user clicks Run".</p> |
| Help text | <ul><li>"When the page opens" = checks run automatically on load.</li><li>"When the user clicks Run" (default) = a Run button appears; nothing runs until clicked.</li></ul><p>Use the latter for heavy checks.</p> |
| Allowed values | **When the page opens**: `RUN_ON_LOAD`<br>**When the user clicks Run**: `RUN_ON_REQUEST` |

### Reveal Mode (`CardRevealMode__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Reveal Mode** |
| API name | `CardRevealMode__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | **One by one**: `ONE_BY_ONE` |
| Used when | Every Check Set; controls when eligible rows become visible. |
| Description | <p>Cosmetic only - same checks, same order, same outcomes either way. It does not change when checks run; that is controlled by "When Checks Run".</p><ul><li>"All at once" lists every eligible check on load (pending), then fills in each result in place.</li><li>"One by one" shows no rows until the run starts, then adds each check as it is reached.</li></ul><p>Defaults to "One by one".</p> |
| Help text | <p>Cosmetic only. "All at once" = every check listed on load, then results fill in.</p><p>"One by one" (default) = checks appear as the run reaches them. Doesn't change when checks run.</p> |
| Allowed values | **All at once**: `ALL_AT_ONCE`<br>**One by one**: `ONE_BY_ONE` |

### Stop after a system error (`StopOnSystemError__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Stop after a system error** |
| API name | `StopOnSystemError__c` |
| Type | Checkbox |
| Capacity | Checkbox |
| Always required | No |
| Default | **Unchecked**: `false` |
| Used when | Optional for every Check Set; affects unexpected system errors, not `FAIL` or `SKIPPED`. |
| Description | <p>When checked, the run stops as soon as a Rule reaches `ERROR`. It does not stop for `FAIL`, `SKIPPED`, or `UNABLE_TO_EVALUATE`; those are completed business, applicability, or expected unable-to-decide outcomes, so later Rules can still provide useful evidence.</p><p>Leave unchecked when independent Rules should continue after one unexpected system problem. Check it when later Rules depend on a healthy technical path or continuing could repeat the same failing operation. Sequential Lightning evaluation is required when this option is checked so the component can see each result before starting the next Rule.</p> |
| Help text | <p>Checked = stop the whole run on an unexpected system error. Does not stop on a normal Fail or Skip.</p><p>Off by default.</p> |
| Allowed values | **Checked**: `true`<br>**Unchecked**: `false` |


## 4. Result display

### Found/Expected Display (`FoundExpectedDisplay__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Found/Expected Display** |
| API name | `FoundExpectedDisplay__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | **On demand**: `ON_DEMAND` |
| Used when | Every Check Set; controls when available Found and Expected values appear. |
| Description | <p>Controls when users see the Found and Expected values for each check in this Check Set.</p><ul><li>"On demand" lets users expand a check to see its values, and failed checks also show their values inline.</li><li>"Failed checks only" shows values only on failed checks, keeping passing checks compact.</li><li>"Every check" shows values inline on every check where values are available.</li></ul><p>Defaults to "On demand".</p> |
| Help text | <p>When Found/Expected values show.</p><ul><li>"On demand" (default) = expand to see; failed checks show inline.</li><li>"Failed checks only" = only on failures.</li><li>"Every check" = inline everywhere available.</li></ul> |
| Allowed values | **On demand**: `ON_DEMAND`<br>**Failed checks only**: `FAILURES_ONLY`<br>**Every check**: `ALL_ROWS` |

### Passed Checks (`PassedChecksDisplay__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Passed Checks** |
| API name | `PassedChecksDisplay__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | **Show each check**: `SHOW_EACH_CHECK` |
| Used when | Every Check Set; controls whether passing rows or only their count appear. |
| Description | <p>Controls how checks that Pass appear.</p><ul><li>"Show each check" lists every passed check.</li><li>"Show count only" removes passed checks from the list; their count still appears in the summary bar at the bottom of the card.</li></ul><p>Defaults to "Show each check".</p> |
| Help text | <p>How passing checks appear.</p><ul><li>"Show each check" (default) = list them all.</li><li>"Show count only" = hide from the list; the count still shows in the summary bar.</li></ul> |
| Allowed values | **Show each check**: `SHOW_EACH_CHECK`<br>**Show count only**: `SHOW_COUNT_ONLY` |

### Skipped Checks (`SkippedChecksDisplay__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Skipped Checks** |
| API name | `SkippedChecksDisplay__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | **Show each check**: `SHOW_EACH_CHECK` |
| Used when | Every Check Set; controls whether skipped rows or only their count appear. |
| Description | <p>Controls how checks that were not run appear. This includes checks that do not apply to the record and checks whose prerequisite did not pass.</p><ul><li>"Show each check" lists every skipped check.</li><li>"Show count only" removes skipped checks from the list; their count still appears in the summary bar at the bottom of the card.</li></ul><p>Defaults to "Show each check".</p> |
| Help text | <p>How checks that were not run appear.</p><ul><li>"Show each check" (default) lists them.</li><li>"Show count only" hides the rows while keeping the summary count.</li></ul> |
| Allowed values | **Show each check**: `SHOW_EACH_CHECK`<br>**Show count only**: `SHOW_COUNT_ONLY` |


## 5. Troubleshooting

### Show Diagnostics (`ShowDiagnostics__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Show Diagnostics** |
| API name | `ShowDiagnostics__c` |
| Type | Checkbox |
| Capacity | Checkbox |
| Always required | No |
| Default | **Unchecked**: `false` |
| Used when | Optional for every Check Set; detail also requires the View Diagnostics Custom Permission. |
| Description | <p>Enables authorized troubleshooting details on the card and in the browser console. A user sees those details only when this field is checked and the user has the "Record Health Check View Diagnostics" Custom Permission.</p><p>Other users continue to see the standard card. Enable it only while diagnosing a configuration or evaluation problem.</p> |
| Help text | <p>Troubleshooting only. Details appear only to users with "Record Health Check View Diagnostics".</p><p>Leave unchecked during normal use.</p> |
| Allowed values | **Checked**: `true`<br>**Unchecked**: `false` |


## 6. Lifecycle events

### Publish User Run Event (`PublishUserRunEvent__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Publish User Run Event** |
| API name | `PublishUserRunEvent__c` |
| Type | Checkbox |
| Capacity | Checkbox |
| Always required | No |
| Default | **Unchecked**: `false` |
| Used when | Optional for every Check Set; affects deliberate runs only and defaults off. |
| Description | <p>Publishes one Check Set Run event after a deliberately initiated run completes. Page-load runs never publish because opening or refreshing a record is passive navigation and could otherwise consume event allocations or repeatedly trigger subscribers.</p><p>Leave unchecked until a reviewed subscriber needs an after-commit summary. Publication consumes the org's Platform Event allocation and does not confirm that the subscriber processed the event.</p> |
| Help text | <p>Publish a completion event for deliberate API, Flow, scheduled, batch, or user-requested runs. Page-load runs never publish.</p> |
| Allowed values | **Checked**: `true`<br>**Unchecked**: `false` |


## 7. Error events

### Publish Error Log Event (`PublishErrorLogEvent__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Publish Error Log Event** |
| API name | `PublishErrorLogEvent__c` |
| Type | Checkbox |
| Capacity | Checkbox |
| Always required | No |
| Default | **Checked**: `true` |
| Used when | Every Framework `ERROR` associated with this Check Set; defaults on and can be opted out. |
| Description | <p>Publishes a `Record_Health_Check_Log__e` event when the Framework records an `ERROR` for this Check Set.</p><p>Uncheck only when the org does not want this Check Set's error events. Salesforce debug-log output is unchanged. If the Check Set cannot be resolved, publication remains enabled so configuration failures stay observable.</p> |
| Help text | <p>Publish Framework ERROR logs as platform events.</p><p>Uncheck to disable error-log events for this Check Set.</p> |
| Allowed values | **Checked**: `true`<br>**Unchecked**: `false` |

## Related

- [Rule fields](02-fields-check-rule.md)
- [Create your first Rule](../installation/03-create-your-first-rule.md)
- [Configure Check Sets and Rules](../guides/03-configure-check-sets-and-rules.md)
