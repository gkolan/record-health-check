/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Defense-in-depth guard for the guided-remediation link. Apex already
 * sanitizes `actionUrl`, but the component must not trust that alone before
 * binding it to an `href`. Accept only an in-app absolute path (a single
 * leading "/", never protocol-relative "//host") or an explicit `https:` URL;
 * anything else — `javascript:`, `data:`, plain `http:`, mailto, relative — is
 * dropped so the link disappears and the fix instructions stand on their own.
 */
export function safeActionUrl(url) {
  if (typeof url !== "string") {
    return null;
  }
  const trimmed = url.trim();
  if (
    trimmed === "" ||
    trimmed.length > 2000 ||
    trimmed.startsWith("//") ||
    trimmed.includes("\\") ||
    /[\r\n\t]/.test(trimmed)
  ) {
    return null;
  }
  if (trimmed.startsWith("/")) {
    return trimmed;
  }
  if (/^https:/i.test(trimmed)) {
    return trimmed;
  }
  return null;
}

const DISPLAY_FIELDS = ["message", "fix", "found", "expected"];
const DISPLAY_ENVELOPE_KEYS = new Set(["version", ...DISPLAY_FIELDS]);
const MAX_DISPLAY_NODES = 1000;
const MAX_DISPLAY_TEXT = 20000;
const MAX_INLINE_LABEL = 2000;
const MAX_INLINE_URL = 2000;
const MAX_DISPLAY_FIELD_BYTES = 64 * 1024;
const MAX_DISPLAY_RESPONSE_BYTES = 256 * 1024;

/* The payload DTO also calls its visible-string property `text`. It is a plain
 * JSON object, never an HTMLScriptElement; suppress the Locker rule's name-only
 * false positive for this bounded validator. */
/* eslint-disable @locker/locker/distorted-html-script-element-text-getter */

function utf8Length(value) {
  let bytes = 0;
  for (const character of value) {
    const codePoint = character.codePointAt(0);
    if (codePoint <= 0x7f) {
      bytes += 1;
    } else if (codePoint <= 0x7ff) {
      bytes += 2;
    } else if (codePoint <= 0xffff) {
      bytes += 3;
    } else {
      bytes += 4;
    }
  }
  return bytes;
}

function hasOnlyKeys(value, allowed) {
  return Object.keys(value).every((key) => allowed.has(key));
}

function hasTraversalSegment(url) {
  const pathStart = url.startsWith("/")
    ? 0
    : url.indexOf("/", "https://".length);
  const path = (pathStart < 0 ? "" : url.slice(pathStart)).split(/[?#]/, 1)[0];
  return path.split("/").some((segment) => {
    const dots = segment.replace(/%2e/gi, ".");
    return dots === "." || dots === "..";
  });
}

/** Strict, no-network inline-link destination validator shared with Apex vectors. */
export function safeInlineUrl(url) {
  if (typeof url !== "string") {
    return null;
  }
  const trimmed = url.replace(/^[\t\n\f\r ]+|[\t\n\f\r ]+$/g, "");
  if (
    trimmed === "" ||
    trimmed.length > MAX_INLINE_URL ||
    /[^\x20-\x7e]/.test(trimmed) ||
    /[\s\\]/.test(trimmed) ||
    /%(?![0-9a-f]{2})/i.test(trimmed) ||
    /%(?:0[0-9a-f]|1[0-9a-f]|7f|25|5c)/i.test(trimmed) ||
    hasTraversalSegment(trimmed)
  ) {
    return null;
  }
  if (trimmed.startsWith("/")) {
    return trimmed.startsWith("//") ? null : trimmed;
  }
  if (!/^https:\/\//.test(trimmed)) {
    return null;
  }
  let parsed;
  try {
    parsed = new URL(trimmed);
  } catch {
    return null;
  }
  if (
    parsed.protocol !== "https:" ||
    parsed.username ||
    parsed.password ||
    (parsed.port && parsed.port !== "443") ||
    parsed.hostname === "localhost" ||
    !/^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)(?:\.(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?))*$/i.test(
      parsed.hostname
    )
  ) {
    return null;
  }
  return trimmed;
}

function plainDisplayNodes(value) {
  if (value == null) {
    return [];
  }
  const original = String(value);
  if (original === "") {
    return [{ kind: "text", text: "" }];
  }
  const lines = original
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .split("\n");
  while (lines.length && lines[0].trim() === "") {
    lines.shift();
  }
  while (lines.length && lines[lines.length - 1].trim() === "") {
    lines.pop();
  }
  const nodes = [];
  lines.forEach((line, index) => {
    if (index > 0) {
      nodes.push({ kind: "break" });
    }
    if (line !== "") {
      nodes.push({ kind: "text", text: line });
    }
  });
  return nodes;
}

function decorateNodes(nodes, field) {
  return nodes.map((displayNode, index) => ({
    ...displayNode,
    key: `${field}-${index}`,
    isText: displayNode.kind === "text",
    isLink: displayNode.kind === "link",
    isBreak: displayNode.kind === "break",
    linkAriaLabel:
      displayNode.kind === "link"
        ? `${displayNode.text} (opens in a new tab)`
        : null
  }));
}

function nodesToPlainText(nodes) {
  return nodes
    .map((displayNode) => {
      return displayNode.kind === "break" ? "\n" : displayNode.text;
    })
    .join("");
}

function validateDisplayField(nodes) {
  if (
    !Array.isArray(nodes) ||
    nodes.length > MAX_DISPLAY_NODES ||
    utf8Length(JSON.stringify(nodes)) > MAX_DISPLAY_FIELD_BYTES
  ) {
    return null;
  }
  const accepted = [];
  let visibleLength = 0;
  for (const displayNode of nodes) {
    if (
      !displayNode ||
      typeof displayNode !== "object" ||
      Array.isArray(displayNode)
    ) {
      return null;
    }
    if (displayNode.kind === "break") {
      if (!hasOnlyKeys(displayNode, new Set(["kind"]))) {
        return null;
      }
      accepted.push({ kind: "break" });
      visibleLength += 1;
    } else if (displayNode.kind === "text") {
      if (
        !hasOnlyKeys(displayNode, new Set(["kind", "text"])) ||
        typeof displayNode.text !== "string"
      ) {
        return null;
      }
      const expanded = plainDisplayNodes(displayNode.text);
      accepted.push(...expanded);
      visibleLength += displayNode.text.length;
    } else if (displayNode.kind === "link") {
      if (
        !hasOnlyKeys(displayNode, new Set(["kind", "text", "href"])) ||
        typeof displayNode.text !== "string" ||
        displayNode.text.length > MAX_INLINE_LABEL
      ) {
        return null;
      }
      const href = safeInlineUrl(displayNode.href);
      if (!href) {
        return null;
      }
      accepted.push({ kind: "link", text: displayNode.text, href });
      visibleLength += displayNode.text.length;
    } else {
      return null;
    }
    if (
      accepted.length > MAX_DISPLAY_NODES ||
      visibleLength > MAX_DISPLAY_TEXT
    ) {
      return null;
    }
  }
  const visible = accepted.some(
    (displayNode) =>
      displayNode.kind !== "break" && displayNode.text.trim() !== ""
  );
  return visible ? accepted : [];
}

/** Validate the complete versioned envelope before returning any bindable href. */
export function normalizeDisplayContent(content, fallback = {}) {
  const fallbackResult = Object.fromEntries(
    DISPLAY_FIELDS.map((field) => [
      field,
      decorateNodes(plainDisplayNodes(fallback[field]), field)
    ])
  );
  if (content == null) {
    return fallbackResult;
  }
  if (
    typeof content !== "object" ||
    Array.isArray(content) ||
    content.version !== 1 ||
    !hasOnlyKeys(content, DISPLAY_ENVELOPE_KEYS)
  ) {
    return fallbackResult;
  }
  try {
    if (utf8Length(JSON.stringify(content)) > MAX_DISPLAY_RESPONSE_BYTES) {
      return fallbackResult;
    }
  } catch {
    return fallbackResult;
  }
  const validated = {};
  for (const field of DISPLAY_FIELDS) {
    if (content[field] == null) {
      validated[field] = fallbackResult[field];
      continue;
    }
    const nodes = validateDisplayField(content[field]);
    validated[field] =
      nodes == null ? fallbackResult[field] : decorateNodes(nodes, field);
  }
  return validated;
}
/* eslint-enable @locker/locker/distorted-html-script-element-text-getter */

/** View-formatting helpers: map check results into template-ready flags and classes. */
const OUTCOME_STYLES = {
  pass: { label: "Pass", modifier: "pass", message: false },
  error: { label: "Failed", modifier: "error", message: true },
  warning: { label: "Warning", modifier: "warning", message: true },
  info: { label: "Info", modifier: "info", message: true },
  skipped: { label: "Skipped", modifier: "skipped", message: true },
  unable: { label: "Unable to Check", modifier: "unable", message: true },
  systemError: {
    label: "System Error",
    modifier: "system-error",
    message: true
  }
};

// Summary pills reuse the same status-icon CSS modifiers as rows.
const SUMMARY_ROWS = [
  { key: "pass", suffix: "pass", label: (n) => `${n} Passed` },
  { key: "error", suffix: "error", label: (n) => `${n} Failed` },
  {
    key: "warn",
    suffix: "warning",
    label: (n) => `${n} ${n === 1 ? "Warning" : "Warnings"}`
  },
  { key: "info", suffix: "info", label: (n) => `${n} Info` },
  { key: "skip", suffix: "skipped", label: (n) => `${n} Skipped` },
  { key: "unable", suffix: "unable", label: (n) => `${n} Unable` },
  {
    key: "systemError",
    suffix: "system-error",
    label: (n) => `${n} ${n === 1 ? "System Error" : "System Errors"}`
  }
];

/** Split admin-authored messages on newlines for stacked display in the template. */
export function splitMessageLines(message) {
  if (message == null) {
    return [];
  }
  const lines = String(message)
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .split("\n");
  while (lines.length && lines[0].trim() === "") {
    lines.shift();
  }
  while (lines.length && lines[lines.length - 1].trim() === "") {
    lines.pop();
  }
  return lines.map((text, idx) => {
    const isBlank = text.trim() === "";
    return {
      key: idx,
      text,
      isBlank,
      lineClass: isBlank
        ? "rhc-row__message-line rhc-row__message-line--blank"
        : "rhc-row__message-line"
    };
  });
}

/** Join message lines for screen-reader aria-labels. */
function joinForSpeech(lines) {
  const parts = lines.map((line) => line.trim()).filter(Boolean);
  return parts.reduce((acc, part, idx) => {
    if (idx === 0) {
      return part;
    }
    const sep = /[.!?:;]$/.test(acc) ? " " : ". ";
    return acc + sep + part;
  }, "");
}

// Keep a collapsed row's accessible name useful even when metadata contains a
// full playbook. The complete text remains in the DOM beside its labelled
// expansion control and is available after the user opens the region.
function previewForSpeech(value, limit = 500) {
  const text = value == null ? "" : String(value);
  return text.length > limit
    ? `${text.slice(0, limit).trimEnd()}… Additional text available.`
    : text;
}

/**
 * Classifies a resolved check into one of the OUTCOME_STYLES keys. Returns null
 * for rows that are still pending/loading or have no result yet.
 */
function classifyOutcome(status, severity) {
  switch (status) {
    case "PASS":
      return "pass";
    case "FAIL":
      // Severity arrives in the vocabulary Setup stores, which is the same
      // vocabulary the docs and the Check Result event use. The card's own
      // words for these are a presentation choice and stay here.
      if (severity === "WARNING") {
        return "warning";
      }
      if (severity === "INFO") {
        return "info";
      }
      return "error";
    case "SKIPPED":
      return "skipped";
    case "UNABLE_TO_EVALUATE":
      return "unable";
    case "ERROR":
      return "systemError";
    default:
      return null;
  }
}

const COMPARISON_MODES = new Set(["OnDemand", "FailuresOnly", "AllRows"]);
function normalizeComparisonMode(mode) {
  if (!COMPARISON_MODES.has(mode)) {
    const error = new Error(`Unsupported comparison display mode: ${mode}.`);
    error.reasonCode = "INVALID_CONFIG";
    throw error;
  }
  return mode;
}

/** Add template-ready display flags for one check row. */
const COMPARISON_DISPLAY_MODES = [
  "AUTOMATIC",
  "FOUND_ONLY",
  "EXPECTED_ONLY",
  "HIDDEN"
];

/**
 * Resolves a Check's configured comparison visibility. Blank, missing, and
 * unrecognized values resolve to AUTOMATIC so metadata authored before the
 * setting existed keeps today's card behavior.
 *
 * @param {string} configuredMode Value supplied by the definition response.
 * @returns {string} One supported comparison display mode.
 */
export function normalizeComparisonDisplayMode(configuredMode) {
  if (typeof configuredMode !== "string") {
    return "AUTOMATIC";
  }
  const normalized = configuredMode.trim().toUpperCase();
  return COMPARISON_DISPLAY_MODES.includes(normalized)
    ? normalized
    : "AUTOMATIC";
}

const EVIDENCE_TYPES = new Set([
  "STRING",
  "ID",
  "NUMBER",
  "BOOLEAN",
  "DATE",
  "DATETIME"
]);

function unavailableEvidence() {
  return {
    unavailable: true,
    summary: "Details unavailable.",
    columns: [],
    rows: [],
    completeness: "UNKNOWN",
    returnedItemCount: 0,
    totalItemCount: null,
    omittedItemCount: null,
    groupKeys: []
  };
}

function normalizeEvidence(value) {
  if (!value || typeof value !== "object") {
    return null;
  }
  if (
    value.version !== "1.0" ||
    !Array.isArray(value.columns) ||
    !Array.isArray(value.rows) ||
    value.columns.length > 20 ||
    !["COMPLETE", "TRUNCATED", "UNKNOWN"].includes(value.completeness)
  ) {
    return unavailableEvidence();
  }
  const seen = new Set();
  const columns = [];
  for (const column of value.columns) {
    const type = column?.type || column?.dataType;
    if (
      !column ||
      typeof column.key !== "string" ||
      !/^[A-Za-z][A-Za-z0-9_]{0,39}$/.test(column.key) ||
      seen.has(column.key) ||
      typeof column.label !== "string" ||
      column.label.trim() === "" ||
      column.label.length > 80 ||
      !EVIDENCE_TYPES.has(type)
    ) {
      return unavailableEvidence();
    }
    seen.add(column.key);
    columns.push({ ...column, type });
  }
  const rows = [];
  for (let rowIndex = 0; rowIndex < value.rows.length; rowIndex += 1) {
    const row = value.rows[rowIndex];
    if (!Array.isArray(row) || row.length !== columns.length) {
      return unavailableEvidence();
    }
    const cells = row.map((cell, columnIndex) => ({
      key: `${rowIndex}-${columns[columnIndex].key}`,
      value: cell == null ? "—" : String(cell),
      raw: cell
    }));
    rows.push({ key: `evidence-row-${rowIndex}`, cells, raw: row });
  }
  return {
    ...value,
    unavailable: false,
    columns,
    rows,
    groupKeys: Array.isArray(value.groupKeys) ? value.groupKeys : []
  };
}

function evidenceGroups(evidence, rows) {
  const [stepKey, ruleKey] = evidence.groupKeys;
  const stepIndex = evidence.columns.findIndex(
    (column) => column.key === stepKey
  );
  const ruleIndex = evidence.columns.findIndex(
    (column) => column.key === ruleKey
  );
  if (stepIndex < 0 || ruleIndex < 0) {
    return [{ key: "all", label: null, step: null, rows }];
  }
  const groups = new Map();
  for (const row of rows) {
    const step = row.raw[stepIndex];
    const rule = row.raw[ruleIndex];
    const key = `${step == null ? "null" : step}\u0000${rule == null ? "" : rule}`;
    if (!groups.has(key)) {
      groups.set(key, { key, step, rule, rows: [] });
    }
    groups.get(key).rows.push(row);
  }
  return [...groups.values()]
    .sort((left, right) => {
      if (left.step == null) {
        return right.step == null ? 0 : 1;
      }
      if (right.step == null) {
        return -1;
      }
      const stepDifference = Number(left.step) - Number(right.step);
      return (
        stepDifference || String(left.rule).localeCompare(String(right.rule))
      );
    })
    .map((group) => ({
      ...group,
      label: `Step ${group.step == null ? "—" : group.step} · ${group.rule == null ? "—" : group.rule} (${group.rows.length} returned)`
    }));
}

export function annotateCheck(c, showDiagnostics, comparisonMode, isExpanded) {
  const uiState = c.uiState;
  const result = c.result || {};
  const status = result.status || "";
  const severity = result.severity || "";

  const isPending = uiState === "PENDING";
  const isLoading = uiState === "LOADING";
  const isResolved = uiState === "RESOLVED";

  const outcome = isResolved ? classifyOutcome(status, severity) : null;
  const style = outcome ? OUTCOME_STYLES[outcome] : null;

  const isPass = outcome === "pass";

  const statusLabel = style ? style.label : "";
  let statusIconClass = "rhc-status-icon ";
  let rowClass = "rhc-row";
  let messageClass =
    "rhc-row__message rhc-expandable__content rhc-expandable__content--message";
  let rowAccentClass = "";

  if (style) {
    statusIconClass += `rhc-status-icon--${style.modifier}`;
    rowClass += ` rhc-row--${style.modifier}`;
    rowAccentClass = `rhc-row__accent rhc-row__accent--${style.modifier}`;
    if (style.message) {
      messageClass += ` rhc-row__message--${style.modifier}`;
    }
  } else if (isLoading) {
    rowClass += " rhc-row--loading";
  } else if (isPending) {
    rowClass += " rhc-row--pending";
  }

  if (c.description) {
    rowClass += " rhc-tooltip-anchor rhc-tooltip-anchor--row";
  }

  const tabIndex = c.description ? 0 : -1;

  const mode = normalizeComparisonMode(comparisonMode);
  const rowExpanded = isExpanded === true;
  // Per-Check comparison visibility (ComparisonDisplayMode__c). This filters
  // which evidence is eligible to render and nothing else: the evaluation
  // result, merge data, diagnostics, and events keep both values. Suppressing a
  // side here also removes its inline chip, expanded row, caret, divider, and
  // accessible-label phrase, because all of those derive from these two values.
  const displayMode = normalizeComparisonDisplayMode(c.comparisonDisplayMode);
  const foundAllowed =
    displayMode === "AUTOMATIC" || displayMode === "FOUND_ONLY";
  const expectedAllowed =
    displayMode === "AUTOMATIC" || displayMode === "EXPECTED_ONLY";
  const actualValue =
    isResolved && foundAllowed && result.actualValue != null
      ? result.actualValue
      : null;
  const expectedValue =
    isResolved && expectedAllowed && result.expectedValue != null
      ? result.expectedValue
      : null;
  const fallbackFixInstructions =
    isResolved && result.fixInstructions ? result.fixInstructions : null;
  const displayNodes = normalizeDisplayContent(result.displayContent, {
    message: result.message,
    fix: fallbackFixInstructions,
    found: actualValue,
    expected: expectedValue
  });
  const messageNodes = displayNodes.message;
  const fixNodes = displayNodes.fix;
  const foundNodes = foundAllowed ? displayNodes.found : [];
  const expectedNodes = expectedAllowed ? displayNodes.expected : [];
  const foundText = nodesToPlainText(foundNodes);
  const expectedText = nodesToPlainText(expectedNodes);
  const showMessage = isResolved && !isPass && messageNodes.length > 0;
  const showStructuredMessage = messageNodes.some(
    (displayNode) => displayNode.isLink
  );
  const showStructuredFix = fixNodes.some((displayNode) => displayNode.isLink);
  const messageLines = showMessage
    ? splitMessageLines(nodesToPlainText(messageNodes))
    : [];
  const hasValues = foundNodes.length > 0 || expectedNodes.length > 0;

  // The Expected side normally reads "Expected"; a Formula check echoing its
  // pass/fail condition (rather than a comparison value) overrides this with its
  // own key, e.g. "Passes when". Found always reads "Found".
  const expectedKeyLabel =
    (isResolved && result.expectedValueLabel) || "Expected";

  const showInlineComparison =
    isResolved && hasValues && (!isPass || mode === "AllRows");

  const valuesBehindCaret =
    isResolved &&
    hasValues &&
    !showInlineComparison &&
    !(mode === "FailuresOnly" && isPass);
  const showCaret = valuesBehindCaret;
  const detailExpanded = showCaret && rowExpanded;

  // Inline chips
  const showActual = showInlineComparison && foundNodes.length > 0;
  const showExpected = showInlineComparison && expectedNodes.length > 0;

  // Expanded region: values only when they were not already inline. Value-source
  // stays out of the card view and is logged through run diagnostics instead.
  const showExpandedActual =
    detailExpanded && valuesBehindCaret && foundNodes.length > 0;
  const showExpandedExpected =
    detailExpanded && valuesBehindCaret && expectedNodes.length > 0;
  const inlineComparisonValues = [
    showActual
      ? { key: "found", label: "Found", value: foundText, nodes: foundNodes }
      : null,
    showExpected
      ? {
          key: "expected",
          label: expectedKeyLabel,
          value: expectedText,
          nodes: expectedNodes
        }
      : null
  ].filter(Boolean);
  const expandedComparisonValues = [
    showExpandedActual
      ? {
          key: "found-expanded",
          label: "Found",
          value: foundText,
          nodes: foundNodes
        }
      : null,
    showExpandedExpected
      ? {
          key: "expected-expanded",
          label: expectedKeyLabel,
          value: expectedText,
          nodes: expectedNodes
        }
      : null
  ].filter(Boolean);

  // Guided remediation: a read-only deep link and/or fix instructions the server
  // sets only on FAIL (actionUrl is blank on any other status). Instructions
  // may stand alone when the link was omitted or failed sanitization server-side.
  const actionUrl = isResolved ? safeActionUrl(result.actionUrl) : null;
  const actionLabel = actionUrl ? result.actionLabel || "Fix this" : null;
  const fixInstructions =
    status === "FAIL" ? nodesToPlainText(fixNodes) || null : null;
  const showAction = actionUrl != null;
  const showFixInstructions = fixInstructions != null;
  const showActionBlock = showAction || showFixInstructions;

  // A divider separates the message/action zone from the Found/Expected evidence
  // on a busy inline row — only when there is actually something above it.
  const showComparisonDivider =
    showInlineComparison && hasValues && (showMessage || showActionBlock);

  const caretExpanded = detailExpanded;
  const caretLabel = detailExpanded
    ? "Hide comparison detail"
    : "Show comparison detail";
  const caretClass = detailExpanded ? "rhc-caret rhc-caret--open" : "rhc-caret";

  const accessibleMessage = showMessage
    ? previewForSpeech(
        joinForSpeech(
          messageLines.filter((line) => !line.isBlank).map(({ text }) => text)
        )
      )
    : null;

  // Fold message and visible comparison values into aria-label (li text is overridden).
  const comparisonAudible =
    showInlineComparison || (detailExpanded && valuesBehindCaret);

  const accessibleLabel = [
    c.label,
    isLoading ? "Evaluating" : isPending ? "Pending" : statusLabel,
    c.description,
    accessibleMessage,
    previewForSpeech(fixInstructions),
    actionLabel ? `Link: ${actionLabel}` : null,
    comparisonAudible && foundNodes.length > 0 ? `Found ${foundText}` : null,
    comparisonAudible && expectedNodes.length > 0
      ? `${expectedKeyLabel} ${expectedText}`
      : null
  ]
    .filter(Boolean)
    .join(". ");

  const incident =
    (showDiagnostics && isResolved && c.result?.adminDetail?.incident) || null;
  const diagnosis = incident
    ? {
        ...incident,
        location: [
          incident.phase,
          incident.topFrameClass
            ? `${incident.topFrameClass}${incident.topFrameMethod ? `.${incident.topFrameMethod}` : ""}${incident.topFrameLine != null ? `, line ${incident.topFrameLine}` : ""}`
            : incident.component
        ]
          .filter(Boolean)
          .join(" · "),
        remediationActions: (incident.remediationActions || []).map(
          (item, index) => ({
            ...item,
            key: `${item.kind || "action"}-${index}`
          })
        ),
        verificationSteps: (incident.verificationSteps || []).map(
          (instruction, index) => ({
            key: `verify-${index}`,
            number: index + 1,
            instruction
          })
        )
      }
    : null;
  const showDiagnosis = diagnosis != null;
  const diagnosisClass = `rhc-diagnosis${outcome === "systemError" ? " rhc-diagnosis--system-error" : ""}`;

  const diagnosticsMeta =
    showDiagnostics && isResolved
      ? [
          result.status,
          result.reasonCode,
          result.durationMs != null ? `${result.durationMs}ms` : null,
          result.evaluatorType
        ]
          .filter(Boolean)
          .join(" · ")
      : "";
  const showDiagnosticsMeta = !!diagnosticsMeta;
  const showRowAccent = !!rowAccentClass;
  const evidence = isResolved ? normalizeEvidence(result.evidence) : null;
  const showEvidence = evidence != null;
  const evidenceExpanded = showEvidence && c.evidenceExpanded === true;
  const evidenceRows = evidence?.rows || [];
  const visibleEvidenceRows = c.evidenceShowAll
    ? evidenceRows
    : evidenceRows.slice(0, 10);
  const showAllEvidence =
    evidenceExpanded && !c.evidenceShowAll && evidenceRows.length > 10;
  const evidenceRegionId = showEvidence
    ? `rhc-evidence-${String(evidence.runId || "run").replace(/[^A-Za-z0-9_-]/g, "-")}-${String(c.qualifiedApiName || c.developerName || "check").replace(/[^A-Za-z0-9_-]/g, "-")}`
    : null;
  const evidenceDownloadLabel =
    evidence?.completeness === "COMPLETE"
      ? "Download full details"
      : "Download returned details";

  return {
    ...c,
    isPending,
    isLoading,
    loadingAlternativeText: `Evaluating ${c.label}`,
    isResolved,
    statusLabel,
    statusIconClass,
    rowClass,
    tabIndex,
    showRowAccent,
    rowAccentClass,
    messageClass,
    showMessage,
    showStructuredMessage,
    messageLines,
    messageNodes,
    actualValue,
    expectedValue,
    expectedKeyLabel,
    showInlineComparison,
    showActual,
    showExpected,
    actionUrl,
    actionLabel,
    fixInstructions,
    fixNodes,
    showStructuredFix,
    showAction,
    showFixInstructions,
    showActionBlock,
    showComparisonDivider,
    showCaret,
    caretExpanded,
    caretLabel,
    caretClass,
    detailExpanded,
    showExpandedActual,
    showExpandedExpected,
    inlineComparisonValues,
    expandedComparisonValues,
    diagnosis,
    diagnosisClass,
    showDiagnosis,
    diagnosticsMeta,
    showDiagnosticsMeta,
    showEvidence,
    evidenceUnavailable: evidence?.unavailable === true,
    evidenceSummary: evidence?.summary,
    evidenceExpanded,
    evidenceExpandLabel: evidenceExpanded ? "Hide details" : "Show details",
    evidenceRegionId,
    evidenceColumns: evidence?.columns || [],
    evidenceGroups: evidence
      ? evidenceGroups(evidence, visibleEvidenceRows)
      : [],
    evidenceVisibleRowCount: visibleEvidenceRows.length,
    showAllEvidence,
    evidenceShowAllLabel: `Show all ${evidenceRows.length} returned items`,
    evidenceDownloadLabel,
    evidenceDownloadJson: evidence?.unavailable
      ? null
      : JSON.stringify(result.evidence),
    accessibleLabel
  };
}

/** Build summary-bar pill rows from resolved check results. */
export function buildSummaryStats(checks, tooltipKeys = new Set()) {
  const buckets = {
    pass: [],
    error: [],
    warn: [],
    info: [],
    skip: [],
    unable: [],
    systemError: []
  };
  for (const c of checks) {
    if (!c.result) {
      continue;
    }
    const outcome = classifyOutcome(c.result.status, c.result.severity);
    let key;
    if (outcome === "pass") {
      key = "pass";
    } else if (outcome === "error") {
      key = "error";
    } else if (outcome === "warning") {
      key = "warn";
    } else if (outcome === "info") {
      key = "info";
    } else if (outcome === "skipped") {
      key = "skip";
    } else if (outcome === "systemError") {
      key = "systemError";
    } else {
      key = "unable";
    }
    buckets[key].push(c.label);
  }

  return SUMMARY_ROWS.filter((row) => buckets[row.key].length > 0).map(
    (row) => {
      const names = buckets[row.key];
      const label = row.label(names.length);
      const hasTooltip = tooltipKeys.has(row.key);
      const baseClass = `rhc-stat rhc-stat--${row.suffix}`;
      return {
        key: row.key,
        label,
        cssClass: hasTooltip
          ? `${baseClass} rhc-tooltip-anchor rhc-tooltip-anchor--footer rhc-tooltip-anchor--stat`
          : baseClass,
        tooltip: hasTooltip ? `${label}: ${names.join(", ")}` : null,
        tabIndex: hasTooltip ? "0" : null,
        iconClass: `rhc-status-icon rhc-status-icon--${row.suffix}`
      };
    }
  );
}

/** Visible label for checks that have no Check category when others do. */
export function uncategorizedSummaryLabel(count) {
  return count === 1 ? "Other" : "Others";
}

/** Build alphabetized category summary rows; uncategorized checks become Other/Others last. */
export function buildSummaryGroups(checks, tooltipKeys = new Set()) {
  const resolved = checks.filter((check) => check.result);
  const hasCategories = resolved.some((check) => check.category);
  if (!hasCategories) {
    const stats = buildSummaryStats(resolved, tooltipKeys);
    return stats.length
      ? [
          {
            key: "all",
            label: null,
            assistiveLabel: null,
            cssClass: "rhc-stats-group rhc-stats-group--unlabeled",
            stats
          }
        ]
      : [];
  }

  const byCategory = new Map();
  const uncategorized = [];
  for (const check of resolved) {
    if (!check.category) {
      uncategorized.push(check);
      continue;
    }
    const key = check.category;
    if (!byCategory.has(key)) {
      byCategory.set(key, {
        key,
        label: check.categoryLabel || key,
        checks: []
      });
    }
    byCategory.get(key).checks.push(check);
  }

  const allTooltipKeys = new Set(SUMMARY_ROWS.map((row) => row.key));
  const groups = [...byCategory.values()]
    .sort((left, right) =>
      left.label.localeCompare(right.label, undefined, { sensitivity: "base" })
    )
    .map((group) => ({
      key: `category-${group.key}`,
      label: group.label,
      assistiveLabel: null,
      cssClass: "rhc-stats-group rhc-stats-group--labeled",
      stats: buildSummaryStats(group.checks, allTooltipKeys)
    }));
  if (uncategorized.length) {
    groups.push({
      key: "uncategorized",
      label: uncategorizedSummaryLabel(uncategorized.length),
      assistiveLabel: null,
      cssClass: "rhc-stats-group rhc-stats-group--labeled",
      stats: buildSummaryStats(uncategorized, allTooltipKeys)
    });
  }
  return groups;
}
