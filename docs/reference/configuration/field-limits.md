# Field and completed-text limits

> [!NOTE]
> Use this page when Salesforce rejects a Check Set or Check value, a Check returns `RESOLVED_TEMPLATE_TOO_LONG`, or a failed Check does not show its action link.

<!-- Maintainers: generated from shipped metadata by scripts/release/generate_field_size_registry.py. -->

Two limits can apply. The Salesforce field limit controls what an administrator can save in Custom Metadata. The completed-text limit applies later, after Record Health Check replaces merge tokens such as `{!record.Name}` with Salesforce values. Most fields have only the Salesforce limit.

## Start with what happened

| What you observe | Which limit matters | What to do |
| --- | --- | --- |
| Salesforce will not save or deploy the Custom Metadata value | **What Salesforce accepts** | Find the field below and shorten or correct the value so it matches the Salesforce field type and limit. |
| A Check returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG` | **Completed text limit** | Shorten the configured text or the Salesforce values inserted by its merge tokens. |
| A failed Check does not show its configured action link | The **Action URL** limit and URL checks | The failure still appears. Keep the final URL within 2,000 characters and use a same-org relative URL or an `https://` URL. |

## Why completed text has a separate limit

Some fields contain a message template rather than the final words a user sees. Record Health Check creates the **completed text** by replacing merge tokens with Salesforce data. For example, `{!record.Name}` is replaced with the current record's Name. Add a quoted `fallback` when an empty value needs a substitute, as in `{!record.Name fallback="Unnamed record"}`.

A saved template can therefore be short while the completed text becomes much larger. `FailureMessage__c` might contain `Account {!record.Name} needs review.`, but the Account Name is not inserted until the Check runs.

Record Health Check limits one completed value to 20,000 characters. This prevents an inserted Salesforce value from creating an unexpectedly large Apex or Flow response and keeps the Lightning card from receiving more display text than intended.

When completed text crosses the limit, Record Health Check returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`. It does not cut the message because partial instructions could mislead the user. **Not applicable** means the field does not accept Record Health Check merge tokens, so only the Salesforce limit matters.

> [!NOTE]
> One display template can contain at most 100 merge tokens, and one completed value can contain at most 20,000 characters. Record Health Check returns `UNABLE_TO_EVALUATE` instead of silently shortening text. A completed Action URL also must pass URL safety checks and contain no more than 2,000 characters.

## Check Set text limits

These Check Set fields can be affected by a saved-value or completed-text character limit. Select an API name for its Setup label, purpose, default, and examples.

| Field API name | Salesforce field type | What Salesforce accepts | Completed text limit | If the value is too long |
| --- | --- | ---: | ---: | --- |
| [`CardSubtitle__c`](../custom-metadata/check-set-fields.md#card-subtitle-cardsubtitle__c) | Text | 255 | 20,000 | Record Health Check returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`CardTitle__c`](../custom-metadata/check-set-fields.md#card-title-cardtitle__c) | Text | 255 | Not applicable | Record Health Check uses the saved value as-is |
| [`ObjectApiName__c`](../custom-metadata/check-set-fields.md#object-objectapiname__c) | Text | 80 | Not applicable | Record Health Check uses the saved value as-is |
| [`RerunButtonLabel__c`](../custom-metadata/check-set-fields.md#rerun-button-label-rerunbuttonlabel__c) | Text | 80 | Not applicable | Record Health Check uses the saved value as-is |
| [`RunButtonIcon__c`](../custom-metadata/check-set-fields.md#run-button-icon-runbuttonicon__c) | Text | 80 | Not applicable | Record Health Check uses the saved value as-is |
| [`RunButtonLabel__c`](../custom-metadata/check-set-fields.md#run-button-label-runbuttonlabel__c) | Text | 80 | Not applicable | Record Health Check uses the saved value as-is |

## Check text limits

These Check fields can be affected by a saved-value or completed-text character limit. Select an API name to learn which Evaluation Type uses it and how it affects the result.

| Field API name | Salesforce field type | What Salesforce accepts | Completed text limit | If the value is too long |
| --- | --- | ---: | ---: | --- |
| [`ActionLabel__c`](../custom-metadata/check-fields.md#action-label-actionlabel__c) | Text | 80 | 20,000 | Record Health Check returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`ActionUrl__c`](../custom-metadata/check-fields.md#action-url-actionurl__c) | LongTextArea | 32768 | 2,000 | Record Health Check leaves out a URL over 2,000 characters or one that fails its safety checks |
| [`ApexClass__c`](../custom-metadata/check-fields.md#apex-class-apexclass__c) | Text | 255 | Not applicable | Record Health Check uses the saved value as-is |
| [`ApexParametersJson__c`](../custom-metadata/check-fields.md#apex-parameters-json-apexparametersjson__c) | LongTextArea | 32768 | Not applicable | Record Health Check uses the saved value as-is |
| [`ApplicabilityCountQuery__c`](../custom-metadata/check-fields.md#applies-when-count-query-applicabilitycountquery__c) | LongTextArea | 32768 | Not applicable | Record Health Check uses the saved value as-is |
| [`ApplicabilityFormula__c`](../custom-metadata/check-fields.md#applies-when-formula-applicabilityformula__c) | LongTextArea | 32768 | Not applicable | Record Health Check uses the saved value as-is |
| [`ApplicabilityNotMetMessage__c`](../custom-metadata/check-fields.md#message-when-not-applicable-applicabilitynotmetmessage__c) | LongTextArea | 32768 | 20,000 | Record Health Check returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`CheckDescription__c`](../custom-metadata/check-fields.md#check-description-checkdescription__c) | Text | 255 | 20,000 | Record Health Check returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`CheckTitle__c`](../custom-metadata/check-fields.md#check-title-checktitle__c) | Text | 255 | Not applicable | Record Health Check uses the saved value as-is |
| [`ComparisonQueryField__c`](../custom-metadata/check-fields.md#comparison-query-field-comparisonqueryfield__c) | Text | 255 | Not applicable | Record Health Check uses the saved value as-is |
| [`ComparisonQuery__c`](../custom-metadata/check-fields.md#comparison-query-comparisonquery__c) | LongTextArea | 32768 | Not applicable | Record Health Check uses the saved value as-is |
| [`DisplayExpectedFormula__c`](../custom-metadata/check-fields.md#display-expected-formula-displayexpectedformula__c) | LongTextArea | 32768 | Not applicable | Record Health Check uses the saved value as-is |
| [`DisplayExpectedText__c`](../custom-metadata/check-fields.md#display-expected-text-displayexpectedtext__c) | Text | 255 | 20,000 | Record Health Check returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`DisplayFoundFormula__c`](../custom-metadata/check-fields.md#display-found-formula-displayfoundformula__c) | LongTextArea | 32768 | Not applicable | Record Health Check uses the saved value as-is |
| [`DisplayFoundText__c`](../custom-metadata/check-fields.md#display-found-text-displayfoundtext__c) | Text | 255 | 20,000 | Record Health Check returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`ExpectedCurrencyIsoCode__c`](../custom-metadata/check-fields.md#expected-currency-iso-code-expectedcurrencyisocode__c) | Text | 3 | Not applicable | Record Health Check uses the saved value as-is |
| [`ExpectedFixedValue__c`](../custom-metadata/check-fields.md#expected-value-fixed-expectedfixedvalue__c) | Text | 255 | Not applicable | Record Health Check uses the saved value as-is |
| [`ExpectedRecordFormula__c`](../custom-metadata/check-fields.md#expected-value-formula-expectedrecordformula__c) | LongTextArea | 32768 | Not applicable | Record Health Check uses the saved value as-is |
| [`FailureMessage__c`](../custom-metadata/check-fields.md#message-when-failed-failuremessage__c) | LongTextArea | 32768 | 20,000 | Record Health Check returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`FindInListFormula__c`](../custom-metadata/check-fields.md#value-to-find-in-the-list-formula-findinlistformula__c) | LongTextArea | 32768 | Not applicable | Record Health Check uses the saved value as-is |
| [`FixMessage__c`](../custom-metadata/check-fields.md#fix-message-fixmessage__c) | LongTextArea | 32768 | 20,000 | Record Health Check returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`PassConditionFormula__c`](../custom-metadata/check-fields.md#pass-condition-passconditionformula__c) | LongTextArea | 32768 | Not applicable | Record Health Check uses the saved value as-is |
| [`PrerequisiteCheck__c`](../custom-metadata/check-fields.md#prerequisite-check-prerequisitecheck__c) | Text | 255 | Not applicable | Record Health Check uses the saved value as-is |
| [`SourceQueryField__c`](../custom-metadata/check-fields.md#source-query-field-sourcequeryfield__c) | Text | 255 | Not applicable | Record Health Check uses the saved value as-is |
| [`SourceQuery__c`](../custom-metadata/check-fields.md#source-query-sourcequery__c) | LongTextArea | 32768 | Not applicable | Record Health Check uses the saved value as-is |
| [`UnableToEvaluateMessage__c`](../custom-metadata/check-fields.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | LongTextArea | 32768 | 20,000 | Record Health Check returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |

## Fields controlled by something other than character count

These fields are still constrained, but making their text shorter will not solve the problem. Picklists accept only shipped API values, checkboxes accept `true` or `false`, Number fields enforce their digit count, and the relationship must name a Check Set.

| Metadata type | Salesforce field type | Constraint | Field API names |
| --- | --- | --- | --- |
| Check Set | Picklist | Restricted value set | [`CardRevealMode__c`](../custom-metadata/check-set-fields.md#reveal-mode-cardrevealmode__c), [`CardRunMode__c`](../custom-metadata/check-set-fields.md#when-checks-run-cardrunmode__c), [`FoundExpectedDisplay__c`](../custom-metadata/check-set-fields.md#foundexpected-display-foundexpecteddisplay__c), [`PassedChecksDisplay__c`](../custom-metadata/check-set-fields.md#passed-checks-passedchecksdisplay__c), [`RunButtonDisplay__c`](../custom-metadata/check-set-fields.md#run-button-display-runbuttondisplay__c), [`SkippedChecksDisplay__c`](../custom-metadata/check-set-fields.md#skipped-checks-skippedchecksdisplay__c), [`SummaryDisplay__c`](../custom-metadata/check-set-fields.md#summary-display-summarydisplay__c) |
| Check Set | Checkbox | true/false | [`IsActive__c`](../custom-metadata/check-set-fields.md#active-isactive__c), [`PublishErrorLogEvent__c`](../custom-metadata/check-set-fields.md#publish-error-log-event-publisherrorlogevent__c), [`PublishUserRunEvent__c`](../custom-metadata/check-set-fields.md#publish-user-run-event-publishuserrunevent__c), [`ShowDiagnostics__c`](../custom-metadata/check-set-fields.md#show-diagnostics-showdiagnostics__c), [`StopOnSystemError__c`](../custom-metadata/check-set-fields.md#stop-after-a-system-error-stoponsystemerror__c) |
| Check | Picklist | Restricted value set | [`ApplicabilityCountOperator__c`](../custom-metadata/check-fields.md#count-must-be-applicabilitycountoperator__c), [`ApplicabilityMode__c`](../custom-metadata/check-fields.md#applies-to-applicabilitymode__c), [`Category__c`](../custom-metadata/check-fields.md#category-category__c), [`ComparisonOperator__c`](../custom-metadata/check-fields.md#comparison-operator-comparisonoperator__c), [`DisplayValueFormat__c`](../custom-metadata/check-fields.md#display-value-format-displayvalueformat__c), [`EmptyValueHandling__c`](../custom-metadata/check-fields.md#if-field-value-is-empty-emptyvaluehandling__c), [`EvaluationType__c`](../custom-metadata/check-fields.md#evaluation-type-evaluationtype__c), [`ExpectedValueSource__c`](../custom-metadata/check-fields.md#expected-value-comes-from-expectedvaluesource__c), [`FailureSeverity__c`](../custom-metadata/check-fields.md#failure-severity-failureseverity__c), [`FormulaResultType__c`](../custom-metadata/check-fields.md#formula-result-type-formularesulttype__c), [`NoRowsResult__c`](../custom-metadata/check-fields.md#if-query-finds-no-records-norowsresult__c), [`QueryResultHandling__c`](../custom-metadata/check-fields.md#how-to-read-query-results-queryresulthandling__c) |
| Check | Number | 4 digits, 0 decimal places | [`ApplicabilityCountThreshold__c`](../custom-metadata/check-fields.md#count-value-applicabilitycountthreshold__c), [`EvaluationOrder__c`](../custom-metadata/check-fields.md#evaluation-order-evaluationorder__c), [`MaxQueryRows__c`](../custom-metadata/check-fields.md#max-query-rows-1-2000-maxqueryrows__c) |
| Check | Checkbox | true/false | [`IsActive__c`](../custom-metadata/check-fields.md#active-isactive__c), [`PublishUserResultEvent__c`](../custom-metadata/check-fields.md#publish-user-result-event-publishuserresultevent__c) |
| Check | Metadata relationship | Must name a Check Set | [`Record_Health_Check_Set__c`](../custom-metadata/check-fields.md#check-set-record_health_check_set__c) |

This page covers all **18 Check Set fields** and **44 Check fields** in the shipped Custom Metadata definitions.

## If the limit is exceeded

Salesforce rejects a value that does not fit its Custom Metadata field. Record Health Check never receives that value. Shorten or correct it, then save or deploy again.

When inserted values make display text longer than 20,000 characters, the Check returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`. Shorten the configured message or review the Salesforce fields used by its merge tokens. Record Health Check does not cut off the message because partial guidance could mislead the user.

When an Action URL is unsafe or longer than 2,000 characters, the Check can still return `FAIL` and show its Fix Message, but Record Health Check leaves out the link. An authorized administrator can use **Show Diagnostics** to investigate the completed URL.

## Related

- [Check Set fields](../custom-metadata/check-set-fields.md)
- [Check fields](../custom-metadata/check-fields.md)
- [Configuration guide](../../build-checks/configure-check-sets-and-checks.md)
- [Architecture](../../architecture/framework.md)
