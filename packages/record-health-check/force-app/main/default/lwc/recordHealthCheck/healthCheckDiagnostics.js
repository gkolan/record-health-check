/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

const COMPONENT_ERROR_PRESENTATIONS = {
  CONFIG_NOT_FOUND: {
    title: "Health Check Needs Setup",
    message: "The configured health check is no longer available.",
    guidance:
      "Ask your Salesforce admin to select another active Check Set on this record page."
  },
  SETUP_REQUIRED: {
    title: "Health Check Needs Setup",
    message: "This health check hasn't been configured for this page.",
    guidance:
      "Ask your Salesforce admin to edit this record page and select an existing active Check Set."
  },
  INACTIVE_CHECK_SETS_ONLY: {
    title: "Health Check Needs Setup",
    message: "Health checks exist for this record type, but none are active.",
    guidance:
      "Ask your Salesforce admin to activate a Check Set for this object, then select it on this record page."
  },
  NO_ACTIVE_CHECK_SETS: {
    title: "Health Check Needs Setup",
    message: "No health check has been created for this record type.",
    guidance:
      "Ask your Salesforce admin to create and activate a Check Set for this object, then select it on this record page."
  },
  CONFIG_INACTIVE: {
    title: "Health Check Needs Setup",
    message: "This health check is currently inactive.",
    guidance:
      "Ask your Salesforce admin to activate this Check Set or select another active Check Set on the record page."
  },
  OBJECT_MISMATCH: {
    title: "Health Check Needs Setup",
    message: "This health check isn't configured for this type of record.",
    guidance:
      "Ask your Salesforce admin to select a Check Set whose Record Object API Name matches this record page."
  },
  NO_ACTIVE_CHECKS: {
    title: "Health Check Needs Setup",
    message: "This health check doesn't contain any active Checks.",
    guidance:
      "Ask your Salesforce admin to add or activate at least one Check in this Check Set."
  },
  NO_RECORD_CONTEXT: {
    title: "Health Check Needs Setup",
    message: "This component only works on a supported record page.",
    guidance:
      "Ask your Salesforce admin to place this component on a supported Salesforce record page."
  },
  INVALID_CONFIG: {
    title: "Health Check Needs Setup",
    message: "This health check has a configuration problem.",
    guidance: "Ask your Salesforce admin to review this Check Set in Setup."
  },
  NOT_AUTHORIZED: {
    title: "Health Check Unavailable",
    message: "You don't have access to view or run this health check.",
    guidance: "Contact your Salesforce administrator if you need access."
  },
  RECORD_NOT_ACCESSIBLE: {
    title: "Health Check Unavailable",
    message: "This health check can't access the current record.",
    guidance: "Verify your record access or refresh the page."
  },
  RECORD_NO_LONGER_AVAILABLE: {
    title: "Health Check Unavailable",
    message: "The current record is no longer available.",
    guidance: "Refresh the page or return to the record list."
  },
  LOAD_FAILED: {
    title: "Health Check Unavailable",
    message: "We couldn't load this health check.",
    guidance:
      "Try again. If the problem continues, contact your Salesforce administrator.",
    retryable: true
  },
  AVAILABILITY_LOOKUP_FAILED: {
    title: "Health Check Unavailable",
    message: "We couldn't verify this health check's setup.",
    guidance:
      "Try again. If the problem continues, contact your Salesforce administrator.",
    retryable: true
  },
  CLIENT_DEFINITION_INVALID: {
    title: "Health Check Unavailable",
    message: "The health check returned an unexpected response.",
    guidance:
      "Try again. If the problem continues, contact your Salesforce administrator.",
    retryable: true
  }
};

const DEFAULT_COMPONENT_ERROR = {
  title: "Health Check Unavailable",
  message: "We couldn't load this health check.",
  guidance:
    "Try again. If the problem continues, contact your Salesforce administrator.",
  retryable: true
};

/** Build a safe component-level error while retaining restricted admin detail. */
export function componentErrorPresentation(
  reasonCode,
  technicalMessage,
  canViewDiagnostics = false,
  diagnosticCode = null
) {
  const presentation =
    COMPONENT_ERROR_PRESENTATIONS[reasonCode] || DEFAULT_COMPONENT_ERROR;
  return {
    reasonCode: reasonCode || "LOAD_FAILED",
    title: presentation.title,
    message: presentation.message,
    guidance: presentation.guidance,
    retryable: presentation.retryable === true,
    technicalDetail:
      canViewDiagnostics && technicalMessage !== presentation.message
        ? technicalMessage || null
        : null,
    diagnosticCode: canViewDiagnostics ? diagnosticCode : null
  };
}

/** Return the administrator guidance for a setup reason code. */
export function setupErrorHint(reasonCode) {
  return COMPONENT_ERROR_PRESENTATIONS[reasonCode]?.guidance || "";
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
      "Open each Diagnosis below. Follow its specific fix and verification steps; use the Diagnostic ID if escalation is still required."
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

/** Build the copy-safe support report for one authorized incident. */
export function safeIncidentReport(incident) {
  if (!incident) return null;
  return {
    contractVersion: incident.contractVersion,
    diagnosticId: incident.diagnosticId,
    runId: incident.runId,
    occurredAt: incident.occurredAt,
    status: incident.status,
    severity: incident.severity,
    category: incident.category,
    reasonCode: incident.reasonCode,
    summary: incident.summary,
    likelyCause: incident.likelyCause,
    owner: incident.owner,
    retryable: incident.retryable,
    phase: incident.phase,
    component: incident.component,
    evaluatorType: incident.evaluatorType,
    checkSetQualifiedApiName: incident.checkSetQualifiedApiName,
    checkQualifiedApiName: incident.checkQualifiedApiName,
    configurationField: incident.configurationField,
    querySide: incident.querySide,
    exceptionType: incident.exceptionType,
    topFrameClass: incident.topFrameClass,
    topFrameMethod: incident.topFrameMethod,
    topFrameLine: incident.topFrameLine,
    affectedRecordCount: incident.affectedRecordCount,
    scopeImpact: incident.scopeImpact,
    fingerprint: incident.fingerprint,
    containsRestrictedDetail: incident.containsRestrictedDetail === true,
    remediationActions: incident.remediationActions || [],
    verificationSteps: incident.verificationSteps || []
  };
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

/** Build a standalone, copyable support report for one Check. */
export function supportCheckDiagnosticsReport(diagnostics, check) {
  const supportCheck = { ...check };
  delete supportCheck.rawResult;
  return {
    runId: diagnostics.runId,
    userId: diagnostics.userId,
    recordId: diagnostics.recordId,
    checkSetQualifiedApiName: diagnostics.checkSetQualifiedApiName,
    generatedAt: diagnostics.generatedAt,
    check: supportCheck
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
