# Check Set fields (**Record Health Check Set** (`Record_Health_Check_Set__mdt`))

> [!NOTE]
> On this page, look up every Check Set field by Setup label or API name and verify its type,
> default, allowed values, and runtime behavior.

This page preserves the exact contract for every Check Set field: the label shown in Setup, API
name, type, default, allowed values, and runtime behavior. Use the short decision path first, then
open an individual field only when you need its exact details.

## Make the Check Set decisions

| Decision | Ask | Configure |
| --- | --- | --- |
| Where does this card belong? | Which record-page object will it evaluate? | [Object](#object-objectapiname__c) |
| When should checks run? | Automatically, on request, or both? | [When Checks Run](#when-checks-run-cardrunmode__c) |
| How should the run action look? | Should users see a labeled button, a compact icon, or no action? | [Run Button Display](#run-button-display-runbuttondisplay__c), [Run Button Label](#run-button-label-runbuttonlabel__c), [Rerun Button Label](#rerun-button-label-rerunbuttonlabel__c), and [Run Button Icon](#run-button-icon-runbuttonicon__c) |
| What should users see first? | All checks immediately, or a summary they can reveal? | [Reveal Mode](#reveal-mode-cardrevealmode__c) |
| How much result detail is useful? | Should Found, Expected, passed, and skipped results always appear, appear conditionally, or stay hidden? | [Found/Expected Display](#foundexpected-display-foundexpecteddisplay__c), [Passed Checks](#passed-checks-passedchecksdisplay__c), and [Skipped Checks](#skipped-checks-skippedchecksdisplay__c) |
| What happens during a problem? | Should later checks continue, and do administrators temporarily need diagnostics? | [Stop after a system error](#stop-after-a-system-error-stoponsystemerror__c) and [Show Diagnostics](#show-diagnostics-showdiagnostics__c) |
| Does another process need the completed run? | Should a deliberate run publish one summary event? | [Publish User Run Event](#publish-user-run-event-publishuserrunevent__c) |
| Should Framework errors publish automatically? | Keep the default error-event stream, or opt this Check Set out? | [Publish Error Log Event](#publish-error-log-event-publisherrorlogevent__c) |

For the complete creation flow, use [Create your first Check](../installation/create-your-first-check.md).

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
| [Run Button Display](#run-button-display-runbuttondisplay__c) | `RunButtonDisplay__c` | Run button |
| [Run Button Label](#run-button-label-runbuttonlabel__c) | `RunButtonLabel__c` | Run button |
| [Rerun Button Label](#rerun-button-label-rerunbuttonlabel__c) | `RerunButtonLabel__c` | Run button |
| [Run Button Icon](#run-button-icon-runbuttonicon__c) | `RunButtonIcon__c` | Run button |
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
| Description | <p>Decides whether checks run on their own when the page opens, or only after the user clicks Run.</p><ul><li>"When the page opens" runs automatically and still offers Rerun after results appear unless Run Button Display is Hide.</li><li>"When the user clicks Run" shows a Run button and runs nothing until it is clicked.</li></ul><p>Defaults to "When the user clicks Run".</p> |
| Help text | <ul><li>"When the page opens" = run on load, then offer Rerun unless hidden.</li><li>"When the user clicks Run" (default) = wait for Run.</li></ul><p>Hide is valid only with page-open runs.</p> |
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
| Description | <p>When checked, the run stops as soon as a Check reaches `ERROR`. It does not stop for `FAIL`, `SKIPPED`, or `UNABLE_TO_EVALUATE`; those are completed business, applicability, or expected unable-to-decide outcomes, so later Checks can still provide useful evidence.</p><p>Leave unchecked when independent Checks should continue after one unexpected system problem. Check it when later Checks depend on a healthy technical path or continuing could repeat the same failing operation. Sequential Lightning evaluation is required when this option is checked so the component can see each result before starting the next Check.</p> |
| Help text | <p>Checked = stop the whole run on an unexpected system error. Does not stop on a normal Fail or Skip.</p><p>Off by default.</p> |
| Allowed values | **Checked**: `true`<br>**Unchecked**: `false` |


## 4. Run button

### Run Button Display (`RunButtonDisplay__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Run Button Display** |
| API name | `RunButtonDisplay__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | **Label and icon**: `LABEL_AND_ICON` |
| Used when | Every Check Set; controls the Run and Rerun action's visible content. **Hide** removes the action area so the title can use that space. Page refresh can reevaluate an automatic card but cannot publish user-run lifecycle events. |
| Description | Controls whether and how the Run/Rerun control appears in the card header. Hide is supported when checks run on page load; a manual Check Set must keep a visible Run control. |
| Help text | Choose label and icon, label only, icon only, or Hide. Hide requires When Checks Run to be When the page opens. |
| Allowed values | **Label and icon**: `LABEL_AND_ICON`<br>**Label only**: `LABEL_ONLY`<br>**Icon only**: `ICON_ONLY`<br>**Hide**: `HIDE` |
| Example | `LABEL_AND_ICON` |

### Run Button Label (`RunButtonLabel__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Run Button Label** |
| API name | `RunButtonLabel__c` |
| Type | Text |
| Capacity | 80 characters |
| Always required | No |
| Default | Blank; the component uses `Run` |
| Used when | The initial Run action is available. The text appears visibly in a labeled mode and provides the accessible name in **Icon only** mode. |
| Description | Optional plain-text label for the Run control before the first completed run. Blank uses Run. |
| Help text | Enter up to 80 characters. Blank uses "Run". This text also names an icon-only Run control for assistive technology. |
| Allowed values | Any value valid for the field type |
| Example | `Check now` |

### Rerun Button Label (`RerunButtonLabel__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Rerun Button Label** |
| API name | `RerunButtonLabel__c` |
| Type | Text |
| Capacity | 80 characters |
| Always required | No |
| Default | Blank; the component uses `Rerun` |
| Used when | The Rerun action is available after a completed run. The text appears visibly in a labeled mode and provides the accessible name in **Icon only** mode. |
| Description | Optional plain-text label for the Run control after a completed run. Blank uses Rerun. |
| Help text | Enter up to 80 characters. Blank uses "Rerun". This text also names an icon-only Rerun control for assistive technology. |
| Allowed values | Any value valid for the field type |
| Example | `Check again` |

### Run Button Icon (`RunButtonIcon__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Run Button Icon** |
| API name | `RunButtonIcon__c` |
| Type | Text |
| Capacity | 80 characters |
| Always required | No |
| Default | Blank; the component uses its built-in play icon |
| Used when | The action includes an icon. |
| Description | Optional SLDS icon name used by the Run and Rerun control, such as utility:play or utility:refresh. Blank uses the built-in CSS play glyph. |
| Help text | Enter an SLDS icon name such as utility:play or utility:refresh. Blank uses the built-in play glyph. |
| Allowed values | A Lightning icon name in `category:name` form, or blank |
| Example | `utility:refresh` |


## 5. Result display

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


## 6. Troubleshooting

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


## 7. Lifecycle events

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
| Description | <p>Publishes one Check Set Run event after a deliberately initiated run completes. Page-load runs and page refreshes never publish because passive navigation could otherwise consume event allocations or repeatedly trigger subscribers.</p><p>A hidden automatic card has no in-card deliberate publication path; metadata validation warns when this switch is enabled in that configuration. Apex and Flow can still publish deliberately.</p><p>Leave unchecked until a reviewed subscriber needs an after-commit summary. Publication consumes the org's Platform Event allocation and does not confirm that the subscriber processed the event.</p> |
| Help text | <p>Publish a completion event for deliberate API, Flow, scheduled, batch, or user-requested runs. Page-load runs never publish.</p> |
| Allowed values | **Checked**: `true`<br>**Unchecked**: `false` |


## 8. Error events

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

- [Check fields](fields-check.md)
- [Create your first Check](../installation/create-your-first-check.md)
- [Configure Check Sets and Checks](../guides/configure-check-sets-and-checks.md)
