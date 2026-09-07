/**
 * The AI drafting prompts under `docs/build-checks/draft-with-ai` are copied
 * verbatim into an assistant and are the only Record Health Check reference the
 * assistant sees. A field name or picklist value that drifts from
 * `Record_Health_Check__mdt` therefore does not produce a documentation typo:
 * it produces a Check an administrator cannot save, in a page whose whole point
 * is that a low-cost model should get the metadata right the first time.
 *
 * This module holds the pure rules. `scripts/release/check_ai_prompt_accuracy.mjs`
 * reads the field metadata and the pages and reports what these functions find.
 *
 * Three rules cover the ways a prompt goes wrong:
 *
 *   1. Every `Something__c` named as real must exist on one of the two objects.
 *      Names the pages deliberately call out as invented ("Never invent
 *      FailMessage__c") must NOT exist, or the warning is now misleading.
 *   2. Every stored picklist value the pages assign - `Skip -> SKIPPED`,
 *      `set ApplicabilityMode__c to COUNT_MATCHES` - must be a declared value of
 *      a picklist the same bullet names.
 *   3. Every configurable field must be reachable from the folder, so an
 *      assistant is not structurally unable to propose a capability the product
 *      ships. Fields that are deliberately withheld are listed with a reason.
 *
 * A "unit" below is one markdown or prompt bullet: field names and the values
 * assigned to them wrap across lines inside a bullet, and nowhere else.
 */

/**
 * Reports a type prompt that no longer repeats the shared rules word for word.
 *
 * Every prompt page is self-contained on purpose - a low-cost assistant cannot
 * open the links - so the shared rules exist four times over. Requiring the
 * block verbatim is what keeps four copies from becoming four dialects.
 *
 * @param {string} shared The shared block, from `shared-rules.md`.
 * @param {{file: string, text: string}[]} prompts The type prompt pages.
 * @returns {string[]} Human-readable problems.
 */
export function sharedBlockDrift(shared, prompts) {
  const normalize = (text) => text.replace(/\r\n/g, "\n").trim();
  const block = normalize(shared);
  return prompts
    .filter((prompt) => !normalize(prompt.text).includes(block))
    .map(
      (prompt) =>
        `${prompt.file} no longer contains the shared rules from ` +
        `shared-rules.md word for word; regenerate the page from that block`
    );
}

/**
 * Reports stale one-based query-row guidance.
 *
 * `rhcQuery.sourceRows` and `comparisonRows` follow Apex and JavaScript
 * collection conventions: index 0 is the first returned row. An explicit
 * one-based claim in a copy-paste prompt teaches an off-by-one bug even though
 * the namespace and field path otherwise look valid.
 *
 * @param {{file: string, text: string}[]} pages Folder pages.
 * @returns {string[]} Human-readable problems.
 */
export function mergeSyntaxProblems(pages) {
  const problems = [];
  const oneBasedClaim =
    /(?:row (?:numbers|indexes?) start(?:s)? at 1|one-based (?:row )?(?:numbers|indexes?|positions?))/gi;
  for (const page of pages) {
    for (const match of page.text.matchAll(oneBasedClaim)) {
      const line = page.text.slice(0, match.index).split("\n").length;
      problems.push(
        `${page.file}:${line} says "${match[0]}"; rhcQuery row indexes start at 0`
      );
    }
  }
  return problems;
}

/** Uppercase words that appear in the pages but are never a stored value. */
const NON_VALUES = new Set([
  // Result statuses an administrator reads on the card, not picklist values.
  "SKIPPED",
  "ERROR",
  // SOQL, formula, and prose vocabulary.
  "SELECT",
  "FROM",
  "WHERE",
  "AND",
  "OR",
  "NOT",
  "ORDER",
  "BY",
  "COUNT",
  "COUNT_DISTINCT",
  "SUM",
  "AVG",
  "MIN",
  "MAX",
  "TRUE",
  "FALSE",
  "NULL",
  "JSON",
  "SOQL",
  "URL",
  "ISBLANK",
  "ISPICKVAL",
  "BLANKVALUE",
  "TODAY",
  "NOW",
  "YEAR",
  "DATE",
  "N/A",
  "AI",
  "LWC",
  "ID",
  "IDS"
]);

/** A line that names a value or field only to forbid it. */
const NEGATIVE =
  /never invent|\bwrong\b|\(not\s|\bnever\s|alternatives such as|instead of/i;

const FIELD = /\b([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)*__c)\b/g;
const UNDERSCORED_VALUE = /\b([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\b/g;
// A stored value is at least three uppercase characters, and never the first
// letter of a Setup label such as "Pass".
const VALUE = "([A-Z][A-Z0-9_]{2,})(?![A-Za-z0-9_])";
const ARROW_VALUE = new RegExp(`(?:→|->)\\s*\`?${VALUE}`, "g");
const ASSIGNED_VALUE = new RegExp(
  `([A-Za-z][A-Za-z0-9_]*__c)\\s*(?:to|=|is|:)\\s*\`?\\*{0,2}${VALUE}`,
  "g"
);

/**
 * Splits page text into bullets. A bullet is the unit a reader and an assistant
 * both treat as one instruction, so a value written on a wrapped continuation
 * line still belongs to the field named on the bullet's first line.
 *
 * @param {string} text Page or prompt-block text.
 * @returns {{line: number, text: string}[]} Units with their starting line.
 */
export function units(text) {
  const lines = text.split("\n");
  const found = [];
  let current = null;
  for (const [index, line] of lines.entries()) {
    // A "Never invent ..." or "Wrong: ..." sentence is its own instruction even
    // when it follows a list without a bullet of its own.
    const starts =
      /^\s*(?:[-*]|\d+\.|\|)\s/.test(line) ||
      /^\s*(?:never invent|wrong\b|do not )/i.test(line) ||
      line.trim() === "";
    if (starts || current === null) {
      if (current) found.push(current);
      current = { line: index + 1, text: line };
    } else {
      current.text += `\n${line}`;
    }
  }
  if (current) found.push(current);
  return found.filter((unit) => unit.text.trim() !== "");
}

const matches = (text, pattern, group = 1) =>
  [...text.matchAll(new RegExp(pattern.source, pattern.flags))].map(
    (match) => match[group]
  );

/**
 * Reports field API names the pages get wrong: a name presented as real that no
 * object declares, and a name warned about as invented that in fact exists.
 *
 * @param {{file: string, text: string}[]} pages Folder pages.
 * @param {Set<string>} declared Every declared field API name.
 * @param {Set<string>} [external] Field names owned by the reader's own org,
 *   used in examples (`Customer_Tier__c`), which this repository cannot declare.
 * @returns {string[]} Human-readable problems.
 */
export function fieldNameProblems(pages, declared, external = new Set()) {
  const problems = [];
  for (const page of pages) {
    for (const unit of units(page.text)) {
      const negative = NEGATIVE.test(unit.text);
      for (const name of new Set(matches(unit.text, FIELD))) {
        if (external.has(name)) continue;
        const exists = declared.has(name);
        if (!exists && !negative) {
          problems.push(
            `${page.file}:${unit.line} names ${name}, which no Check or Check ` +
              `Set field declares`
          );
        }
      }
    }
  }
  problems.push(...misleadingWarnings(pages, declared));
  return problems;
}

/**
 * Reports a "Never invent ..." sentence that names a field the product really
 * declares. Such a warning teaches an assistant to avoid a supported
 * capability, which is the same defect as an invented name in the other
 * direction. The scan is sentence-scoped: the enumeration ends at its period,
 * and the fields named after it are ordinary instructions.
 *
 * @param {{file: string, text: string}[]} pages Folder pages.
 * @param {Set<string>} declared Every declared field API name.
 * @returns {string[]} Human-readable problems.
 */
function misleadingWarnings(pages, declared) {
  const problems = [];
  for (const page of pages) {
    for (const match of page.text.matchAll(/Never invent([^.]*)\./gi)) {
      const line = page.text.slice(0, match.index).split("\n").length;
      for (const name of new Set(matches(match[1], FIELD))) {
        if (!declared.has(name)) continue;
        problems.push(
          `${page.file}:${line} warns against inventing ${name}, but that ` +
            `field is real`
        );
      }
    }
  }
  return problems;
}

/**
 * Reports stored picklist values the pages get wrong.
 *
 * A value is checked against the picklists its own bullet names. A bullet that
 * names no picklist still has its underscored values checked against every
 * picklist, which is what catches an invented value written in prose.
 *
 * @param {{file: string, text: string}[]} pages Folder pages.
 * @param {Map<string, string[]>} picklists Field API name to declared values.
 * @param {Set<string>} [ignore] Uppercase words that are product vocabulary
 *   rather than stored values, such as documented result reason codes.
 * @returns {string[]} Human-readable problems.
 */
export function picklistValueProblems(pages, picklists, ignore = new Set()) {
  const everyValue = new Set([...picklists.values()].flat());
  const problems = [];
  for (const page of pages) {
    for (const unit of units(page.text)) {
      if (NEGATIVE.test(unit.text)) continue;
      const named = [...new Set(matches(unit.text, FIELD))].filter((name) =>
        picklists.has(name)
      );
      const allowed = new Set(named.flatMap((name) => picklists.get(name)));
      const report = (value, domain) =>
        problems.push(
          `${page.file}:${unit.line} stores ${value}, which is not a value of ` +
            domain
        );

      // Assignments: the bullet says which field takes the value, so the value
      // is wrong whenever that field does not declare it - even when the value
      // is a real status word elsewhere in the product.
      for (const value of new Set([
        ...matches(unit.text, ARROW_VALUE),
        ...matches(unit.text, ASSIGNED_VALUE, 2)
      ])) {
        if (named.length === 0 || allowed.has(value)) continue;
        report(value, named.join(", "));
      }

      // Loose mentions: an underscored uppercase word is a stored value or a
      // typo; it is almost never prose.
      for (const value of new Set(matches(unit.text, UNDERSCORED_VALUE))) {
        if (NON_VALUES.has(value) || ignore.has(value)) continue;
        if (named.length > 0 ? allowed.has(value) : everyValue.has(value)) {
          continue;
        }
        report(value, named.length > 0 ? named.join(", ") : "any picklist");
      }
    }
  }
  return problems;
}

/**
 * Reports configurable fields that the drafting folder never mentions, so an
 * assistant working only from these pages cannot propose them.
 *
 * @param {{file: string, text: string}[]} pages Folder pages.
 * @param {string[]} configurable Field API names an administrator can set.
 * @param {Map<string, string>} withheld Field API name to the reason the pages
 *   deliberately keep it out of an AI draft.
 * @returns {string[]} Human-readable problems.
 */
export function capabilityGaps(pages, configurable, withheld) {
  const text = pages.map((page) => page.text).join("\n");
  const mentioned = new Set(matches(text, FIELD));
  const problems = [];
  for (const field of configurable) {
    if (withheld.has(field)) continue;
    if (!mentioned.has(field)) {
      problems.push(
        `No page offers ${field}, so an assistant cannot propose it; add it ` +
          `to a prompt or list it as deliberately withheld`
      );
    }
  }
  for (const [field, reason] of withheld) {
    if (!configurable.includes(field)) {
      problems.push(
        `${field} is listed as withheld (${reason}) but is not a configurable ` +
          `field; remove the stale entry`
      );
    }
  }
  return problems;
}
