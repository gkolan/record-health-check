# Account Check Builder Guide: configuration and results

Use this page to understand the 25 Account examples, compare their configuration with Salesforce Setup, and adapt them to your own requirements. The examples retain their existing API names for package upgrades; their titles and Evaluation Order describe the current rules.

> On this page, find each Check's configuration, Found and Expected values, demo result, and steps for testing it in your sandbox.

These examples match the Check definitions in this checkout; use [the matching scratch-org setup](../install/install-demo-in-a-scratch-org.md) before comparing exact results.

## Scenario

Acme Corporation has incomplete Case details, missing Opportunity Contact Roles, and Opportunities without Products. The Check Set starts with Account fields, then uses related records to show which requirements pass and which need attention.

## Why this Evaluation Type matters

Use **Formula** for Account fields and parent Account fields, **Query** for one set of related
Salesforce records, **Compare Two Queries** when two related-record results must agree, and **Apex**
only when the supported Formula and Query settings cannot safely express the requirement.

## Configure the Check

### Values shared by all 25 Checks

| Setup field | Value |
| --- | --- |
| Check Set | Account Check Builder Guide |
| Base Object | Account |
| Active | Selected |
| Found and Expected display | On demand |
| Unable to Evaluate guidance | Confirm that the Check is configured correctly and that the running user can read every object and field used by the formula, SOQL query, or Apex class. Then run the Check again. |
| Action-link rule | Open the related Account, Opportunities, Cases, Contacts, or new Task page needed to review the result. |
| Test users | Test with the intended Salesforce user and assigned permission sets, not only a System Administrator. |

The standard Unable to Evaluate guidance above applies unless a Check below provides a more
specific message. It is not repeated in every row.

## Formula Checks

### Check 10: Account Type is set

| Check field | Value |
| --- | --- |
| Check API name | `Example_Website_URL_Valid` (existing identity retained for upgrades) |
| Evaluation Order | 10 |
| Evaluation Type | Formula |
| Description | The formula checks the standard Account Type picklist. It passes when Type has a value and fails when Type is blank. |
| Applies When | All records; a blank Type fails rather than skips. |
| Pass Formula | `NOT(ISBLANK(TEXT(Type)))` |
| Found Formula | `IF(ISBLANK(TEXT(Type)), "Not set", TEXT(Type))` |
| Expected Formula | `"An Account Type is selected"` |
| Demo result | Pass. Acme's Type is `Customer`. |
| Failure Severity | Warning |
| Failure Message | `{!record.Name fallback="This Account"} has no Account Type selected.` |
| Fix Instructions | Select the Type that describes the Account's relationship to your business. |
| Action | **Set Account Type** → edit the Account |

### Check 20: Account has a phone number or website

| Check field | Value |
| --- | --- |
| Check API name | `Example_Segregation_Of_Duties` (existing identity retained for upgrades) |
| Evaluation Order | 20 |
| Evaluation Type | Formula |
| Description | The formula checks the standard Account Phone and Website fields. It passes when either field has a value and fails when both are blank. This checks completeness, not whether the number or website is valid. |
| Applies When | All records; two blank fields fail rather than skip. |
| Pass Formula | `OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website)))` |
| Found Formula | `"Phone: " & BLANKVALUE(Phone, "Not set") & "; Website: " & BLANKVALUE(Website, "Not set")` |
| Expected Formula | `"A phone number or website is provided"` |
| Demo result | Pass. Acme has both a Phone and a Website. |
| Failure Severity | Warning |
| Failure Message | `{!record.Name fallback="This Account"} has neither a phone number nor a website.` |
| Fix Instructions | Add a business phone number or website so users can contact or research the business. |
| Action | **Add Phone or Website** → edit the Account |

### Check 30: Billing address matches the parent bill-to Account

| Check field | Value |
| --- | --- |
| Check API name | `Example_Guide_Industry_Manufacturing` (existing identity retained for upgrades) |
| Evaluation Order | 30 |
| Evaluation Type | Formula |
| Description | Formula evaluation compares the Account and parent Account billing street, city, state, postal code, and country. It passes only when all five values match. |
| Applies When | **Parent Account** is selected. |
| Applicability Formula | `NOT(ISBLANK(ParentId))` |
| Pass Formula | `AND(BillingStreet = Parent.BillingStreet, BillingCity = Parent.BillingCity, BillingState = Parent.BillingState, BillingPostalCode = Parent.BillingPostalCode, BillingCountry = Parent.BillingCountry)` |
| Found | Complete Account billing address |
| Found Formula | `BillingStreet & ", " & BillingCity & ", " & BillingState & " " & BillingPostalCode & ", " & BillingCountry` |
| Expected | Complete parent Account billing address |
| Expected Formula | `Parent.BillingStreet & ", " & Parent.BillingCity & ", " & Parent.BillingState & " " & Parent.BillingPostalCode & ", " & Parent.BillingCountry` |
| Demo result | Pass. Found and Expected both show `2400 West Fulton Street, Chicago, Illinois 60612, United States`. |
| Failure Severity | Information |
| Failure Message | `{!record.Name fallback="This Account"} does not match the parent Account's complete bill-to address.` |
| Skipped Message | `{!record.Name fallback="This Account"} has no parent bill-to Account to compare.` |
| Fix Instructions | Confirm the legal bill-to location with finance. Correct the Account or parent Account only after the difference is verified. |
| Action | **Review bill-to address** → edit the Account |

## Query Checks

The **Verify with Query** examples progress from counts with fixed thresholds (40–50), to checking
fields across rows (60–80), returning only exceptions (90), related Contact Roles (100–110), finding
a value in a list (120), and calculating the expected value with another query (130).

### Query Check summary

Found and Expected show the value and comparison only. The title and description provide the
context; row checks add a short qualifier such as “missing” or “inactive.”

| Order | Check and installed API name | Found in Acme | Expected in Acme | Outcome |
| ---: | --- | --- | --- | --- |
| 40 | High-priority open Cases stay within the limit<br>`Example_Fewer_Than_Ten_Open_Cases` | 4 | at most 1 | Fail (Critical) |
| 50 | At least one open Opportunity is Commit<br>`Example_Significant_Open_Opp` | 0 | at least 1 | Fail (Info) |
| 60 | Every open Case has a Contact<br>`Example_Open_Cases_Have_Contacts` | 6 of 12 missing | None missing | Fail (Critical) |
| 70 | Every escalated open Case has a Description<br>`Example_Guide_Contacts_Have_Email` | 1 of 1 missing | None missing | Fail (Warning) |
| 80 | Every open Opportunity has an active owner<br>`Example_High_Value_Open_Opp` | 0 of 2 inactive | None inactive | Pass |
| 90 | No proposal has a missing or low Amount<br>`Example_Open_Opps_Have_Amount` | 0 exceptions | No exceptions | Pass |
| 100 | Open Opportunities include a Decision Maker<br>`Example_Has_At_Least_One_Contact` | 1 | at least 1 | Pass |
| 110 | Contacts on open deals have Email or Phone<br>`Example_Contact_States_Match_Billing` | 1 missing both | None missing both | Fail (Warning) |
| 120 | Open-deal Contact Roles include Technical Buyer<br>`Example_Billing_State_In_Contacts` | Technical Buyer | to be one of [Decision Maker, Executive Sponsor, Executive Sponsor, Business User] | Fail (Info) |
| 130 | Cases closed keep pace with Cases created<br>`Example_Contacts_Cover_Open_Cases` | 4 | at least 16 | Fail (Warning) |

### Query Check configuration

| Order | Configuration | What this teaches |
| ---: | --- | --- |
| 40 | Source query: `SELECT COUNT() FROM Case WHERE AccountId = {!record.Id} AND IsClosed = false AND Priority = 'High'`<br>Expected value source: `FIXED_VALUE`<br>Fixed expected value: `1`<br>Result handling: `ONE_RESULT`<br>Comparison: `LESS_THAN_OR_EQUAL`<br>No rows: `FAIL` | The Query check counts open Cases with Priority High. It passes when no more than one high-priority Case requires Account-level escalation at the same time. |
| 50 | Source query: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false AND ForecastCategoryName = 'Commit'`<br>Expected value source: `FIXED_VALUE`<br>Fixed expected value: `1`<br>Result handling: `ONE_RESULT`<br>Comparison: `GREATER_THAN_OR_EQUAL`<br>No rows: `FAIL` | The Query check counts open Opportunities with Forecast Category Commit. It passes when at least one open deal is included in the committed forecast. |
| 60 | Source query: `SELECT ContactId FROM Case WHERE AccountId = {!record.Id} AND IsClosed = false`<br>Result handling: `ALL_ROWS_PASS`<br>Comparison: `IS_NOT_BLANK`<br>No rows: `PASS` | The Query check reads Contact on each open Case. It passes only when every returned Case has a Contact. With no open Cases, it passes. |
| 70 | Source query: `SELECT Description FROM Case WHERE AccountId = {!record.Id} AND IsClosed = false AND IsEscalated = true`<br>Result handling: `ALL_ROWS_PASS`<br>Comparison: `IS_NOT_BLANK`<br>No rows: `SKIP` | The Query check reads Description on each escalated open Case. It passes only when every Description has a value. No escalated open Cases skips the check. It does not assess the quality of the text. |
| 80 | Source query: `SELECT Owner.IsActive FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false`<br>Expected value source: `FIXED_VALUE`<br>Fixed expected value: `true`<br>Result handling: `ALL_ROWS_PASS`<br>Comparison: `EQUALS`<br>No rows: `PASS` | The Query check verifies Active on the owner of every open Opportunity. It passes only when every Opportunity owner is an active Salesforce user. |
| 90 | Source query: `SELECT Name FROM Opportunity WHERE AccountId = {!record.Id} AND StageName = 'Proposal/Price Quote' AND (Amount = null OR Amount < 25000)`<br>Result handling: `ALL_ROWS_PASS`<br>Comparison: `IS_BLANK`<br>No rows: `PASS` | The Query check returns only proposal-stage Opportunities whose Amount is blank or below $25,000. It passes when the query returns no Opportunity names. |
| 100 | Source query: `SELECT COUNT() FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false AND Role = 'Decision Maker'`<br>Expected value source: `FIXED_VALUE`<br>Fixed expected value: `1`<br>Result handling: `ONE_RESULT`<br>Comparison: `GREATER_THAN_OR_EQUAL`<br>No rows: `FAIL` | The Query check counts Decision Maker Contact Roles across open Opportunities. It passes when at least one role exists. This checks the recorded role, not whether the person has verified buying authority. |
| 110 | Source query: `SELECT COUNT() unreachableStakeholders FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false AND ContactId != null AND Contact.Email = null AND Contact.Phone = null`<br>Expected value source: `FIXED_VALUE`<br>Fixed expected value: `0`<br>Result handling: `ONE_RESULT`<br>Comparison: `EQUALS`<br>No rows: `PASS` | The Query check counts Contact Roles on open Opportunities whose Contact has neither Email nor Phone. It passes when the count is zero. It checks presence, not whether the contact details are valid. |
| 120 | Comparison query: `SELECT Role FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false AND Role != null`<br>Find value formula: `"Technical Buyer"`<br>Result handling: `COMPARE_AS_LISTS`<br>Comparison: `LIST_CONTAINS_ANY`<br>Applies when this count is greater than zero: `SELECT COUNT() FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false`<br>No rows: `FAIL` | The Query check searches the Role values on open Opportunities for Technical Buyer. It passes when the role appears. Found shows the value being sought; Expected shows the returned list to search. |
| 130 | Source query: `SELECT COUNT() FROM Case WHERE AccountId = {!record.Id} AND IsClosed = true AND ClosedDate = LAST_N_DAYS:30`<br>Comparison query: `SELECT COUNT() FROM Case WHERE AccountId = {!record.Id} AND CreatedDate = LAST_N_DAYS:30`<br>Expected value source: `COMPARISON_QUERY`<br>Result handling: `ONE_RESULT`<br>Comparison: `GREATER_THAN_OR_EQUAL`<br>No rows: `FAIL` | The Query check compares 30-day Case resolution throughput with intake and passes when closures meet or exceed new demand, making backlog direction visible at the Account level. |

## Compare Two Queries Checks

Start with two counts on the same object: Amount, Next Step, and Campaign field coverage (140–160).
Then add a date range (170), related Contact Role coverage (180–190), currency totals (200–210),
and finally list overlap, containment, and exact matching (220–240).

### Compare Two Queries summary

| Order | Check and installed API name | Found in Acme | Expected in Acme | Outcome |
| ---: | --- | --- | --- | --- |
| 140 | Every won Opportunity has an Amount<br>`Example_Parent_Cities_Require_Data` | 0 | to equal 1 | Fail (Warning) |
| 150 | Every proposal has a Next Step<br>`Example_Contact_Vs_Open_Opp_Count` | 0 | to equal 1 | Fail (Warning) |
| 160 | Every proposal has a Primary Campaign Source<br>`Example_Guide_Open_Deals_Have_Contacts` | 0 | to equal 1 | Fail (Critical) |
| 170 | Open Opportunity Close Dates are in range<br>`Example_Distinct_Cities_Vs_Contacts` | 1 | to equal 2 | Fail (Info) |
| 180 | Every open Opportunity has a Contact Role<br>`Example_Oldest_Contact_City_Matches` | 1 | to equal 2 | Fail (Critical) |
| 190 | Every won Opportunity has a primary Contact<br>`Example_Earliest_Vs_Latest_Close` | Not produced | Not produced | Fail (Warning) |
| 200 | New pipeline value covers recently lost value<br>`Example_Open_Pipeline_Covers_Revenue` | $600,000.00 | at least $760,000.00 | Fail (Critical) |
| 210 | Total proposal Amount matches total Product value<br>`Example_Average_Deal_Vs_Largest` | Not produced | Not produced | Unable to Evaluate |
| 220 | Sales and service share a Contact name<br>`Example_Contact_Cities_Overlap_Parent` | [Jae Kim, Irene Kowalski, Mei Choi, Marcus Reed, Owen Murphy, Lucas Baker] | to overlap with [Thomas Gallagher, Sarah Bennett, Elena Ramirez, Gavin Scott] | Fail (Warning) |
| 230 | Sales Contact names cover priority Case Contacts<br>`Example_Parent_Covers_Contact_Cities` | [Thomas Gallagher, Sarah Bennett, Elena Ramirez, Gavin Scott] | to contain all of [Jae Kim, Irene Kowalski, Mei Choi] | Fail (Warning) |
| 240 | Open Opportunity names match those with Products<br>`Example_Contact_Cities_Exact_Parent` | [Acme Corporation Plant Modernization Expansion, Acme Corporation Managed Services Add-On] | to exactly match (none) | Fail (Warning) |

“Not produced” means this run did not produce a display value. Check 190 fails under its configured no-row
behavior before producing Found and Expected. Check 210 returns Unable to Evaluate because no
Opportunity Product total is available. Neither result implies that the missing value is zero.

The final three examples compare **names**, so duplicate names can hide differences between records.
Use record IDs when identity matters. Check 210 compares Account-wide totals: offsetting differences
between individual proposals can cancel each other out.

### Compare Two Queries configuration

| Order | Configuration | What this teaches |
| ---: | --- | --- |
| 140 | Source query: `SELECT COUNT() valuedDeals FROM Opportunity WHERE AccountId = {!record.Id} AND IsWon = true AND Amount != null`<br>Comparison query: `SELECT COUNT() allDeals FROM Opportunity WHERE AccountId = {!record.Id} AND IsWon = true`<br>Result handling: `ONE_RESULT`<br>Comparison: `EQUALS`<br>Applies when this count is greater than zero: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsWon = true`<br>No rows: `FAIL` | The Compare Two Queries check compares won Opportunities with won Opportunities whose Amount is not blank. It passes when both counts match. |
| 150 | Source query: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND StageName = 'Proposal/Price Quote' AND NextStep != null`<br>Comparison query: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND StageName = 'Proposal/Price Quote'`<br>Result handling: `ONE_RESULT`<br>Comparison: `EQUALS`<br>No rows: `FAIL` | The Compare Two Queries check counts proposals with Next Step and all proposals. It passes when the counts match. This checks that Next Step has text, not whether the action has been agreed. |
| 160 | Source query: `SELECT COUNT() coveredDeals FROM Opportunity WHERE AccountId = {!record.Id} AND StageName = 'Proposal/Price Quote' AND CampaignId != null`<br>Comparison query: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND StageName = 'Proposal/Price Quote'`<br>Result handling: `ONE_RESULT`<br>Comparison: `EQUALS`<br>Applies when this count is greater than zero: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false`<br>No rows: `FAIL` | The Compare Two Queries check counts proposals with a Primary Campaign Source and all proposals. It passes when the counts match. This checks the Campaign link, not the accuracy of attribution. |
| 170 | Source query: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false AND CloseDate = NEXT_N_DAYS:180`<br>Comparison query: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false`<br>Result handling: `ONE_RESULT`<br>Comparison: `EQUALS`<br>Applies when this count is greater than zero: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false`<br>No rows: `FAIL` | The Compare Two Queries check passes when every open Opportunity has a Close Date from today through the next 180 days, detecting both stale dates and dates outside the operating forecast horizon. |
| 180 | Source query: `SELECT COUNT_DISTINCT(OpportunityId) coveredDeals FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false`<br>Comparison query: `SELECT COUNT() allDeals FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false`<br>Result handling: `ONE_RESULT`<br>Comparison: `EQUALS`<br>Applies when this count is greater than zero: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false`<br>No rows: `FAIL` | The Compare Two Queries check compares open Opportunities with open Opportunities represented by at least one Opportunity Contact Role. It passes when both counts match. |
| 190 | Source query: `SELECT COUNT_DISTINCT(OpportunityId) coveredDeals FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsWon = true AND IsPrimary = true`<br>Comparison query: `SELECT COUNT() allDeals FROM Opportunity WHERE AccountId = {!record.Id} AND IsWon = true`<br>Result handling: `ONE_RESULT`<br>Comparison: `EQUALS`<br>Applies when this count is greater than zero: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsWon = true`<br>No rows: `FAIL` | The Compare Two Queries check passes when every won Opportunity retains a primary Contact Role, preserving buyer history for implementation handoff, renewal planning, and expansion. |
| 200 | Source query: `SELECT SUM(Amount) newPipeline FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false AND CreatedDate = LAST_N_DAYS:90 AND Amount != null`<br>Comparison query: `SELECT SUM(Amount) recentLosses FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = true AND IsWon = false AND CloseDate = LAST_N_DAYS:90 AND Amount != null`<br>Result handling: `ONE_RESULT`<br>Comparison: `GREATER_THAN_OR_EQUAL`<br>Applies when this count is greater than zero: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = true AND IsWon = false AND CloseDate = LAST_N_DAYS:90 AND Amount != null`<br>No rows: `FAIL` | The Compare Two Queries check compares Amount from open Opportunities created in the last 90 days with Amount from Opportunities closed lost in the same period. It passes when new pipeline value equals or exceeds lost value. |
| 210 | Source query: `SELECT SUM(Amount) proposalAmount FROM Opportunity WHERE AccountId = {!record.Id} AND StageName = 'Proposal/Price Quote' AND Amount != null`<br>Comparison query: `SELECT SUM(TotalPrice) productTotal FROM OpportunityLineItem WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.StageName = 'Proposal/Price Quote'`<br>Result handling: `ONE_RESULT`<br>Comparison: `EQUALS`<br>Applies when this count is greater than zero: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND StageName = 'Proposal/Price Quote' AND Amount != null`<br>No rows: `UNABLE_TO_EVALUATE` | The Compare Two Queries check sums proposal Amounts and Product Total Prices across the Account. It passes when the totals match. Differences between individual proposals can cancel out; this is an Account-level reconciliation. |
| 220 | Source query: `SELECT Contact.Name FROM Case WHERE AccountId = {!record.Id} AND IsClosed = false AND ContactId != null`<br>Comparison query: `SELECT Contact.Name FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false AND ContactId != null`<br>Result handling: `COMPARE_AS_LISTS`<br>Comparison: `LISTS_OVERLAP`<br>Applies when this count is greater than zero: `SELECT COUNT() FROM Case WHERE AccountId = {!record.Id} AND IsClosed = false AND ContactId != null`<br>No rows: `SKIP` | The Compare Two Queries check compares Contact names on open Cases with names on open Opportunities. It passes when the lists overlap. Matching names do not prove Contact identity; use IDs when distinct people can share a name. |
| 230 | Source query: `SELECT Contact.Name FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false AND ContactId != null`<br>Comparison query: `SELECT Contact.Name FROM Case WHERE AccountId = {!record.Id} AND IsClosed = false AND Priority = 'High' AND ContactId != null`<br>Result handling: `COMPARE_AS_LISTS`<br>Comparison: `LISTS_CONTAIN_ALL`<br>Applies when this count is greater than zero: `SELECT COUNT() FROM Case WHERE AccountId = {!record.Id} AND IsClosed = false AND Priority = 'High' AND ContactId != null`<br>No rows: `SKIP` | The Compare Two Queries check compares Contact names on open Opportunities with names on high-priority open Cases. It passes when the first list contains every name in the second. Shared names can represent different Contacts. |
| 240 | Source query: `SELECT Name FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false`<br>Comparison query: `SELECT Opportunity.Name FROM OpportunityLineItem WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false`<br>Result handling: `COMPARE_AS_LISTS`<br>Comparison: `LISTS_MATCH_EXACTLY`<br>Applies when this count is greater than zero: `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false`<br>No rows: `FAIL` | The Compare Two Queries check compares open Opportunity names with names represented by Products. It passes when the lists match exactly. Duplicate names can hide missing Product coverage; use IDs when names are not unique. |

## Apex Check

### Check 250: Account activity meets the operating cadence

| Check field | Value |
| --- | --- |
| Check API name | `Example_Guide_Recent_Activity` |
| Evaluation Order | 250 |
| Evaluation Type | Apex |
| Description | Apex evaluation counts completed Tasks and Events related to the Account during the configured 60-day period. It passes when the count meets the configured minimum of two; the class does not decide whether each activity was meaningful customer engagement. |
| Apex Class | `AccountHasRecentActivityCheck` |
| Apex Parameters | `{"daysBack": 60, "minimumActivities": 2}` |
| Applies When | Every Account |
| Found | `Completed activities: 2` |
| Expected | `Minimum: 2 in 60 days` |
| Demo result | Pass |
| Failure Severity | Warning |
| Failure Message | `Fewer than two completed Account activities are documented for {!record.Name fallback="this Account"} in the last 60 days.` |
| Fix Instructions | Review the completed Tasks and Events and their outcomes. Log only work that occurred, or change the period and minimum to match the approved Account-management cadence. |
| Action | **Review Account activity** → open a new Task |

The current demo produces **7 Passed, 17 Failed, 0 Skipped, and 1 Unable to Evaluate**.

### Demo data for these results

| Salesforce data | Required demo value | Checks proved |
| --- | --- | --- |
| Account **Type**, **Phone**, and **Website** | Type is Customer; Phone and Website are populated | Checks 10 and 20 pass the basic field examples. |
| One open Case | **Escalated** selected and **Description** blank | Check 70 identifies a blank Description. |
| Recently lost Opportunity Amounts | Combined Amount of `$760,000` | Check 200 shows `$600,000` of new pipeline does not replace recently lost value. |
| Historical won Opportunity | Amount remains blank | Check 140 fails without a supported won Amount. |
| Opportunity Products | None | Check 210 returns Unable to Evaluate and Check 240 fails product coverage. |

## What the user sees

### Failure guidance and actions

This table contains the Check-specific response. It does not repeat the shared Unable to Evaluate
guidance.

| Order | When the Check fails | Administrator response | Action link |
| ---: | --- | --- | --- |
| 40 | More than one high-priority Case is open. | Review Case ownership, customer impact, and recovery plans. Escalate excess work; do not lower Priority only to pass. | Account Cases |
| 50 | No open Opportunity is included in the Commit forecast category. | Review forecast judgment with the Opportunity owners. Update Forecast Category only when the current customer commitment supports it. | Account Opportunities |
| 60 | One or more open Cases have no Contact. | Add the customer Contact who can confirm impact and resolution, or close Cases that no longer require work. | Account Cases |
| 70 | An open escalated Case has no Description. | Add a concise, verified explanation of the customer impact and current recovery work. Do not add generic text only to pass. | Account Cases |
| 80 | An open Opportunity is owned by an inactive Salesforce user. | Transfer the Opportunity through the approved ownership process and confirm that forecasts, activities, and access remain correct. | Account Opportunities |
| 90 | A proposal-stage Amount is blank or below the approved floor. | Validate scope, pricing, and commercial fit. Requalify the deal or return it to an earlier Stage; do not inflate Amount. | Account Opportunities |
| 100 | No Decision Maker Contact Role exists on an open Opportunity. | Confirm buying authority with the customer and add the verified Contact Role. Do not infer authority from job title. | Account Opportunities |
| 110 | An open-deal Contact has neither email nor phone. | Confirm permitted contact information with the customer. Remove obsolete Contact Roles when appropriate. | Account Contacts |
| 120 | No open-deal Contact Role is `Technical Buyer`. | Confirm who evaluates the solution and add the verified Contact Role. | Account Opportunities |
| 130 | Case closures are lower than Case intake. | Review staffing, Case ownership, repeated causes, and aged work before changing the target. | Account Cases |
| 140 | A won Opportunity has no Amount. | Recover the Amount from approved sales records when evidence exists. Do not invent historical value. | Account Opportunities |
| 150 | A proposal-stage Opportunity has no Next Step. | Confirm the next customer action, owner, and timing, then update **Next Step**. | Account Opportunities |
| 160 | A proposal-stage Opportunity has no Primary Campaign Source. | Confirm the originating Campaign and populate **Primary Campaign Source** only when attribution is supported. | Account Opportunities |
| 170 | An open Opportunity has a past Close Date or a date beyond 180 days. | Reconfirm customer timing and update only Close Dates supported by the current plan. | Account Opportunities |
| 180 | An open Opportunity has no Opportunity Contact Role. | Add a verified customer Contact Role to each open deal. Do not use an unrelated or placeholder Contact. | Account Opportunities |
| 190 | A won Opportunity has no primary Contact Role. | Identify the primary buyer from supported history and mark that Contact Role as primary. | Account Opportunities |
| 200 | New open pipeline Amount does not replace recently lost Amount. | Review loss reasons, deal value, and the Account plan. Create only Opportunities supported by a real customer initiative. | Account Opportunities |
| 210 | Proposal Amount and Opportunity Product Total Price do not match, or no Product total is available. | Confirm products, quantities, prices, discounts, and the Opportunity Amount before correcting either total. | Account Opportunities |
| 220 | Open sales and service work have no Contact name in common. | Confirm whether the teams should share a stakeholder. Change the Check if separate Contacts are intentional. | Account record |
| 230 | A priority service Contact name is absent from open sales work. | Decide whether sales needs that Contact represented. Add a legitimate Contact Role or change the handoff rule. | Account record |
| 240 | The open Opportunity name list differs from the names represented by Products. | Confirm whether the sales process uses Products. Add verified Products and prices, or deactivate the Check. | Account record |

## Security and access

SOQL and Apex read Salesforce data with the running user's sharing, object access, and field
access. A System Administrator can see more data than the intended user, so administrator-only
testing does not prove that Found, Expected, or the final result is correct for production users.

## Test the Check

Test each Check with the same Salesforce access assigned to its intended users.

| Result to prove | Required test |
| --- | --- |
| Pass | Create or select Account data that meets the stated requirement. Confirm Found and Expected show only the values in this page. |
| Fail | Change one relevant Salesforce value so the requirement is not met. Confirm severity, failure message, Fix Instructions, and Action link. |
| Skipped | Remove the data named in **Applies When**. Confirm the skipped message explains why the Check does not apply. |
| Unable to Evaluate | Test with a user who intentionally lacks access to one required object or field. Confirm the result gives administrator guidance without exposing data the user cannot read. Restore access after the test. |
| Sharing | Keep one relevant related record outside the test user's sharing access. Confirm Found reflects only records that user can access. |
| API identity | Installed examples retain legacy API names. In Setup, use the Check title and description to identify the current requirement. Copy the Qualified API Name rather than typing it from memory. |

## Adapt the examples to your org

| Order | Setting or requirement to consider |
| ---: | --- |
| 10 | Which Type values describe your Account relationships? This example accepts any populated Type, including values added by your org. |
| 20 | Is either Phone or Website sufficient? This example checks presence, so decide separately whether format or reachability validation is needed. |
| 30 | Does centralized billing require the child address to match its parent? Define how to handle legitimate address differences; a missing parent skips. |
| 40 | Is one simultaneous high-priority Case the approved capacity, and should exceeding it be Critical for every Account segment? |
| 50 | Does the sales organization use **Forecast Category** `Commit`, and is one Commit deal per Account a useful requirement? |
| 60 | Should an Account with no open Cases Pass or Skip, and is **Contact Name** mandatory for every Case type and channel? |
| 70 | Is **Case Description** the approved place for customer impact, or does the org use another standard or custom Case field? |
| 80 | Confirm that all open Opportunities are user-owned and that **Owner Active** is readable by intended users. Define the approved transfer process for inactive owners. |
| 90 | Confirm the proposal Stage value, `$25,000` floor, currency behavior, and whether blank Amount should be treated the same as an Amount below the floor. |
| 100 | Is one Decision Maker anywhere in open pipeline enough, or must every qualifying Opportunity have one? Confirm the exact Contact Role value. |
| 110 | Is either Email or Phone sufficient, and may the intended users read both fields for every Contact Role they can see? |
| 120 | Confirm the exact `Technical Buyer` Contact Role value and which Opportunity Stages require it. |
| 130 | Is 30 days long enough for meaningful Account-level Case volume, and should the comparison use all Cases or only selected Case types? |
| 140 | Must every won Opportunity have Amount, and how should migrated or confidential historical deals be handled? |
| 150 | Does **Next Step** contain the agreed customer action, or does the sales process store mutual actions elsewhere? |
| 160 | Does the organization consistently maintain **Primary Campaign Source** before proposal Stage, including Opportunities created without a Campaign? |
| 170 | Is 180 days the approved planning horizon for every sales motion, and should overdue Close Dates be reported separately from dates beyond the horizon? |
| 180 | Must every open Opportunity have a Contact Role, or only Opportunities at selected Stages? |
| 190 | Must every won Opportunity retain a primary Contact Role, including renewals, channel deals, and migrated history? |
| 200 | Confirm the 90-day period, currency handling, which open Stages count as replacement pipeline, and whether Amount is the approved measure of replaced value. |
| 210 | Is Opportunity **Amount** expected to equal Opportunity Product **Total Price**, or can services, taxes, adjustments, or manual pricing create approved differences? |
| 220 | Which Account segments require one Contact to connect open sales and service work? If separate Contacts are normal, deactivate or narrow this Check. |
| 230 | Must every priority service Contact appear on an open Opportunity, or is sales awareness recorded through Account Teams, notes, or another Salesforce relationship? |
| 240 | Does the sales process require Opportunity Products on every open Opportunity or only after a selected Stage? |
| 250 | Which Task and Event types count toward the cadence? The current Apex class counts completed Account Tasks and Events but does not determine whether each activity was meaningful customer engagement. |

Also identify every Flow, Apex class, report, integration, or saved reference that uses an existing
Check Qualified API Name before changing an API name.

## Related

- [Configure Check Sets and Checks](../build-checks/configure-check-sets-and-checks.md)
- [Check Custom Metadata fields](../reference/custom-metadata/check-fields.md)
- [Found and Expected configuration](../reference/configuration/display-found-and-expected.md)
- [Examples](./README.md)
