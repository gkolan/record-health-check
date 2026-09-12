/**
 * A Check Set card has to say what it is about in about three seconds.
 *
 * That is a judgement, but the ways it goes wrong are mechanical: a title that
 * names the mechanism instead of the subject, two cards wearing the same name,
 * a subtitle short enough to be a second label, and Checks whose reader-facing
 * fields were never filled in. Those are what this module checks.
 *
 * The purpose table is the anti-drift part. Every Check Set fixture must be
 * declared here, so a new card cannot appear without someone deciding which
 * kind of card it is and titling it accordingly.
 *
 * The four rules, in the order a reader meets them:
 *
 *   1. The title names the subject, never only the mechanism. A card called
 *      "Icon-Only Run and Rerun" describes a button and hides the eight Checks
 *      underneath it.
 *   2. No two cards share a title. If two cards are called the same thing,
 *      neither name means anything.
 *   3. The record label is the title. The label is the card's identity in
 *      Setup, so searching for what the card calls itself has to find it.
 *      Custom Metadata caps a label at MAX_LABEL characters, so a longer title
 *      may be cut short there — but only cut short, never reworded.
 *   4. The subtitle is a sentence about what the reader will see, not a second
 *      label. Presentation details come after the subject, not instead of it.
 *
 * A presentation setting may ride along on a subject card — the automatic
 * on-load card really is a data-quality card that also happens to run itself.
 * What is not allowed is letting the setting take over the title.
 *
 * The field tiers below are deliberately not uniform. The Check Builder Guide
 * populates all 43 fields because its job is to teach them, and
 * `check:package-boundary` enforces that separately. Applying it everywhere
 * would work against the three-second rule: the thirty Checks that exist only
 * to prove the 25-Check display ceiling do not need thirty invented pieces of
 * fix advice. So Tier A is what a reader sees on any Check, and Tier B adds
 * somewhere to go and something to do on the cards an administrator copies —
 * a Check on a coverage matrix is being read, not acted on.
 */

/** Title prefix each purpose must carry. A business card carries none. */
export const PURPOSE_PREFIX = {
  example: "Example: ",
  coverage: "Coverage: ",
  diagnostics: "Diagnostics: ",
  review: "Review: ",
  business: null
};

/** Every Check Set fixture, and the kind of card it is. */
export const PURPOSES = {
  RHC_Bare_One: "coverage",
  RHC_Bare_Two: "coverage",
  RHC_Heading_Full: "coverage",
  RHC_Heading_Title: "coverage",
  RHC_Heading_Action: "coverage",
  RHC_Heading_None: "coverage",
  RHC_Heading_Legacy: "coverage",
  RHC_Heading_FullAuto: "coverage",
  RHC_Heading_TitleAuto: "coverage",
  RHC_Heading_FullBothAuto: "coverage",
  RHC_Heading_FullLabelAuto: "coverage",
  RHC_Heading_FullLabelManual: "coverage",
  RHC_Heading_FullIconAuto: "coverage",
  RHC_Heading_FullIconManual: "coverage",
  RHC_Heading_TitleBothAuto: "coverage",
  RHC_Heading_TitleLabelAuto: "coverage",
  RHC_Heading_TitleLabelManual: "coverage",
  RHC_Heading_TitleIconAuto: "coverage",
  RHC_Heading_TitleIconManual: "coverage",
  RHC_Heading_NoneBothAuto: "coverage",
  RHC_Heading_NoneLabelAuto: "coverage",
  RHC_Heading_NoneLabelManual: "coverage",
  RHC_Heading_NoneIconAuto: "coverage",
  RHC_Heading_NoneIconManual: "coverage",
  RHC_Heading_NoneTop: "coverage",
  RHC_Heading_NoneCount: "coverage",
  RHC_Heading_NoneProgressive: "coverage",
  RHC_Heading_NoneEmpty: "coverage",
  RHC_Heading_NoneManual: "coverage",
  RHC_Heading_NoneSkipped: "coverage",

  Account_Advanced_Checks: "coverage",
  Account_Aggregate_Coverage: "coverage",
  Account_AppComp_Coverage: "coverage",
  Account_Category_Grouping: "coverage",
  Account_Compare_Queries: "coverage",
  Account_Compliance_Audit: "business",
  Account_Data_Quality: "business",
  Account_Display_Formats: "coverage",
  Account_Everyday_Use_Cases: "business",
  Account_Formula_Coverage: "coverage",
  Account_Formula_Display_Types: "coverage",
  Account_Query_Coverage: "coverage",
  Account_Relationships: "business",
  Account_Row_Tokens_Negative: "coverage",
  Account_Row_Tokens_Positive: "coverage",
  Account_Token_Surfaces: "coverage",
  Example_Account_Apex: "example",
  Example_Account_Check_Builder_Guide: "example",
  Example_Account_Compare_Two_Queries: "example",
  Example_Account_Formula: "example",
  Example_Account_Over_25_Checks: "example",
  Example_Account_Query: "example",
  Example_Account_Relationship_Risk: "example",
  Example_Contact_Relationship_Readiness: "example",
  Example_Long_Found_Expected: "example",
  Example_Opportunity_Deal_Readiness: "example",
  Foreign_Namespace_Proof: "coverage",
  RHC_Diagnostic_Bad_Apex: "diagnostics",
  RHC_Diagnostic_Bad_Formula: "diagnostics",
  RHC_Diagnostic_Bad_Query: "diagnostics",
  RHC_Inactive_Set: "diagnostics",
  RHC_Link_Conditions: "coverage",
  RHC_Link_Grammar: "coverage",
  RHC_Evidence_Projection: "coverage",
  RHC_Evidence_Bytes_Complete: "coverage",
  RHC_Evidence_Bytes_Truncated: "coverage",
  RHC_Evidence_Bytes_Unknown: "coverage",

  RHC_Negative_Runtime: "diagnostics",
  RHC_No_Active_Checks: "diagnostics",
  RHC_Persona_Access: "coverage",
  RHC_Plugin_Compatibility: "coverage",
  RHC_SP_Definition: "coverage",
  RHC_SP_Diagnostics: "diagnostics",
  RHC_SP_Definition_Invalid: "diagnostics",
  RHC_SP_Diagnostics_Invalid: "diagnostics",
  RHC_SP_Formula: "coverage",
  RHC_SP_Formula_Access: "coverage",
  RHC_SP_Preview: "coverage",
  RHC_SP_Preview_Invalid: "diagnostics",
  RHC_SP_Preview_Live: "coverage",
  RHC_SP_Values: "coverage",
  RHC_Display_Budget: "coverage",
  RHC_Stop_On_System_Error: "diagnostics",
  Release_On_Load: "business",
  Review_Label_Icon_Pass: "review",
  Review_Label_Only_Pass: "review",
  Review_Summary_Above_Checks: "review"
};

/** Fields a reader sees on any Check, whatever kind of card it sits on. */
export const TIER_A = [
  "CheckTitle__c",
  "CheckDescription__c",
  "FailureSeverity__c",
  "FailureMessage__c",
  "UnableToEvaluateMessage__c"
];

/** What a failing Check should also offer on a card an administrator copies. */
export const TIER_B = [
  "FixMessage__c",
  "ActionLabel__c",
  "ActionUrl__c",
  "Category__c"
];

/** Text shown to an administrator or record-page user. */
export const READER_FACING_TEXT_FIELDS = new Set([
  ...TIER_A,
  ...TIER_B,
  "DisplayFoundText__c",
  "DisplayExpectedText__c"
]);

/** Check Sets that represent a real administrator scenario, so Tier B applies. */
export const TIER_B_SETS = [
  "Account_Compliance_Audit",
  "Account_Data_Quality",
  "Account_Everyday_Use_Cases",
  "Account_Relationships",
  "Example_Account_Apex",
  "Example_Account_Compare_Two_Queries",
  "Example_Account_Formula",
  "Example_Account_Query",
  "Example_Account_Relationship_Risk",
  "Example_Contact_Relationship_Readiness",
  "Example_Opportunity_Deal_Readiness"
];

export const MAX_TITLE = 60;
/** Custom Metadata caps a record label at 40 characters. */
export const MAX_LABEL = 40;
export const MIN_SUBTITLE = 60;

/**
 * @param sets    [{api, label, title, subtitle}]
 * @param checks  [{api, set, fields:Set<string>}]
 * @returns human-readable findings, empty when every card reads cleanly
 */
export function comprehensionFindings(sets, checks) {
  const findings = [];
  const byTitle = new Map();

  for (const { api, label, title, subtitle } of sets) {
    const purpose = PURPOSES[api];
    if (!purpose) {
      findings.push(
        `${api} is not declared in the Check Set purpose table. Decide whether ` +
          `it is an example, coverage, diagnostics, review, or business card ` +
          `and title it accordingly.`
      );
      continue;
    }
    if (!title) {
      findings.push(`${api} has no Card Title`);
    } else {
      if (title.length > MAX_TITLE) {
        findings.push(
          `${api} Card Title is ${title.length} characters; keep it to ${MAX_TITLE} so it reads at a glance`
        );
      }
      const prefix = PURPOSE_PREFIX[purpose];
      if (prefix && !title.startsWith(prefix)) {
        findings.push(
          `${api} is a ${purpose} card, so its Card Title must start "${prefix.trim()}" (found "${title}")`
        );
      }
      if (!prefix) {
        const wrong = Object.values(PURPOSE_PREFIX).find(
          (other) => other && title.startsWith(other)
        );
        if (wrong) {
          findings.push(
            `${api} is a business card, so its Card Title must name the subject rather than start "${wrong.trim()}"`
          );
        }
      }
      // The record label is the card's identity in Setup, so it has to be the
      // same name. Custom Metadata caps it at 40 characters, so a longer title
      // may be cut short — but only cut short, never reworded.
      if (
        label !== title &&
        !(title.length > MAX_LABEL && title.startsWith(label))
      ) {
        findings.push(
          `${api} record label "${label}" is not the Card Title "${title}"; ` +
            (title.length > MAX_LABEL
              ? `the title is over ${MAX_LABEL} characters, so the label must be the start of it`
              : `the title fits in ${MAX_LABEL} characters, so the label must be exactly it`)
        );
      }
      const seen = byTitle.get(title);
      if (seen) {
        findings.push(
          `${api} and ${seen} share the Card Title "${title}"; a reader cannot tell them apart`
        );
      } else {
        byTitle.set(title, api);
      }
    }
    if (!subtitle || subtitle.length < MIN_SUBTITLE) {
      findings.push(
        `${api} Card Subtitle is ${subtitle ? `${subtitle.length} characters` : "missing"}; ` +
          `write a sentence saying what the reader will see, not a second label`
      );
    }
  }

  const tierB = new Set(TIER_B_SETS);
  for (const { api, set, fields, values = new Map() } of checks) {
    const required = [...TIER_A, ...(tierB.has(set) ? TIER_B : [])];
    const missing = required.filter((field) => !fields.has(field));
    if (missing.length > 0) {
      findings.push(`${api} (in ${set}) is missing ${missing.join(", ")}`);
    }
    for (const [field, value] of values) {
      if (
        READER_FACING_TEXT_FIELDS.has(field) &&
        /\b[A-Za-z]+\((?:s|es|ies)\)/i.test(value)
      ) {
        findings.push(
          `${api} ${field} uses parenthetical plural shorthand in "${value}"; write the message as a natural sentence or use a result plural-suffix token`
        );
      }
    }
  }
  return findings.sort();
}
