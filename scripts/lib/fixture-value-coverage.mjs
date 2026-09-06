/**
 * Every configuration value an administrator can choose must be exercised by at
 * least one integration-test Custom Metadata fixture, so the sandbox
 * verification path in the regression-first contract covers the whole
 * configuration surface rather than the values that happened to be convenient.
 *
 * Two coverage rules are checked:
 *
 *   1. Every value of every restricted picklist on `Record_Health_Check__mdt`
 *      and `Record_Health_Check_Set__mdt` appears in a fixture.
 *   2. Every checkbox whose non-default `true`/`false` state changes runtime
 *      behavior appears in a fixture in both states.
 *
 * A checkbox is only listed in BOTH_STATES when the unset state is not merely
 * "the feature is off": those are indistinguishable from an omitted field and
 * would force meaningless fixtures. `ShowDiagnostics__c`,
 * `PublishErrorLogEvent__c`, `PublishUserRunEvent__c` and
 * `PublishUserResultEvent__c` are covered in their `true` state only for that
 * reason.
 *
 * Combinations of values are deliberately out of scope. Every individual value
 * is covered here; the legal combinations of `EvaluationType__c`,
 * `QueryResultHandling__c` and `ComparisonOperator__c` are enforced by the
 * metadata validator and asserted in Apex, and enumerating them as fixtures
 * would multiply the harness without adding a distinct thing to look at.
 *
 * ── States no fixture can represent ─────────────────────────────────────────
 *
 * The regression-first contract wants a sandbox verification path for every
 * configuration an administrator can reach. These runtime card states are the
 * absence of configuration, or a placement decision on a Lightning record page,
 * so a fixture would destroy the very condition it is meant to show. Each one
 * is verified by hand instead:
 *
 *   CONFIG_NOT_FOUND
 *     The card names a Check Set that does not exist, so a fixture would make
 *     it exist. Point a card at an unused API name on a scratch-org record page.
 *
 *   OBJECT_MISMATCH
 *     Depends on which object's record page the card sits on, not on the Check
 *     Set. Place any Account Check Set on a Contact record page.
 *
 *   NO_RECORD_CONTEXT
 *     The component is on an app or home page with no record. Add the component
 *     to an App Page.
 *
 *   NO_ACTIVE_CHECK_SETS, INACTIVE_CHECK_SETS_ONLY
 *     Org-wide states that require *no* active Check Set to exist, and this
 *     repository ships several. Deploy `force-app` only, to an org with the
 *     example Check Sets deactivated.
 *
 *   CHECK_NOT_FOUND, CHECK_INACTIVE
 *     Returned by the MCP and Agentforce configuration tools for a Check named
 *     in a request, not by the card. Covered by `npm run contract:org`.
 *
 * NO_ACTIVE_CHECKS is the one that *can* be a fixture — a Check Set whose every
 * Check is inactive — and the gate script requires one.
 */

/** Checkboxes whose true and false states are distinct user-visible behavior. */
export const BOTH_STATES = [
  "Record_Health_Check_Set__mdt.IsActive__c",
  "Record_Health_Check_Set__mdt.StopOnSystemError__c"
];

const tagValues = (xml, tag) =>
  [...xml.matchAll(new RegExp(`<${tag}\\s*>([\\s\\S]*?)</${tag}>`, "g"))].map(
    (match) => match[1].replace(/\s+/g, " ").trim()
  );

/** Decodes XML character references before measuring the stored value. */
export function decodeXmlText(value) {
  return value
    .replace(/&#x([0-9a-f]+);/gi, (_, code) =>
      String.fromCodePoint(Number.parseInt(code, 16))
    )
    .replace(/&#(\d+);/g, (_, code) =>
      String.fromCodePoint(Number.parseInt(code, 10))
    )
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&quot;", '"')
    .replaceAll("&apos;", "'")
    .replaceAll("&amp;", "&");
}

/** Returns the restricted picklist values a field declares, or []. */
export function picklistValues(fieldXml) {
  const definition = fieldXml.match(
    /<valueSetDefinition>([\s\S]*?)<\/valueSetDefinition>/
  );
  return definition ? tagValues(definition[1], "fullName") : [];
}

/**
 * Returns the character limit a field declares, or null when it stores no
 * bounded text. Salesforce rejects the whole deployment when a fixture exceeds
 * it, so reading the limit from the field is the only way a source-only gate
 * can catch that before an org does.
 */
export function fieldLength(fieldXml) {
  const length = fieldXml.match(/<length>(\d+)<\/length>/);
  return length ? Number(length[1]) : null;
}

/** The platform caps a Custom Metadata record label at 40 characters. */
export const MAX_MASTER_LABEL = 40;

/**
 * @param limits  Map of "Object.Field" -> declared character limit
 * @param records [{file, label, values: [[field, value]]}]
 * @returns a finding for every value Salesforce would refuse to store
 */
export function lengthGaps(limits, records) {
  const gaps = [];
  for (const { file, label, values } of records) {
    if (label && label.length > MAX_MASTER_LABEL) {
      gaps.push(
        `${file} record label is ${label.length} characters; the platform ` +
          `caps a Custom Metadata label at ${MAX_MASTER_LABEL}`
      );
    }
    for (const [field, value] of values) {
      const limit = limits.get(field);
      if (limit && value.length > limit) {
        gaps.push(
          `${file} ${field.split(".").pop()} is ${value.length} characters; ` +
            `the field stores ${limit}`
        );
      }
    }
  }
  return gaps.sort();
}

/** Returns the field -> value pairs one Custom Metadata record sets. */
export function fixtureValues(recordXml) {
  const pairs = [];
  for (const block of recordXml.matchAll(/<values>([\s\S]*?)<\/values>/g)) {
    const field = block[1].match(/<field>([^<]+)<\/field>/)?.[1]?.trim();
    const value = block[1].match(/<value[^>]*>([\s\S]*?)<\/value>/)?.[1];
    if (field) {
      pairs.push([
        field,
        decodeXmlText((value ?? "").replace(/\s+/g, " ").trim())
      ]);
    }
  }
  return pairs;
}

/**
 * @param declared  Map of "Object.Field" -> declared picklist values
 * @param used      Map of "Object.Field" -> Set of values seen in fixtures
 * @returns a list of human-readable coverage gaps, empty when fully covered
 */
export function coverageGaps(declared, used) {
  const gaps = [];
  for (const [field, values] of declared) {
    const seen = used.get(field) ?? new Set();
    const missing = values.filter((value) => !seen.has(value));
    if (missing.length > 0) {
      gaps.push(
        `${field} has no integration-test fixture for: ${missing.join(", ")}`
      );
    }
  }
  for (const field of BOTH_STATES) {
    const seen = used.get(field) ?? new Set();
    const missing = ["true", "false"].filter((state) => !seen.has(state));
    if (missing.length > 0) {
      gaps.push(
        `${field} has no integration-test fixture for: ${missing.join(", ")}`
      );
    }
  }
  return gaps.sort();
}

/**
 * Returns the merge-token properties one namespace resolver method offers, read
 * from its `property == '...'` branches. Reading the resolver rather than a
 * hand-kept list means a new token cannot be added without also being covered.
 */
export function tokenProperties(resolverSource, methodName) {
  const start = resolverSource.indexOf(`Object ${methodName}(`);
  if (start < 0) return [];
  const end = resolverSource.indexOf("\n  }", start);
  return [
    ...resolverSource
      .slice(start, end < 0 ? undefined : end)
      .matchAll(/property == '([A-Za-z0-9_]+)'/g)
  ].map((match) => match[1]);
}

/** Returns the display formats an inline `format="…"` modifier accepts. */
export function displayFormats(displayFormatSource) {
  return [
    ...displayFormatSource.matchAll(
      /public static final String FORMAT_[A-Z_]+ = '([A-Z_]+)'/g
    )
  ].map((match) => match[1]);
}

/**
 * @param required  Map of surface name -> list of items that need a fixture
 * @param seen      Map of surface name -> Set of items found in fixtures
 */
export function surfaceGaps(required, seen) {
  const gaps = [];
  for (const [surface, items] of required) {
    const found = seen.get(surface) ?? new Set();
    const missing = items.filter((item) => !found.has(item));
    if (missing.length > 0) {
      gaps.push(
        `${surface} has no integration-test fixture for: ${missing.join(", ")}`
      );
    }
  }
  return gaps.sort();
}
