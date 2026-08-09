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

/**
 * Turn terminal outcomes into a short investigation path for an administrator.
 * The order is deliberate: a system defect needs attention before an
 * indeterminate evaluation, business failure, or intentionally skipped Check.
 */
export function diagnosticNextSteps(checks) {
  const statuses = new Set(checks.map((row) => row.status));
  const steps = [];
  if (statuses.has("ERROR")) {
    steps.push(
      "Open each System Error below. Capture its Reason Code and this Run ID, then match the time in Salesforce Debug Logs."
    );
  }
  if (statuses.has("UNABLE_TO_EVALUATE")) {
    steps.push(
      "For each Unable result, read its Reason Code and server diagnostic, then verify the running user's record and field access."
    );
  }
  if (statuses.has("FAIL")) {
    steps.push(
      "For each Fail result, compare Found, Expected, and the operator. Fail is normally a business outcome, not broken code."
    );
  }
  if (statuses.has("SKIPPED")) {
    steps.push(
      "For each Skipped result, inspect applicability, prerequisite, and no-row behavior. Skipped is not Pass or Fail."
    );
  }
  if (steps.length === 0) {
    steps.push(
      "Every Check passed. If the displayed answer is unexpected, compare the resolved evaluation with the Check configuration below."
    );
  }
  return steps;
}

/** Remove duplicated implementation detail from the report intended for support. */
export function supportDiagnosticsReport(diagnostics) {
  return {
    runId: diagnostics.runId,
    userId: diagnostics.userId,
    recordId: diagnostics.recordId,
    checkSetQualifiedApiName: diagnostics.checkSetQualifiedApiName,
    generatedAt: diagnostics.generatedAt,
    checks: diagnostics.checks.map((check) => {
      const supportCheck = { ...check };
      delete supportCheck.rawResult;
      return supportCheck;
    })
  };
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
