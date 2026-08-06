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
  if (message == null) return [];
  const lines = String(message)
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .split("\n");
  while (lines.length && lines[0].trim() === "") lines.shift();
  while (lines.length && lines[lines.length - 1].trim() === "") lines.pop();
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
    if (idx === 0) return part;
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
      if (severity === "Warning") return "warning";
      if (severity === "Info") return "info";
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

  const showMessage = isResolved && !isPass && !!(c.result && c.result.message);

  const messageLines = showMessage ? splitMessageLines(c.result.message) : [];

  const mode = normalizeComparisonMode(comparisonMode);
  const rowExpanded = isExpanded === true;
  const actualValue =
    isResolved && result.actualValue != null ? result.actualValue : null;
  const expectedValue =
    isResolved && result.expectedValue != null ? result.expectedValue : null;
  const hasValues = actualValue != null || expectedValue != null;

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
  const showActual = showInlineComparison && actualValue != null;
  const showExpected = showInlineComparison && expectedValue != null;

  // Expanded region: values only when they were not already inline. Value-source
  // stays out of the card view and is logged through run diagnostics instead.
  const showExpandedActual =
    detailExpanded && valuesBehindCaret && actualValue != null;
  const showExpandedExpected =
    detailExpanded && valuesBehindCaret && expectedValue != null;
  const inlineComparisonValues = [
    showActual ? { key: "found", label: "Found", value: actualValue } : null,
    showExpected
      ? { key: "expected", label: expectedKeyLabel, value: expectedValue }
      : null
  ].filter(Boolean);
  const expandedComparisonValues = [
    showExpandedActual
      ? { key: "found-expanded", label: "Found", value: actualValue }
      : null,
    showExpandedExpected
      ? {
          key: "expected-expanded",
          label: expectedKeyLabel,
          value: expectedValue
        }
      : null
  ].filter(Boolean);

  // Guided remediation: a read-only deep link and/or fix instructions the server
  // sets only on FAIL (actionUrl is blank on any other status). Instructions
  // may stand alone when the link was omitted or failed sanitization server-side.
  const actionUrl = isResolved ? safeActionUrl(result.actionUrl) : null;
  const actionLabel = actionUrl ? result.actionLabel || "Fix this" : null;
  const fixInstructions =
    isResolved && result.fixInstructions ? result.fixInstructions : null;
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
          messageLines.filter((line) => !line.isBlank).map((line) => line.text)
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
    comparisonAudible && actualValue != null ? `Found ${actualValue}` : null,
    comparisonAudible && expectedValue != null
      ? `${expectedKeyLabel} ${expectedValue}`
      : null
  ]
    .filter(Boolean)
    .join(". ");

  const adminDetailMessage =
    (isResolved && c.result && c.result.adminDetailMessage) || null;
  const showAdminDetail = showDiagnostics && !!adminDetailMessage;

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

  return {
    ...c,
    isPending,
    isLoading,
    isResolved,
    statusLabel,
    statusIconClass,
    rowClass,
    tabIndex,
    showRowAccent,
    rowAccentClass,
    messageClass,
    showMessage,
    messageLines,
    actualValue,
    expectedValue,
    expectedKeyLabel,
    showInlineComparison,
    showActual,
    showExpected,
    actionUrl,
    actionLabel,
    fixInstructions,
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
    adminDetailMessage,
    showAdminDetail,
    diagnosticsMeta,
    showDiagnosticsMeta,
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
    if (!c.result) continue;
    const outcome = classifyOutcome(c.result.status, c.result.severity);
    let key;
    if (outcome === "pass") key = "pass";
    else if (outcome === "error") key = "error";
    else if (outcome === "warning") key = "warn";
    else if (outcome === "info") key = "info";
    else if (outcome === "skipped") key = "skip";
    else if (outcome === "systemError") key = "systemError";
    else key = "unable";
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

/** Visible label for checks that have no Rule category when others do. */
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
