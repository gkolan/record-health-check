# Fields by Evaluation Type

> [!NOTE]
> On this page, see which Check fields to complete for the Evaluation Type you chose and which to
> leave blank, so you do not have to read every field definition first.
>
> **Reference**
>
> - Each field links to its full definition in the [Check fields reference](../reference/custom-metadata/check-fields.md).
> - For complete working configurations, copy an [example by Evaluation Type](../examples/README.md).

A Check record in Setup shows every field for every Evaluation Type. Most of them do not apply to
the type you chose. Use this page as the checklist: complete the fields marked **Fill**, decide the
ones marked **If**, and leave everything else blank.

## Every Check

| Field                                                                                                     | What to do                                                                                        |
| --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| [Label](../reference/custom-metadata/check-fields.md#label-masterlabel) and Developer Name                | **Fill.** The Developer Name is what other Checks use as a Prerequisite Check.                    |
| [Check Set](../reference/custom-metadata/check-fields.md#check-set-record_health_check_set__c)            | **Fill.** It decides the object and the card.                                                     |
| [Check Title](../reference/custom-metadata/check-fields.md#check-title-checktitle__c)                     | **Fill.** Users read this on the card.                                                            |
| [Message When Failed](../reference/custom-metadata/check-fields.md#message-when-failed-failuremessage__c) | **Fill.** Setup lets you save it blank, but the Check then returns `INVALID_CONFIG` when it runs. |
| [Evaluation Type](../reference/custom-metadata/check-fields.md#evaluation-type-evaluationtype__c)         | **Fill.** Then use the matching section below.                                                    |
| [Evaluation Order](../reference/custom-metadata/check-fields.md#evaluation-order-evaluationorder__c)      | Keep the default `100` or set your own. Do not clear it; a blank value is `INVALID_CONFIG`.       |
| [Failure Severity](../reference/custom-metadata/check-fields.md#failure-severity-failureseverity__c)      | **If** a failure is a warning or information rather than a critical failure.                      |
| [Fix Message](../reference/custom-metadata/check-fields.md#fix-message-fixmessage__c)                     | **If** users need to know how to fix a failure. Recommended.                                      |
| Applies To, Prerequisite Check, Action Label and URL, display fields, Publish User Result Event           | Optional. Leave at their defaults for a first Check.                                              |

## Verify with a formula (`FORMULA`)

| Field                                                                                                                                    | What to do                                                       |
| ---------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| [Pass Condition](../reference/custom-metadata/check-fields.md#pass-condition-passconditionformula__c)                                    | **Fill** with a formula that is true when the record is healthy. |
| [Display: Found Formula](../reference/custom-metadata/check-fields.md#display-found-formula-displayfoundformula__c) and Expected Formula | **If** the card should show a Found or Expected value.           |

Leave every query field and both Apex fields blank.

## Verify with a query (`QUERY`)

| Field                                                                                                                            | What to do                                                                                                 |
| -------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| [Source Query](../reference/custom-metadata/check-fields.md#source-query-sourcequery__c)                                         | **Fill** with one SOQL query. Filter it to the current record with a `record` merge token.                 |
| [Source Query Field](../reference/custom-metadata/check-fields.md#source-query-field-sourcequeryfield__c)                        | **Fill** with the field or aggregate alias to read. Leave blank only for bare `COUNT()`.                   |
| [Comparison Operator](../reference/custom-metadata/check-fields.md#comparison-operator-comparisonoperator__c)                    | **Fill.**                                                                                                  |
| [How To Read Query Results](../reference/custom-metadata/check-fields.md#how-to-read-query-results-queryresulthandling__c)       | **Fill.** One row or aggregate is the usual choice.                                                        |
| [Expected Value Comes From](../reference/custom-metadata/check-fields.md#expected-value-comes-from-expectedvaluesource__c)       | **Fill** unless the operator is Is empty or Is not empty. Then fill the one field it points to.            |
| [If Query Finds No Records](../reference/custom-metadata/check-fields.md#if-query-finds-no-records-norowsresult__c)              | **If** How To Read Query Results is Any record passes, Every record passes, or Compare as lists: required. |
| [If Field Value Is Empty](../reference/custom-metadata/check-fields.md#if-field-value-is-empty-emptyvaluehandling__c)            | **If** the query reads records rather than an aggregate and blanks need special handling.                  |
| [Expected Currency ISO Code](../reference/custom-metadata/check-fields.md#expected-currency-iso-code-expectedcurrencyisocode__c) | **If** a multi-currency org compares a Currency field with a fixed value: required.                        |
| [Max Query Rows](../reference/custom-metadata/check-fields.md#max-query-rows-1-2000-maxqueryrows__c)                             | Optional. The default is `200`; keep it as low as the question allows.                                     |

For **List contains any** or **List contains none**, set How To Read Query Results to Compare as
lists, fill [Value to find in the list (formula)](../reference/custom-metadata/check-fields.md#value-to-find-in-the-list-formula-findinlistformula__c)
and Comparison Query, and leave Source Query blank.

Leave Pass Condition, the display formulas, and both Apex fields blank.

## Compare two queries (`COMPARE_TWO_QUERIES`)

| Field                                                                                                                           | What to do                                                                                 |
| ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Source Query and Source Query Field                                                                                             | **Fill**, as for a Query Check.                                                            |
| [Comparison Query](../reference/custom-metadata/check-fields.md#comparison-query-comparisonquery__c) and Comparison Query Field | **Fill** with the second query and the field or alias to read.                             |
| Comparison Operator and How To Read Query Results                                                                               | **Fill.** Lists overlap, Lists contain all, and Lists match exactly need Compare as lists. |
| If Query Finds No Records                                                                                                       | **If** How To Read Query Results is not One row or aggregate: required.                    |

Leave Expected Value Comes From, the Expected Value fields, Pass Condition, and both Apex fields
blank.

## Verify with Apex (`APEX`)

| Field                                                                                                             | What to do                                                                                    |
| ----------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| [Apex Class](../reference/custom-metadata/check-fields.md#apex-class-apexclass__c)                                | **Fill** with the API name of a reviewed class that implements `rhc.RecordHealthCheckPlugin`. |
| [Apex Parameters (JSON)](../reference/custom-metadata/check-fields.md#apex-parameters-json-apexparametersjson__c) | **If** the class reads parameters, such as `{"daysBack": 90}`.                                |

Leave every formula and query field blank. A developer owns the class and its tests; see
[Create a custom Apex Check](../developer-guides/write-an-apex-check.md).

## Related

- [Check fields](../reference/custom-metadata/check-fields.md): the full definition of every field
- [Examples by Evaluation Type](../examples/README.md): complete configurations to copy
- [Configure Check Sets and Checks](./configure-check-sets-and-checks.md): the complete setup procedure
- [Create your first Check](../step-by-step-guide/create-your-first-check.md): a guided first Check
