# Reference: Field limits

> [!NOTE]
> On this page, distinguish what Salesforce can store from what the Framework can safely resolve, then fix the field, completed text, or action URL responsible for a rejected value or `UNABLE_TO_EVALUATE` result.

<!-- Generated from shipped Salesforce metadata by scripts/release/generate_field_size_registry.py. -->

Use this page when Salesforce will not save or deploy a Custom Metadata value, when a Rule returns `UNABLE_TO_EVALUATE` because displayed text became too long, or when a configured action link does not appear. Most fields have only the Salesforce limit. A smaller group can grow when the Framework inserts record or result values into merge tokens such as `{!record.Name}`.

## Start with what happened

| What you observe | Which limit matters | What to do |
| --- | --- | --- |
| Salesforce will not save or deploy the Custom Metadata value | **What Salesforce accepts** | Find the field below and shorten or correct the value so it matches the Salesforce field type and limit. |
| A Rule returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG` | **Completed text limit** | Shorten the configured text or the Salesforce values inserted by its merge tokens. |
| A failed Rule does not show its configured action link | The `ActionUrl__c` limit and URL rules | Keep the final URL within 2,000 characters and use a same-org relative URL or an `https://` URL. |

## Why the Framework limits completed text

Some fields contain a message template rather than the final words a user sees. The Framework creates the **completed text** by replacing merge tokens with Salesforce data. For example, `{!record.Name}` is replaced with the current record's Name when populated. Add a quoted `fallback` attribute when a blank value needs a substitute, as in `{!record.Name fallback="Unnamed record"}`.

A saved template can therefore be short while the completed text becomes much larger. `FailureMessage__c` might contain `Account {!record.Name} needs review.`, but the Account Name is not inserted until the Rule runs.

The Framework limits one completed value to 20,000 characters so a merge token cannot create an unexpectedly large result, response, or demand on Salesforce transaction resources. A predictable ceiling also keeps the Lightning card and calling integrations from receiving unbounded display text.

When completed text crosses the limit, the Framework returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`. It does not cut the message to fit because truncated failure guidance, values, or instructions could mislead the user. **Not applicable** in the tables means the field does not accept Framework merge tokens, so only the Salesforce limit matters.

> [!NOTE]
> Display text can contain at most 100 merge tokens, and the completed text can contain at most 20,000 characters. The Framework returns `UNABLE_TO_EVALUATE` instead of silently shortening text. Action URLs receive an additional safety check and a 2,000-character limit before the link is shown.

## Check Set text limits

These are the Check Set fields where character count can prevent a value from being saved or can affect Framework output. Select an API name for its Setup label, purpose, default, and examples.

| Field API name | Salesforce field type | What Salesforce accepts | Completed text limit | If the value is too long |
| --- | --- | ---: | ---: | --- |
| [`CardSubtitle__c`](../../metadata/fields-check-set.md#card-subtitle-cardsubtitle__c) | Text | 255 | 20,000 | The Framework returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`CardTitle__c`](../../metadata/fields-check-set.md#card-title-cardtitle__c) | Text | 255 | Not applicable | The Framework uses the saved value as-is |
| [`ObjectApiName__c`](../../metadata/fields-check-set.md#object-objectapiname__c) | Text | 80 | Not applicable | The Framework uses the saved value as-is |

## Rule text limits

These are the Rule fields where character count can prevent a value from being saved or can affect Framework output. Select an API name to learn which Evaluation Type uses it and how it affects the result.

| Field API name | Salesforce field type | What Salesforce accepts | Completed text limit | If the value is too long |
| --- | --- | ---: | ---: | --- |
| [`ActionLabel__c`](../../metadata/fields-check-rule.md#action-label-actionlabel__c) | Text | 80 | 20,000 | The Framework returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`ActionUrl__c`](../../metadata/fields-check-rule.md#action-url-actionurl__c) | LongTextArea | 32768 | 2,000 | The Framework leaves out a URL over 2,000 characters or one that fails its safety checks |
| [`ApexClass__c`](../../metadata/fields-check-rule.md#apex-class-apexclass__c) | Text | 255 | Not applicable | The Framework uses the saved value as-is |
| [`ApexParametersJson__c`](../../metadata/fields-check-rule.md#apex-parameters-json-apexparametersjson__c) | LongTextArea | 32768 | Not applicable | The Framework uses the saved value as-is |
| [`ApplicabilityCountQuery__c`](../../metadata/fields-check-rule.md#applies-when-count-query-applicabilitycountquery__c) | LongTextArea | 32768 | Not applicable | The Framework uses the saved value as-is |
| [`ApplicabilityFormula__c`](../../metadata/fields-check-rule.md#applies-when-formula-applicabilityformula__c) | LongTextArea | 32768 | Not applicable | The Framework uses the saved value as-is |
| [`ApplicabilityNotMetMessage__c`](../../metadata/fields-check-rule.md#message-when-not-applicable-applicabilitynotmetmessage__c) | LongTextArea | 32768 | 20,000 | The Framework returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`CheckDescription__c`](../../metadata/fields-check-rule.md#check-description-checkdescription__c) | Text | 255 | 20,000 | The Framework returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`CheckTitle__c`](../../metadata/fields-check-rule.md#check-title-checktitle__c) | Text | 255 | Not applicable | The Framework uses the saved value as-is |
| [`ComparisonQueryField__c`](../../metadata/fields-check-rule.md#comparison-query-field-comparisonqueryfield__c) | Text | 255 | Not applicable | The Framework uses the saved value as-is |
| [`ComparisonQuery__c`](../../metadata/fields-check-rule.md#comparison-query-comparisonquery__c) | LongTextArea | 32768 | Not applicable | The Framework uses the saved value as-is |
| [`DisplayExpectedFormula__c`](../../metadata/fields-check-rule.md#display-expected-formula-displayexpectedformula__c) | LongTextArea | 32768 | Not applicable | The Framework uses the saved value as-is |
| [`DisplayExpectedText__c`](../../metadata/fields-check-rule.md#display-expected-text-displayexpectedtext__c) | Text | 255 | 20,000 | The Framework returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`DisplayFoundFormula__c`](../../metadata/fields-check-rule.md#display-found-formula-displayfoundformula__c) | LongTextArea | 32768 | Not applicable | The Framework uses the saved value as-is |
| [`DisplayFoundText__c`](../../metadata/fields-check-rule.md#display-found-text-displayfoundtext__c) | Text | 255 | 20,000 | The Framework returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`ExpectedFixedValue__c`](../../metadata/fields-check-rule.md#expected-value-fixed-expectedfixedvalue__c) | Text | 255 | Not applicable | The Framework uses the saved value as-is |
| [`ExpectedRecordFormula__c`](../../metadata/fields-check-rule.md#expected-value-formula-expectedrecordformula__c) | LongTextArea | 32768 | Not applicable | The Framework uses the saved value as-is |
| [`FailureMessage__c`](../../metadata/fields-check-rule.md#message-when-failed-failuremessage__c) | LongTextArea | 32768 | 20,000 | The Framework returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`FindInListFormula__c`](../../metadata/fields-check-rule.md#value-to-find-in-the-list-formula-findinlistformula__c) | LongTextArea | 32768 | Not applicable | The Framework uses the saved value as-is |
| [`FixMessage__c`](../../metadata/fields-check-rule.md#fix-message-fixmessage__c) | LongTextArea | 32768 | 20,000 | The Framework returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |
| [`PassConditionFormula__c`](../../metadata/fields-check-rule.md#pass-condition-passconditionformula__c) | LongTextArea | 32768 | Not applicable | The Framework uses the saved value as-is |
| [`PrerequisiteRule__c`](../../metadata/fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Text | 255 | Not applicable | The Framework uses the saved value as-is |
| [`SourceQueryField__c`](../../metadata/fields-check-rule.md#source-query-field-sourcequeryfield__c) | Text | 255 | Not applicable | The Framework uses the saved value as-is |
| [`SourceQuery__c`](../../metadata/fields-check-rule.md#source-query-sourcequery__c) | LongTextArea | 32768 | Not applicable | The Framework uses the saved value as-is |
| [`UnableToEvaluateMessage__c`](../../metadata/fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | LongTextArea | 32768 | 20,000 | The Framework returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text |

## Fields controlled by something other than character count

These fields are still constrained, but making their text shorter will not solve the problem. Picklists accept only shipped API values, checkboxes accept `true` or `false`, Number fields enforce their digit count, and the relationship must name a Check Set.

| Metadata type | Salesforce field type | Constraint | Field API names |
| --- | --- | --- | --- |
| Check Set | Picklist | Restricted value set | [`CardRevealMode__c`](../../metadata/fields-check-set.md#reveal-mode-cardrevealmode__c), [`CardRunMode__c`](../../metadata/fields-check-set.md#when-checks-run-cardrunmode__c), [`FoundExpectedDisplay__c`](../../metadata/fields-check-set.md#foundexpected-display-foundexpecteddisplay__c), [`PassedChecksDisplay__c`](../../metadata/fields-check-set.md#passed-checks-passedchecksdisplay__c), [`SkippedChecksDisplay__c`](../../metadata/fields-check-set.md#skipped-checks-skippedchecksdisplay__c) |
| Check Set | Checkbox | true/false | [`IsActive__c`](../../metadata/fields-check-set.md#active-isactive__c), [`PublishErrorLogEvent__c`](../../metadata/fields-check-set.md#publish-error-log-event-publisherrorlogevent__c), [`PublishUserRunEvent__c`](../../metadata/fields-check-set.md#publish-user-run-event-publishuserrunevent__c), [`ShowDiagnostics__c`](../../metadata/fields-check-set.md#show-diagnostics-showdiagnostics__c), [`StopOnSystemError__c`](../../metadata/fields-check-set.md#stop-after-a-system-error-stoponsystemerror__c) |
| Rule | Picklist | Restricted value set | [`ApplicabilityCountOperator__c`](../../metadata/fields-check-rule.md#count-must-be-applicabilitycountoperator__c), [`ApplicabilityMode__c`](../../metadata/fields-check-rule.md#applies-to-applicabilitymode__c), [`Category__c`](../../metadata/fields-check-rule.md#category-category__c), [`ComparisonOperator__c`](../../metadata/fields-check-rule.md#comparison-operator-comparisonoperator__c), [`DisplayValueFormat__c`](../../metadata/fields-check-rule.md#display-value-format-displayvalueformat__c), [`EmptyValueHandling__c`](../../metadata/fields-check-rule.md#if-field-value-is-empty-emptyvaluehandling__c), [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c), [`ExpectedValueSource__c`](../../metadata/fields-check-rule.md#expected-value-comes-from-expectedvaluesource__c), [`FailureSeverity__c`](../../metadata/fields-check-rule.md#failure-severity-failureseverity__c), [`FormulaResultType__c`](../../metadata/fields-check-rule.md#formula-result-type-formularesulttype__c), [`NoRowsResult__c`](../../metadata/fields-check-rule.md#if-query-finds-no-records-norowsresult__c), [`QueryResultHandling__c`](../../metadata/fields-check-rule.md#how-to-read-query-results-queryresulthandling__c) |
| Rule | Number | 4 digits, 0 decimal places | [`ApplicabilityCountThreshold__c`](../../metadata/fields-check-rule.md#count-value-applicabilitycountthreshold__c), [`EvaluationOrder__c`](../../metadata/fields-check-rule.md#evaluation-order-evaluationorder__c), [`MaxQueryRows__c`](../../metadata/fields-check-rule.md#max-query-rows-1-2000-maxqueryrows__c) |
| Rule | Checkbox | true/false | [`IsActive__c`](../../metadata/fields-check-rule.md#active-isactive__c), [`PublishUserResultEvent__c`](../../metadata/fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) |
| Rule | Metadata relationship | Must name a Check Set | [`Record_Health_Check_Set__c`](../../metadata/fields-check-rule.md#check-set-record_health_check_set__c) |

This page covers all **13 Check Set fields** and **43 Rule fields** in the shipped Custom Metadata definitions.

## If the limit is exceeded

Salesforce rejects a value that does not fit its Custom Metadata field. The Framework does not receive that configuration, so correct the source value and deploy again.

When inserted values make display text longer than 20,000 characters, the Rule returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`. Shorten the configured message or review the Salesforce fields used by its merge tokens. The Framework does not cut off the message because partial guidance could mislead the user.

When an action URL is unsafe or longer than 2,000 characters, the Rule can still return `FAIL` and show its Fix Message, but the Framework leaves out the link. An authorized administrator can use Show Diagnostics to investigate the resolved URL.

## Related

- [Check Set fields](../../metadata/fields-check-set.md)
- [Rule fields](../../metadata/fields-check-rule.md)
- [Configuration guide](../../guides/configure-check-sets-and-rules.md)
- [Architecture](../framework/architecture.md)
