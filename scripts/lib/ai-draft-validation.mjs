/**
 * Scores a Check proposal an AI assistant produced from the prompts in
 * `docs/build-checks/draft-with-ai`.
 *
 * The prompts are written for low-cost models, and a prompt is only as good as
 * the metadata the weakest model returns from it. This module reads the Check
 * and Check Set tables out of a draft and reports what an administrator would
 * discover only when Setup refused to save the record: an invented field, a
 * Setup label stored where a stored value belongs, a required field the
 * Evaluation Type never received, a field that belongs to a different type, and
 * a merge token on a surface that rejects it.
 *
 * The parser reads the table the prompts require - Setup label, API field name,
 * proposed value, why - so an unparseable draft is itself a prompt failure.
 */

import { createHash } from "node:crypto";

/**
 * The cheapest model an administrator is realistically drafting with.
 *
 * The prompts exist to make that model produce Check configuration that saves,
 * so this is the model the release gate holds them to. Raising it to a more
 * capable model would make the gate easier to pass and prove less; change it
 * only when the cheapest model an administrator can reach actually changes.
 */
export const LOWEST_COST_MODEL = "claude-haiku-4-5-20251001";

/** The four Evaluation Types a release must have recorded evidence for. */
export const EVALUATION_TYPES = {
  formula: "FORMULA",
  query: "QUERY",
  "compare-two-queries": "COMPARE_TWO_QUERIES",
  apex: "APEX"
};

/**
 * The prompt text an assistant actually receives: the first fenced block on a
 * prompt page. Prose around it is for the administrator, so a wording change
 * there does not invalidate recorded evidence, and a change inside it does.
 *
 * @param {string} page A prompt page's Markdown.
 * @returns {string|undefined} The prompt block, or undefined when absent.
 */
export function promptBlock(page) {
  return page.match(/```text\n([\s\S]*?)```/)?.[1];
}

/**
 * Identifies the exact prompt a recording was made from, so a later edit to
 * that prompt makes the recording provably stale instead of quietly outdated.
 *
 * @param {string} prompt The prompt block.
 * @returns {string} A hex SHA-256 digest.
 */
export function promptFingerprint(prompt) {
  return createHash("sha256").update(prompt, "utf8").digest("hex");
}

/**
 * Capabilities every Check has, whatever its Evaluation Type. A draft that
 * never mentions one of these is not wrong so much as narrow: the assistant
 * proposed a bare pass/fail rule and left applicability, prerequisites,
 * presentation, and event publication for the administrator to discover later.
 * A prompt that stops offering one of them shows up here first.
 */
export const CROSS_CUTTING = [
  "EvaluationType__c",
  "CheckTitle__c",
  "CheckDescription__c",
  "Category__c",
  "FailureSeverity__c",
  "EvaluationOrder__c",
  "IsActive__c",
  "FailureMessage__c",
  "UnableToEvaluateMessage__c",
  "FixMessage__c",
  "ActionLabel__c",
  "ActionUrl__c",
  "ApplicabilityMode__c",
  "ApplicabilityNotMetMessage__c",
  "PrerequisiteCheck__c",
  "ComparisonDisplayMode__c",
  "DisplayValueFormat__c",
  "DisplayFoundText__c",
  "DisplayExpectedText__c",
  "PublishUserResultEvent__c",
  "ObjectApiName__c",
  "CardTitle__c",
  "CardSubtitle__c",
  "CardRunMode__c",
  "CardRevealMode__c",
  "SummaryDisplay__c",
  "PassedChecksDisplay__c",
  "SkippedChecksDisplay__c",
  "FoundExpectedDisplay__c",
  "RunButtonDisplay__c",
  "RunButtonLabel__c",
  "RerunButtonLabel__c",
  "RunButtonIcon__c",
  "StopOnSystemError__c",
  "ShowDiagnostics__c",
  "PublishUserRunEvent__c",
  "PublishErrorLogEvent__c"
];

/**
 * A value that names the field but decides nothing about it.
 *
 * The prompts require this placeholder for an API name only the administrator
 * can supply. Anywhere else it is the assistant declining to draft: a label, a
 * message, a severity, or a display choice the requirement already answers.
 */
const PLACEHOLDER = /^[(*_\s]*confirm in salesforce setup/i;

/**
 * Cross-cutting fields a draft has to fill in with a usable value rather than
 * merely mention.
 *
 * `PrerequisiteCheck__c` is deliberately absent: it names a sibling Check, so a
 * single-Check draft has nothing true to put there. Every other field on this
 * list is answerable from the requirement, and leaving it empty hands the
 * administrator an unfinished record to research instead of one to edit.
 */
export const MUST_FILL = CROSS_CUTTING.filter(
  (field) => field !== "PrerequisiteCheck__c"
);

/**
 * Optional fields each Evaluation Type reads that a draft should still decide,
 * so the saved Check shows an administrator the whole surface of its type.
 */
const TYPE_MUST_FILL = {
  FORMULA: [
    "FormulaResultType__c",
    "DisplayFoundFormula__c",
    "DisplayExpectedFormula__c"
  ],
  QUERY: ["SourceQueryField__c", "EmptyValueHandling__c", "MaxQueryRows__c"],
  COMPARE_TWO_QUERIES: [
    "SourceQueryField__c",
    "ComparisonQueryField__c",
    "EmptyValueHandling__c",
    "MaxQueryRows__c"
  ],
  APEX: ["ApexParametersJson__c"]
};

/**
 * Reports the fields a draft left for the administrator to work out.
 *
 * A field is covered when the draft proposes a value the administrator could
 * save. A field the Evaluation Type never reads is not a gap - filling it in
 * would earn a CONFIGURATION_IGNORED warning in the org - so the exemptions
 * here mirror `RecordHealthCheckIgnoredConfig`: Display Found/Expected Text are
 * ignored on an Apex Check, and the not-applicable message is ignored on a
 * Check that always applies.
 *
 * @param {Map<string, string>} fields Proposed fields, from `draftFields`.
 * @returns {string[]} Field names left unfilled, in declaration order.
 */
export function coverageGaps(fields) {
  const type = fields.get("EvaluationType__c") ?? "";
  const { forbidden } = typeExpectations(fields);
  const exempt = new Set(forbidden);
  if (type === "APEX") {
    // An Apex Check sets its own Found and Expected values, so the two display
    // text fields are ignored: RecordHealthCheckMetadataValidator reports
    // APEX_DISPLAY_TEXT_IGNORED for them. A Formula Check is not in this list;
    // twelve of the shipped Formula examples use display text.
    exempt.add("DisplayFoundText__c").add("DisplayExpectedText__c");
  }
  if ((fields.get("ApplicabilityMode__c") ?? "ALL_RECORDS") === "ALL_RECORDS") {
    exempt.add("ApplicabilityNotMetMessage__c");
  }
  if (fields.get("RunButtonDisplay__c") === "HIDE") {
    exempt
      .add("RunButtonLabel__c")
      .add("RerunButtonLabel__c")
      .add("RunButtonIcon__c");
  }
  const bareCount = (soql) =>
    /SELECT\s+COUNT\(\s*\)/i.test(soql ?? "") &&
    !/COUNT_DISTINCT|COUNT\s*\(\s*[A-Za-z]/i.test(soql ?? "");
  if (bareCount(fields.get("SourceQuery__c"))) {
    exempt.add("SourceQueryField__c");
  }
  if (bareCount(fields.get("ComparisonQuery__c"))) {
    exempt.add("ComparisonQueryField__c");
  }
  const filled = (field) => {
    const value = fields.get(field);
    return value !== undefined && !PLACEHOLDER.test(value);
  };

  // A Formula Check writes each side of the card as either a formula or fixed
  // text, and the shipped examples use both spellings, sometimes in the same
  // Check. Either one answers for that side; demanding both would be stricter
  // than the product's own metadata.
  if (type === "FORMULA") {
    for (const [formula, text] of [
      ["DisplayFoundFormula__c", "DisplayFoundText__c"],
      ["DisplayExpectedFormula__c", "DisplayExpectedText__c"]
    ]) {
      if (filled(formula)) exempt.add(text);
      if (filled(text)) exempt.add(formula);
    }
  }

  return [...MUST_FILL, ...(TYPE_MUST_FILL[type] ?? [])].filter(
    (field) => !exempt.has(field) && !filled(field)
  );
}

/** Surfaces that accept only `record.*` tokens, unquoted. */
const SOQL_FIELDS = [
  "SourceQuery__c",
  "ComparisonQuery__c",
  "ApplicabilityCountQuery__c"
];

/** Surfaces a person reads as a sentence on the card. */
const MESSAGE_FIELDS = [
  "FailureMessage__c",
  "UnableToEvaluateMessage__c",
  "FixMessage__c",
  "ApplicabilityNotMetMessage__c",
  "ActionLabel__c",
  "DisplayFoundText__c",
  "DisplayExpectedText__c"
];

/** Surfaces that hold Salesforce formula syntax and never a merge token. */
const FORMULA_FIELDS = [
  "PassConditionFormula__c",
  "ApplicabilityFormula__c",
  "ExpectedRecordFormula__c",
  "FindInListFormula__c",
  "DisplayFoundFormula__c",
  "DisplayExpectedFormula__c"
];

const LIST_ROW_OPERATORS = [
  "LIST_CONTAINS_ANY",
  "LIST_CONTAINS_NONE",
  "LISTS_OVERLAP",
  "LISTS_CONTAIN_ALL",
  "LISTS_MATCH_EXACTLY"
];

const NO_EXPECTED_VALUE = ["IS_BLANK", "IS_NOT_BLANK"];

/**
 * Values that mean the assistant deliberately left a field unset. "Confirm in
 * Salesforce Setup" is deliberately not one of them: the prompts require that
 * placeholder for a value the administrator has to supply, so the field was
 * proposed and only its value is open.
 */
const UNSET = [
  /^[(*_\s]*(n\/a|none|blank|empty|leave (it )?blank|-|—)[)*_.\s]*$/i,
  /^[(*_\s]*(n\/a|not used|not needed|not required|not applicable|unused|omit)\b/i
];

/**
 * Reads `| Setup label | Field__c | value | why |` rows out of a draft.
 *
 * @param {string} markdown The assistant's answer.
 * @returns {Map<string, string>} Field API name to proposed value, without the
 *   rows the assistant marked unused.
 */
export function draftFields(markdown) {
  const fields = new Map();
  // A table without a proposed-value column carries no values, whatever its
  // rows look like. Reading the "why" cell as a value there would invent a
  // finding for every row, so the separator row decides which tables count.
  let columns = 0;
  for (const line of markdown.split("\n")) {
    if (!line.includes("|")) continue;
    if (/^\s*\|?[\s:|-]*-[\s:|-]*\|/.test(line)) {
      columns = line.split("|").filter((cell) => cell.trim() !== "").length;
      continue;
    }
    if (columns > 0 && columns < 4) continue;
    const cells = line
      .split("|")
      .map((cell) =>
        cell.trim().replace(/^`|`$/g, "").replaceAll("\\_", "_")
      );
    const index = cells.findIndex(
      (cell) =>
        /^[A-Za-z][A-Za-z0-9_]*(__c)?$/.test(cell) &&
        (cell.endsWith("__c") ||
          cell === "DeveloperName" ||
          cell === "MasterLabel")
    );
    if (index === -1) continue;
    const value = (cells[index + 1] ?? "").replace(/^`|`$/g, "").trim();
    if (value === "" || UNSET.some((pattern) => pattern.test(value))) continue;
    fields.set(cells[index], value);
  }
  return fields;
}

/**
 * Reports factual drift in prose required for installed Apex examples.
 *
 * Table validation proves that metadata saves, but the Apex prompt also asks
 * for a class contract and sandbox tests. For a class shipped by this package,
 * allowing an inexpensive model to invent that contract is unsafe evidence.
 *
 * @param {string} markdown The assistant's complete answer.
 * @param {Map<string, string>} fields Proposed fields, from `draftFields`.
 * @returns {string[]} Human-readable problems.
 */
/**
 * The shape a drafted API name must take when the assistant made it up.
 *
 * An illustrative name that looks like a real one is the failure this guards:
 * an administrator who copies `BillingCity__c` out of an explanation gets a
 * field that does not exist, and `BillingCity` is a standard field that carries
 * no suffix at all. A name nobody could mistake for real cannot be pasted by
 * accident.
 */
const INVENTED_NAME_SHAPE = /^Your_[A-Za-z0-9_]*__c$/;

/**
 * Reports API names a draft introduced that nobody supplied.
 *
 * The requirement is the only source of an administrator's own field names, and
 * the Check metadata is the only source of this product's. A `__c` name from
 * neither was invented by the assistant, whatever it looks like, so it must
 * either not be there or announce itself as a placeholder to replace.
 *
 * @param {string} markdown The assistant's complete answer.
 * @param {string} requirement The administrator's message.
 * @param {Set<string>} declared Declared Check and Check Set field names.
 * @returns {string[]} Human-readable problems.
 */
export function inventedNameProblems(markdown, requirement, declared) {
  const invented = new Set();
  for (const name of markdown.match(/\b[A-Za-z][A-Za-z0-9_]*__c\b/g) ?? []) {
    if (declared.has(name)) continue;
    if (requirement.includes(name)) continue;
    if (INVENTED_NAME_SHAPE.test(name)) continue;
    invented.add(name);
  }
  return [...invented].map(
    (name) =>
      `${name} is an API name nobody supplied; write an invented name as ` +
      `Your_Something__c so it cannot be pasted into Setup as though it were real`
  );
}

export function draftNarrativeProblems(markdown, fields) {
  if (fields.get("ApexClass__c") !== "AccountHasRecentActivityCheck") {
    return [];
  }
  const problems = [];
  if (!/\b(?:3,650|3650)\b/.test(markdown)) {
    problems.push(
      "AccountHasRecentActivityCheck must state the real daysBack maximum of 3,650"
    );
  }
  if (!/\bINVALID_CONFIG\b/.test(markdown)) {
    problems.push(
      "AccountHasRecentActivityCheck must state that invalid parameter values return INVALID_CONFIG"
    );
  }
  if (!/\bWhatId\b/.test(markdown) || !/\bActivityDate\b/.test(markdown)) {
    problems.push(
      "AccountHasRecentActivityCheck must identify WhatId and ActivityDate as its relationship and date fields"
    );
  }
  return problems;
}

/**
 * Fields each Evaluation Type must have, and fields it must not have.
 *
 * `QUERY` list operators are the one conditional shape: they read their value
 * from a formula and their list from the Comparison Query, so the Source Query
 * that every other Query Check needs must be absent.
 *
 * @param {Map<string, string>} fields Proposed Check fields.
 * @returns {{required: string[], forbidden: string[]}} Expectations.
 */
export function typeExpectations(fields) {
  const type = fields.get("EvaluationType__c");
  const operator = fields.get("ComparisonOperator__c") ?? "";
  const handling = fields.get("QueryResultHandling__c") ?? "";
  const formulaOnly = [
    "PassConditionFormula__c",
    "FormulaResultType__c",
    "DisplayFoundFormula__c",
    "DisplayExpectedFormula__c"
  ];
  const queryOnly = [
    "SourceQuery__c",
    "SourceQueryField__c",
    "ComparisonQuery__c",
    "ComparisonQueryField__c",
    "QueryResultHandling__c",
    "ComparisonOperator__c",
    "ExpectedValueSource__c",
    "ExpectedFixedValue__c",
    "ExpectedRecordFormula__c",
    "ExpectedCurrencyIsoCode__c",
    "FindInListFormula__c",
    "NoRowsResult__c",
    "EmptyValueHandling__c",
    "MaxQueryRows__c"
  ];
  const apexOnly = ["ApexClass__c", "ApexParametersJson__c"];
  const needsNoRows = ["ANY_ROW_PASSES", "ALL_ROWS_PASS", "COMPARE_AS_LISTS"];

  if (type === "FORMULA") {
    return {
      required: ["PassConditionFormula__c"],
      forbidden: [...queryOnly, ...apexOnly]
    };
  }
  if (type === "QUERY") {
    const listSearch = ["LIST_CONTAINS_ANY", "LIST_CONTAINS_NONE"].includes(
      operator
    );
    return {
      required: [
        "QueryResultHandling__c",
        "ComparisonOperator__c",
        ...(listSearch
          ? ["FindInListFormula__c", "ComparisonQuery__c"]
          : ["SourceQuery__c"]),
        ...(NO_EXPECTED_VALUE.includes(operator) || listSearch
          ? []
          : ["ExpectedValueSource__c"]),
        ...(needsNoRows.includes(handling) ? ["NoRowsResult__c"] : [])
      ],
      forbidden: [
        ...formulaOnly,
        ...apexOnly,
        ...(listSearch ? ["SourceQuery__c"] : [])
      ]
    };
  }
  if (type === "COMPARE_TWO_QUERIES") {
    return {
      required: [
        "SourceQuery__c",
        "ComparisonQuery__c",
        "QueryResultHandling__c",
        "ComparisonOperator__c",
        ...(handling === "COMPARE_AS_LISTS" ? ["NoRowsResult__c"] : [])
      ],
      forbidden: [
        ...formulaOnly,
        ...apexOnly,
        "ExpectedValueSource__c",
        "ExpectedFixedValue__c",
        "ExpectedRecordFormula__c",
        "ExpectedCurrencyIsoCode__c",
        "FindInListFormula__c"
      ]
    };
  }
  if (type === "APEX") {
    return {
      required: ["ApexClass__c"],
      forbidden: [...formulaOnly, ...queryOnly]
    };
  }
  return { required: [], forbidden: [] };
}

/**
 * Reports everything wrong with one drafted Check.
 *
 * @param {Map<string, string>} fields Proposed Check fields.
 * @param {{declared: Set<string>, picklists: Map<string, string[]>,
 *   lengths: Map<string, number>}} schema Field metadata.
 * @returns {string[]} Human-readable problems, empty when the draft is sound.
 */
export function draftProblems(fields, schema) {
  const problems = [];
  const say = (problem) => problems.push(problem);

  for (const [field, value] of fields) {
    if (field === "DeveloperName" || field === "MasterLabel") continue;
    if (!schema.declared.has(field)) {
      say(`${field} is not a Check or Check Set field`);
      continue;
    }
    const values = schema.picklists.get(field);
    if (values && !values.includes(value)) {
      say(
        `${field} = ${value} is not a stored value; use one of ` +
          values.join(", ")
      );
    }
    const limit = schema.lengths.get(field);
    if (limit !== undefined && value.length > limit) {
      say(`${field} is ${value.length} characters, over its ${limit} limit`);
    }
  }

  for (const field of ["EvaluationType__c", "CheckTitle__c"]) {
    if (!fields.has(field)) say(`${field} is required and was not proposed`);
  }

  const { required, forbidden } = typeExpectations(fields);
  const type = fields.get("EvaluationType__c") ?? "no Evaluation Type";
  for (const field of required) {
    if (!fields.has(field)) say(`${type} needs ${field}, which is missing`);
  }
  for (const field of forbidden) {
    if (fields.has(field)) say(`${type} must not set ${field}`);
  }

  const operator = fields.get("ComparisonOperator__c");
  if (
    operator &&
    LIST_ROW_OPERATORS.includes(operator) &&
    fields.get("QueryResultHandling__c") !== "COMPARE_AS_LISTS"
  ) {
    say(`${operator} requires QueryResultHandling__c = COMPARE_AS_LISTS`);
  }

  const rows = Number(fields.get("MaxQueryRows__c"));
  if (fields.has("MaxQueryRows__c") && !(rows >= 1 && rows <= 2000)) {
    say(`MaxQueryRows__c must be a whole number from 1 through 2000`);
  }

  for (const field of SOQL_FIELDS) {
    const soql = fields.get(field);
    if (soql === undefined) continue;
    for (const [token, namespace] of soql.matchAll(/\{!\s*([A-Za-z$]+)\./g)) {
      if (namespace !== "record") {
        say(`${field} uses ${token.trim()}; SOQL accepts only record.* tokens`);
      }
    }
    if (/['"]\{!/.test(soql)) {
      say(`${field} quotes a merge token; strings are quoted automatically`);
    }
    if (/:recordId|\{!Id\}|\{!recordId\}/.test(soql)) {
      say(`${field} uses Flow or Apex bind syntax instead of {!record.Id}`);
    }
  }

  // A bare COUNT() returns one aggregate row even when the count is zero, so a
  // no-rows decision on it is inert - and the skip the administrator asked for
  // silently never happens. Applicability is where that decision belongs.
  const bareCount = SOQL_FIELDS.filter((field) =>
    /SELECT\s+COUNT\(\s*\)/i.test(fields.get(field) ?? "")
  );
  if (
    fields.has("NoRowsResult__c") &&
    bareCount.includes("SourceQuery__c") &&
    fields.get("QueryResultHandling__c") === "ONE_RESULT"
  ) {
    say(
      "SourceQuery__c is a bare COUNT(), which always returns one row, so " +
        "NoRowsResult__c never applies; use ApplicabilityMode__c to skip a " +
        "record instead"
    );
  }

  for (const field of SOQL_FIELDS) {
    if (/\bAS\s+[A-Za-z_]/.test(fields.get(field) ?? "")) {
      say(`${field} uses AS for an alias; SOQL aliases have no AS keyword`);
    }
  }

  const url = fields.get("ActionUrl__c") ?? "";
  if (/^\/lightning\/r\/\{!/.test(url)) {
    say(
      "ActionUrl__c omits the object API name; the path is " +
        "/lightning/r/<Object>/{!record.Id}/..."
    );
  }

  for (const field of FORMULA_FIELDS) {
    if (fields.get(field)?.includes("{!")) {
      say(`${field} is a Salesforce formula and cannot contain a merge token`);
    }
  }

  if (fields.get("ActionUrl__c")?.includes("{!rhcResult.")) {
    say("ActionUrl__c cannot contain an rhcResult token");
  }

  // "1 Opportunity(s)" is the sentence a model writes when it forgets that the
  // product already solved pluralisation. foundValuePluralSuffix exists so a
  // count reads as "1 Contact" and "2 Contacts" without a conditional, and a
  // draft that hand-rolls the bracket instead ships that bracket to a user.
  for (const field of MESSAGE_FIELDS) {
    const message = fields.get(field);
    if (message === undefined) continue;
    if (
      !/\{!\s*rhcResult\.(foundValue|failedRecordCount|totalRecordCount)/.test(
        message
      )
    ) {
      continue;
    }
    if (/\((?:s|es|ies)\)|\b\w+\(s\)/i.test(message)) {
      say(
        `${field} spells a plural as "(s)"; use ` +
          `{!rhcResult.foundValuePluralSuffix} so the count reads as a sentence`
      );
    }
  }

  // format="..." asks Salesforce to render a field by its data type, which it
  // can only do for a token that names a field. A result token already holds
  // finished display text, so formatting it again is a configuration error the
  // administrator meets at run time rather than on save.
  for (const [field, value] of fields) {
    for (const [, namespace] of value.matchAll(
      /\{!\s*([A-Za-z$]+)\.[^}]*?\bformat\s*=/g
    )) {
      if (namespace !== "record" && namespace !== "rhcQuery") {
        say(
          `${field} formats a ${namespace} token; format="..." works only on ` +
            `record.* and rhcQuery row fields, which still name a Salesforce field`
        );
      }
    }
  }

  if (fields.get("RunButtonDisplay__c") === "HIDE") {
    for (const field of [
      "RunButtonLabel__c",
      "RerunButtonLabel__c",
      "RunButtonIcon__c"
    ]) {
      if (fields.has(field)) {
        say(`${field} is ignored when RunButtonDisplay__c = HIDE`);
      }
    }
  }

  if (
    NO_EXPECTED_VALUE.includes(operator) &&
    fields.get("DisplayExpectedText__c")?.includes("{!rhcResult.expectedValue}")
  ) {
    say(
      `${operator} has no expected operand, so DisplayExpectedText__c cannot ` +
        "use {!rhcResult.expectedValue}"
    );
  }

  return problems;
}
