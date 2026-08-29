# Account Check Builder Guide: complete Check review

> **Audience: Salesforce administrators.** This is a human-review specification for the 25 Account
> Checks included in the demo. It is not approval to deploy them unchanged. Confirm every business
> threshold, Stage value, Contact Role value, permission, and sharing assumption in a sandbox.

Use this page to review the complete Check design before the Custom Metadata records are renamed or
updated. Every description starts with the selected **Evaluation Type** and explains which
Salesforce data it checks. API names describe the same business rule as the Check name.

> On this page, review the complete Salesforce configuration, card wording, demo result, and test
> expectations for every Check in the Account Check Builder Guide.

## Scenario

An administrator needs one review page before approving the 25 demo Checks for subscribers to
clone. The page must make each business rule, Salesforce field, related record, outcome, and next
step understandable without requiring source-code knowledge.

## Why this Evaluation Type matters

Use **Formula** for Account fields and parent Account fields, **Query** for one set of related
Salesforce records, **Compare Two Queries** when two related-record results must agree, and **Apex**
only when the supported Formula and Query settings cannot safely express the requirement.

## Review rules

1. Say each fact once. Later tables add configuration or remediation; they do not restate the
   description.
2. **Found** reports only the Salesforce value that was checked. **Expected** reports only the
   required value or comparison.
3. Use Salesforce terms a junior administrator can recognize from Setup, Object Manager, reports,
   formulas, SOQL, Flow Builder, or record pages.
4. The Check API name must describe the same requirement as the Check name.
5. A passing demo Check must still define its failure, skipped, and Unable to Evaluate behavior.

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

### Check 10: SLA renewal is secured beyond 60 days

| Check field | Proposed value |
| --- | --- |
| Check API name | `SLA_Renewal_Secured_Beyond_60_Days` |
| Evaluation Order | 10 |
| Evaluation Type | Formula |
| Description | Formula evaluation compares the Account **SLA Expiration Date** with the date 60 days from today. It passes when the renewed term extends beyond that date and fails when expiry is inside the renewal-risk window. |
| Applies When | **SLA Expiration Date** has a value. |
| Applicability Formula | `NOT(ISBLANK(SLAExpirationDate__c))` |
| Pass Formula | `SLAExpirationDate__c > TODAY() + 60` |
| Found | `{!rhcResult.foundValue}` |
| Found Formula | `TEXT(SLAExpirationDate__c)` |
| Expected | `{!rhcResult.expectedValue}` |
| Expected Formula | `"More than 60 days"` |
| Demo result | Warning failure. The proposed demo SLA Expiration Date is 45 days from setup. |
| Failure Severity | Warning |
| Failure Message | `{!record.Name fallback="This Account"} has an SLA Expiration Date within the next 60 days and does not show a renewed term beyond the renewal-risk window.` |
| Skipped Message | `{!record.Name fallback="This Account"} has no SLA Expiration Date, so renewal timing cannot be checked.` |
| Fix Instructions | Confirm renewal status with the Account owner and contracting team. If the renewal is signed, update **SLA Expiration Date** from the approved term. Otherwise, document the renewal plan. Do not move the date only to pass the Check. |
| Action | **Review SLA renewal** → edit the Account |
| Rating | Understandability 10 · Business value 10 · Logic depth 10 · **30/30** |

### Check 20: Billing address matches the parent bill-to Account

| Check field | Proposed value |
| --- | --- |
| Check API name | `Billing_Address_Matches_Parent` |
| Evaluation Order | 20 |
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
| Rating | Understandability 10 · Business value 10 · Logic depth 9 · **29/30** |

### Check 30: Strategic Accounts have an Account Number

| Check field | Proposed value |
| --- | --- |
| Check API name | `Strategic_Account_Has_Account_Number` |
| Evaluation Order | 30 |
| Evaluation Type | Formula |
| Description | Formula evaluation checks whether **Account Number** has a value for an Account above the strategic-Account revenue threshold. It passes when the Account has a customer identifier for downstream Salesforce and business processes. |
| Applies When | **Annual Revenue** is greater than `$1,000,000`. |
| Applicability Formula | `AnnualRevenue > 1000000` |
| Pass Formula | `NOT(ISBLANK(AccountNumber))` |
| Found | Account Number value, or `Missing` |
| Found Formula | `IF(ISBLANK(AccountNumber), "Missing", AccountNumber)` |
| Expected | `Account Number is required` |
| Expected Formula | `"Account Number is required"` |
| Demo result | Skipped. Demo Annual Revenue is `$500,000`. |
| Failure Severity | Warning |
| Failure Message | `{!record.Name fallback="This Account"} meets the strategic-Account threshold but has no Account Number for customer identification.` |
| Skipped Message | `{!record.Name fallback="This Account"} is below the $1 million strategic-Account threshold, so this Check does not apply.` |
| Fix Instructions | Confirm the approved customer identifier with the team that owns Account data, then populate **Account Number**. Do not enter a placeholder value. Replace the example revenue threshold with the organization's approved definition of a strategic Account. |
| Action | **Review Account Number** → edit the Account |
| Rating | Understandability 10 · Business value 9 · Logic depth 10 · **29/30** |

## Query Checks

### Query Check summary

| Order | Check name and API name | Found | Expected | Demo and rating | Description |
| ---: | --- | --- | --- | --- | --- |
| 40 | Open pipeline has an identified decision maker<br>`Open_Pipeline_Has_Decision_Maker` | `Decision Makers: 1` | `Minimum: 1` | Pass · **30/30** | Query evaluation counts **Opportunity Contact Roles** marked `Decision Maker` on open Opportunities. It passes when the Account has at least one. |
| 50 | Every open Case identifies a customer Contact<br>`Open_Cases_Have_Customer_Contacts` | `Missing Contacts: 6 of 12` | `Required missing Contacts: 0` | Critical failure · **29/30** | Query evaluation checks **Contact Name** on every open Case. It passes only when every returned Case has a Contact. |
| 60 | High-priority Cases stay within escalation capacity<br>`High_Cases_Within_Escalation_Capacity` | `High-priority Cases: 4` | `Maximum: 1` | Critical failure · **30/30** | Query evaluation counts open Cases with **Priority** `High`. It passes when no more than one high-priority Case requires Account-level escalation at the same time. |
| 70 | Escalated Cases document customer impact<br>`Escalated_Cases_Document_Impact` | `Missing descriptions: 1 of 1` | `Required missing descriptions: 0` | Warning failure · **30/30** | Query evaluation checks **Description** on every open Case where **Escalated** is selected. It passes only when every escalated Case explains the customer impact. |
| 80 | Proposal-stage deals meet the value floor<br>`Proposal_Deals_Meet_Value_Floor` | `Deals below floor: None` | `No proposal below $25,000` | Pass · **30/30** | Query evaluation returns only proposal-stage Opportunities whose Amount is blank or below `$25,000`. It passes when the query returns no Opportunity names. |
| 90 | Open Opportunities have active owners<br>`Open_Opportunities_Have_Active_Owners` | `Inactive owners: 0 of 2` | `Required inactive owners: 0` | Pass · **30/30** | Query evaluation checks **Active** on the owner of every open Opportunity. It passes only when every Opportunity owner is an active Salesforce user. |
| 100 | Open pipeline includes a Commit deal<br>`Open_Pipeline_Has_Commit_Deal` | `Commit deals: 0` | `Minimum: 1` | Warning failure · **29/30** | Query evaluation counts open Opportunities with **Forecast Category** `Commit`. It passes when at least one open deal is included in the committed forecast. |
| 110 | Open-deal stakeholders are reachable<br>`Open_Deal_Stakeholders_Are_Reachable` | `Unreachable stakeholders: 1` | `Required: 0` | Warning failure · **29/30** | Query evaluation counts open-deal Contact Roles whose Contact has neither **Email** nor **Phone**. It passes only when the count is zero. |
| 120 | Open deals include a Technical Buyer<br>`Open_Deals_Have_Technical_Buyer` | `Roles: Decision Maker; Executive Sponsor; Business User` | `Required role: Technical Buyer` | Information failure · **30/30** | Query evaluation reads **Role** from Contact Roles on open Opportunities. It passes when the returned roles include `Technical Buyer`. |
| 130 | Case closures keep pace with intake<br>`Case_Closures_Keep_Pace_With_Intake` | `Cases closed: 4` | `Cases created: 16` | Warning failure · **29/30** | Query evaluation compares Cases closed in the last 30 days with Cases created in the same period. It passes when closures equal or exceed intake; use a longer period when Account-level volume is too low for a useful comparison. |

### Query Check configuration

| Order | SOQL and comparison | When no records are returned |
| ---: | --- | --- |
| 40 | `SELECT COUNT() FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false AND Role = 'Decision Maker'`; compare the count with fixed value `1` using **Greater Than or Equal**. | Fail |
| 50 | `SELECT ContactId FROM Case WHERE AccountId = {!record.Id} AND IsClosed = false`; check every **ContactId** using **Is Not Blank**. | Pass because there are no open Cases to review. |
| 60 | `SELECT COUNT() FROM Case WHERE AccountId = {!record.Id} AND IsClosed = false AND Priority = 'High'`; compare the count with fixed value `1` using **Less Than or Equal**. | The count is zero, which passes. |
| 70 | `SELECT Description FROM Case WHERE AccountId = {!record.Id} AND IsClosed = false AND IsEscalated = true`; check every **Description** using **Is Not Blank**. | Skip because no open escalated Case needs impact documentation. |
| 80 | `SELECT Name FROM Opportunity WHERE AccountId = {!record.Id} AND StageName = 'Proposal/Price Quote' AND (Amount = null OR Amount < 25000)`; check every returned **Name** using **Is Blank**. A returned name identifies a proposal that missed the floor. | Pass because no proposal missed the floor. |
| 90 | `SELECT Owner.IsActive FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false`; check every **Owner.IsActive** using **Equals** with fixed value `true`. | Pass because there is no open Opportunity owner to review. |
| 100 | `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false AND ForecastCategoryName = 'Commit'`; compare the count with fixed value `1` using **Greater Than or Equal**. | Fail because no open Opportunity is included in Commit. |
| 110 | `SELECT COUNT() unreachableStakeholders FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false AND ContactId != null AND Contact.Email = null AND Contact.Phone = null`; compare `unreachableStakeholders` with `0` using **Equals**. | The count is zero, which passes. |
| 120 | `SELECT Role FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false AND Role != null`; check whether the returned roles include `Technical Buyer`. | Skip because no open-deal Contact Role exists to review. |
| 130 | Found query: `SELECT COUNT() FROM Case WHERE AccountId = {!record.Id} AND IsClosed = true AND ClosedDate = LAST_N_DAYS:30`. Expected query: `SELECT COUNT() FROM Case WHERE AccountId = {!record.Id} AND CreatedDate = LAST_N_DAYS:30`. Compare using **Greater Than or Equal**. | Both counts are zero, which passes. |

## Compare Two Queries Checks

### Compare Two Queries summary

| Order | Check name and API name | Found | Expected | Demo and rating | Description |
| ---: | --- | --- | --- | --- | --- |
| 140 | Every proposal-stage deal has a mutual action<br>`Proposal_Deals_Have_Mutual_Action` | `Deals with Next Step: 0` | `Proposal-stage deals: 1` | Warning failure · **29/30** | Compare Two Queries evaluation compares proposal-stage Opportunities with the subset where **Next Step** is not blank. It passes when both Opportunity lists match. |
| 150 | Every open Opportunity has a Contact Role<br>`Open_Deals_Have_Contact_Roles` | `Deals with Contact Roles: 1` | `Open deals: 2` | Critical failure · **30/30** | Compare Two Queries evaluation compares open Opportunities with open Opportunities represented by at least one Opportunity Contact Role. It passes when both counts match. |
| 160 | Every proposal-stage deal has a Primary Campaign Source<br>`Proposal_Deals_Have_Campaign_Source` | `Deals with campaign source: 0` | `Proposal-stage deals: 1` | Warning failure · **29/30** | Compare Two Queries evaluation compares proposal-stage Opportunities with the subset where **Primary Campaign Source** is selected. It passes when both Opportunity counts match. |
| 170 | New pipeline value replaces recent losses<br>`New_Pipeline_Value_Replaces_Losses` | `New open pipeline: $600,000` | `Recently lost value: $760,000` | Critical failure · **30/30** | Compare Two Queries evaluation compares Amount from open Opportunities created in the last 90 days with Amount from Opportunities closed lost in the same period. It passes when new pipeline value equals or exceeds lost value. |
| 180 | Proposal Amount matches the Opportunity Product total<br>`Proposal_Amount_Matches_Product_Total` | `Proposal Amount: $600,000` | `Opportunity Product total: unavailable` | Unable to Evaluate · **30/30** | Compare Two Queries evaluation compares total Amount from proposal-stage Opportunities with Total Price from their Opportunity Products. It passes when both totals match and returns Unable to Evaluate when no Product total exists. |
| 190 | Every won deal has a primary Contact<br>`Won_Deals_Have_Primary_Contacts` | `Won deals with primary Contact: 0` | `Won deals: 1` | Warning failure · **30/30** | Compare Two Queries evaluation compares won Opportunities with won Opportunities that retain a primary Contact Role. It passes when both counts match. |
| 200 | Every open deal is inside the 180-day planning horizon<br>`Open_Deals_Within_180_Day_Horizon` | `Deals inside horizon: 1` | `Open deals: 2` | Information failure · **29/30** | Compare Two Queries evaluation compares open Opportunities with those whose **Close Date** is today through the next 180 days. It passes when both counts match. |
| 210 | Sales and service share a customer Contact<br>`Sales_And_Service_Share_Contacts` | `Open Case Contacts: 6` | `Open Opportunity Contacts: 4` | Warning failure · **29/30** | Compare Two Queries evaluation compares Contacts on open Cases with Contacts on open Opportunities. It passes when the two lists share at least one Contact. |
| 220 | Sales covers priority service Contacts<br>`Sales_Covers_Priority_Service_Contacts` | `Open Opportunity Contacts: 4` | `Priority service Contacts: 3` | Warning failure · **29/30** | Compare Two Queries evaluation compares open-Opportunity Contacts with Contacts on high-priority open Cases. It passes when the sales list contains every priority service Contact. |
| 230 | Every open Opportunity has a Product<br>`Open_Opportunities_Have_Products` | `Open Opportunities: 2` | `Opportunities with Products: 0` | Warning failure · **29/30** | Compare Two Queries evaluation compares open Opportunity names with Opportunity names returned from **Opportunity Products**. It passes when both lists match. |
| 240 | Every won Opportunity retains an Amount<br>`Won_Opportunities_Have_Amounts` | `Won deals with Amount: 0` | `Won deals: 1` | Warning failure · **30/30** | Compare Two Queries evaluation compares won Opportunities with won Opportunities whose **Amount** is not blank. It passes when both counts match. |

### Compare Two Queries configuration

| Order | Found query | Expected query and required comparison | Applies when |
| ---: | --- | --- | --- |
| 140 | Proposal Opportunity names where **Next Step** is not blank | All proposal Opportunity names; both lists must match exactly. | At least one proposal-stage Opportunity exists. |
| 150 | Count of distinct open Opportunities represented by an Opportunity Contact Role | Count of all open Opportunities; both counts must be equal. | At least one open Opportunity exists. |
| 160 | Count of proposal Opportunities where **Primary Campaign Source** is selected | Count of all proposal Opportunities; both counts must be equal. | At least one proposal-stage Opportunity exists. |
| 170 | `SUM(Amount)` for open Opportunities created in the last 90 days | `SUM(Amount)` for Opportunities closed lost in the last 90 days; Found must be greater than or equal to Expected. | At least one recently lost Opportunity has an Amount. |
| 180 | `SUM(Amount)` for proposal-stage Opportunities | `SUM(TotalPrice)` from Opportunity Products on those proposals; both totals must be equal. A missing Product total returns **Unable to Evaluate**. | At least one proposal-stage Opportunity has an Amount. |
| 190 | Count of won Opportunities represented by a primary Contact Role | Count of all won Opportunities; both counts must be equal. | At least one won Opportunity exists. |
| 200 | Count of open Opportunities whose **Close Date** is within the next 180 days | Count of all open Opportunities; both counts must be equal. | At least one open Opportunity exists. |
| 210 | Contact names on open Cases | Contact names on open Opportunity Contact Roles; the lists must share at least one name. | At least one open Case has a Contact. |
| 220 | Contact names on open Opportunity Contact Roles | Contact names on high-priority open Cases; Found must contain every Expected name. | At least one high-priority open Case has a Contact. |
| 230 | Names of all open Opportunities | Opportunity names returned from Opportunity Products; both lists must match exactly. | At least one open Opportunity exists. |
| 240 | Count of won Opportunities where **Amount** is not blank | Count of all won Opportunities; both counts must be equal. | At least one won Opportunity exists. |

## Apex Check

### Check 250: Account activity meets the operating cadence

| Check field | Proposed value |
| --- | --- |
| Check API name | `Account_Activity_Meets_Cadence` |
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
| Rating | Understandability 10 · Business value 10 · Logic depth 10 · **30/30** |

The proposed demo remains **5 Passed, 18 Failed, 1 Skipped, and 1 Unable to Evaluate**.

### Demo data changes required by this review

| Salesforce data | Required demo value | Checks proved |
| --- | --- | --- |
| Account **SLA Expiration Date** | 45 days from setup | Check 10 fails inside the renewal-risk window. |
| One open Case | **Escalated** selected and **Description** blank | Check 70 identifies missing customer-impact documentation. |
| Recently lost Opportunity Amounts | Combined Amount of `$760,000` | Check 170 shows `$600,000` of new pipeline does not replace recently lost value. |
| Historical won Opportunity | Amount remains blank | Check 240 fails without a supported won Amount. |
| Opportunity Products | None | Check 180 returns Unable to Evaluate and Check 230 fails product coverage. |

## What the user sees

### Failure guidance and actions

This table contains the Check-specific response. It does not repeat the shared Unable to Evaluate
guidance.

| Order | When the Check fails | Administrator response | Action link |
| ---: | --- | --- | --- |
| 40 | No Decision Maker Contact Role exists on an open Opportunity. | Confirm buying authority with the customer and add the verified Contact Role. Do not infer authority from job title. | Account Opportunities |
| 50 | One or more open Cases have no Contact. | Add the customer Contact who can confirm impact and resolution, or close Cases that no longer require work. | Account Cases |
| 60 | More than one high-priority Case is open. | Review Case ownership, customer impact, and recovery plans. Escalate excess work; do not lower Priority only to pass. | Account Cases |
| 70 | An open escalated Case has no customer-impact description. | Add a concise, verified explanation of the customer impact and current recovery work. Do not add generic text only to pass. | Account Cases |
| 80 | A proposal-stage Amount is below the approved floor. | Validate scope, pricing, and commercial fit. Requalify the deal or return it to an earlier Stage; do not inflate Amount. | Account Opportunities |
| 90 | An open Opportunity is owned by an inactive Salesforce user. | Transfer the Opportunity through the approved ownership process and confirm that forecasts, activities, and access remain correct. | Account Opportunities |
| 100 | No open Opportunity is included in the Commit forecast category. | Review forecast judgment with the Opportunity owners. Update Forecast Category only when the current customer commitment supports it. | Account Opportunities |
| 110 | An open-deal Contact has neither email nor phone. | Confirm permitted contact information with the customer. Remove obsolete Contact Roles when appropriate. | Account Contacts |
| 120 | No open-deal Contact Role is `Technical Buyer`. | Confirm who evaluates the solution and add the verified Contact Role. | Account Opportunities |
| 130 | Case closures are lower than Case intake. | Review staffing, Case ownership, repeated causes, and aged work before changing the target. | Account Cases |
| 140 | A proposal-stage Opportunity has no Next Step. | Confirm the next customer action, owner, and timing, then update **Next Step**. | Account Opportunities |
| 150 | An open Opportunity has no Opportunity Contact Role. | Add a verified customer Contact Role to each open deal. Do not use an unrelated or placeholder Contact. | Account Opportunities |
| 160 | A proposal-stage Opportunity has no Primary Campaign Source. | Confirm the originating Campaign and populate **Primary Campaign Source** only when attribution is supported. | Account Opportunities |
| 170 | New open pipeline Amount does not replace recently lost Amount. | Review loss reasons, deal value, and the Account plan. Create only Opportunities supported by a real customer initiative. | Account Opportunities |
| 180 | Proposal Amount and Opportunity Product Total Price do not match, or no Product total is available. | Confirm products, quantities, prices, discounts, and the Opportunity Amount before correcting either total. | Account Opportunities |
| 190 | A won Opportunity has no primary Contact Role. | Identify the primary buyer from supported history and mark that Contact Role as primary. | Account Opportunities |
| 200 | An open Opportunity has a past Close Date or a date beyond 180 days. | Reconfirm customer timing and update only Close Dates supported by the current plan. | Account Opportunities |
| 210 | Open sales and service work have no Contact in common. | Confirm whether the teams should share a stakeholder. Change the Check if separate Contacts are intentional. | Account record |
| 220 | A priority service Contact is absent from open sales work. | Decide whether sales needs that Contact represented. Add a legitimate Contact Role or change the handoff rule. | Account record |
| 230 | An open Opportunity has no Opportunity Product. | Confirm whether the sales process uses Products. Add verified Products and prices, or deactivate the Check. | Account record |
| 240 | A won Opportunity has no Amount. | Recover the Amount from approved sales records when evidence exists. Do not invent historical value. | Account Opportunities |

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
| API identity | In Setup, confirm the Check name and Qualified API Name describe the same requirement. Copy the Qualified API Name rather than typing it from memory. |

## Approval questions before metadata changes

| Order | Question the administrator must answer |
| ---: | --- |
| 10 | Does **SLA Expiration Date** move to the new term when renewal is signed? If not, use the verified renewal field or Contract relationship instead. Decide whether a blank or expired date should Fail rather than Skip or Warning. |
| 20 | Does centralized billing require every child Account address to match its parent, and how are legitimate legal-entity or address-format differences handled? |
| 30 | What Annual Revenue defines a strategic Account, who owns **Account Number**, and which approved system supplies that value? |
| 40 | Is one Decision Maker anywhere in open pipeline enough, or must every qualifying Opportunity have one? Confirm the exact Contact Role value. |
| 50 | Should an Account with no open Cases Pass or Skip, and is **Contact Name** mandatory for every Case type and channel? |
| 60 | Is one simultaneous high-priority Case the approved capacity, and should exceeding it be Critical for every Account segment? |
| 70 | Is **Case Description** the approved place for customer impact, or does the org use another standard or custom Case field? |
| 80 | Confirm the proposal Stage value, `$25,000` floor, currency behavior, and whether blank Amount should be treated the same as an Amount below the floor. |
| 90 | Confirm that all open Opportunities are user-owned and that **Owner Active** is readable by intended users. Define the approved transfer process for inactive owners. |
| 100 | Does the sales organization use **Forecast Category** `Commit`, and is one Commit deal per Account a useful requirement? |
| 110 | Is either Email or Phone sufficient, and may the intended users read both fields for every Contact Role they can see? |
| 120 | Confirm the exact `Technical Buyer` Contact Role value and which Opportunity Stages require it. |
| 130 | Is 30 days long enough for meaningful Account-level Case volume, and should the comparison use all Cases or only selected Case types? |
| 140 | Does **Next Step** contain the agreed customer action, or does the sales process store mutual actions elsewhere? |
| 150 | Must every open Opportunity have a Contact Role, or only Opportunities at selected Stages? |
| 160 | Does the organization consistently maintain **Primary Campaign Source** before proposal Stage, including Opportunities created without a Campaign? |
| 170 | Confirm the 90-day period, currency handling, which open Stages count as replacement pipeline, and whether Amount is the approved measure of replaced value. |
| 180 | Is Opportunity **Amount** expected to equal Opportunity Product **Total Price**, or can services, taxes, adjustments, or manual pricing create approved differences? |
| 190 | Must every won Opportunity retain a primary Contact Role, including renewals, channel deals, and migrated history? |
| 200 | Is 180 days the approved planning horizon for every sales motion, and should overdue Close Dates be reported separately from dates beyond the horizon? |
| 210 | Which Account segments require one Contact to connect open sales and service work? If separate Contacts are normal, deactivate or narrow this Check. |
| 220 | Must every priority service Contact appear on an open Opportunity, or is sales awareness recorded through Account Teams, notes, or another Salesforce relationship? |
| 230 | Does the sales process require Opportunity Products on every open Opportunity or only after a selected Stage? |
| 240 | Must every won Opportunity have Amount, and how should migrated or confidential historical deals be handled? |
| 250 | Which Task and Event types count toward the cadence? The current Apex class counts completed Account Tasks and Events but does not determine whether each activity was meaningful customer engagement. |

Also identify every Flow, Apex class, report, integration, or saved reference that uses an existing
Check Qualified API Name before approving any API-name change.

## Related

- [Configure Check Sets and Checks](../build-checks/configure-check-sets-and-checks.md)
- [Check Custom Metadata fields](../reference/custom-metadata/check-fields.md)
- [Found and Expected configuration](../reference/configuration/display-found-and-expected.md)
- [Examples](./README.md)
