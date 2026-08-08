/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Return the administrator guidance for a setup reason code. */
export function setupErrorHint(reasonCode) {
  switch (reasonCode) {
    case "CONFIG_NOT_FOUND":
    case "SETUP_REQUIRED":
      return "Ask your Salesforce admin to choose a Check Set for this page.";
    case "INACTIVE_CHECK_SETS_ONLY":
      return "Ask your Salesforce admin to activate a Check Set for this object.";
    case "NO_ACTIVE_CHECK_SETS":
      return "Ask your Salesforce admin to set up a Check Set for this object.";
    case "CONFIG_INACTIVE":
      return "Ask your Salesforce admin to activate this Check Set.";
    case "OBJECT_MISMATCH":
      return "Ask your Salesforce admin to choose a Check Set for this object.";
    case "NO_ACTIVE_CHECKS":
      return "Ask your Salesforce admin to add an active Check.";
    case "NO_RECORD_CONTEXT":
      return "Ask your Salesforce admin to place this on a record page.";
    case "INVALID_CONFIG":
      return "Ask your Salesforce admin to review this Check Set in Setup.";
    default:
      return "";
  }
}

/** Build the optional inactive-Check summary shown to diagnostics users. */
export function buildInactiveCheckStat(showDiagnostics, count, labels) {
  if (!showDiagnostics || count < 1) return null;
  const names = labels || [];
  const undisclosed = count - names.length;
  const listed = undisclosed > 0 ? [...names, `+${undisclosed} more`] : names;
  const hasTooltip = names.length > 0;
  const baseClass = "rhc-stat rhc-stat--inactive";
  return {
    key: "inactive",
    label: `${count} Inactive`,
    cssClass: hasTooltip
      ? `${baseClass} rhc-tooltip-anchor rhc-tooltip-anchor--footer rhc-tooltip-anchor--stat`
      : baseClass,
    tooltip: hasTooltip
      ? `${count} inactive ${count === 1 ? "Check" : "Checks"} omitted: ${listed.join(
          ", "
        )}`
      : null,
    tabIndex: hasTooltip ? "0" : null,
    iconClass: "rhc-status-icon rhc-status-icon--inactive"
  };
}

/** Format the console summary for a completed Framework run. */
export function formatRunSummary(checks) {
  const counts = {
    PASS: 0,
    FAIL: 0,
    SKIPPED: 0,
    ERROR: 0,
    UNABLE_TO_EVALUATE: 0
  };
  let totalMs = 0;
  for (const row of checks) {
    if (Object.prototype.hasOwnProperty.call(counts, row.status)) {
      counts[row.status]++;
    }
    if (row.durationMs != null) {
      totalMs += row.durationMs;
    }
  }
  const parts = [];
  if (counts.PASS) parts.push(`${counts.PASS} Passed`);
  if (counts.FAIL) parts.push(`${counts.FAIL} Failed`);
  if (counts.SKIPPED) parts.push(`${counts.SKIPPED} Skipped`);
  if (counts.UNABLE_TO_EVALUATE) {
    parts.push(`${counts.UNABLE_TO_EVALUATE} Unable`);
  }
  if (counts.ERROR) parts.push(`${counts.ERROR} Error`);
  const outcome =
    parts.length > 0 ? parts.join(", ") : `${checks.length} checks`;
  const timing = totalMs > 0 ? ` · ${totalMs}ms total` : "";
  return `${outcome}${timing}`;
}

/** Parse a diagnostics JSON field without allowing malformed server detail to break logging. */
export function parseDiagnosticJson(value) {
  if (!value) return {};
  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {
      parseError: "The diagnostic payload was not valid JSON.",
      raw: value
    };
  }
}
