/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

export const VALID_RESULT_STATUSES = new Set([
  "PASS",
  "FAIL",
  "SKIPPED",
  "UNABLE_TO_EVALUATE",
  "ERROR"
]);

/** Client-synthesized result when the server never evaluated the check. */
export function synthesizeResult(check, status, reasonCode, message) {
  return {
    checkDeveloperName: check.developerName,
    checkQualifiedApiName: check.qualifiedApiName || check.developerName,
    label: check.label,
    status,
    reasonCode,
    message,
    priority: check.priority,
    evaluatorType: null
  };
}

/** Normalize Apex result; malformed responses become ERROR. */
export function normalizeResult(result, check) {
  if (!result || typeof result !== "object") {
    return synthesizeResult(
      check,
      "ERROR",
      "MALFORMED_RESPONSE",
      "The server returned an invalid result. Contact your administrator."
    );
  }
  const normalized = result.evaluation
    ? {
        checkDeveloperName:
          result.evaluation.checkQualifiedApiName || check.developerName,
        checkQualifiedApiName:
          result.evaluation.checkQualifiedApiName ||
          check.qualifiedApiName ||
          check.developerName,
        recordId: result.evaluation.recordId,
        status: result.evaluation.status,
        severity: result.evaluation.severity,
        reasonCode: result.evaluation.reasonCode,
        actualValue:
          result.display?.foundDisplayValue ??
          result.evaluation.found?.storedValue ??
          null,
        expectedValue:
          result.display?.expectedDisplayValue ??
          result.evaluation.expected?.storedValue ??
          null,
        expectedValueLabel: result.display?.expectedValueLabel,
        actualDisplayFormat: result.display?.foundDisplayFormat,
        expectedDisplayFormat: result.display?.expectedDisplayFormat,
        actualCurrencyIsoCode: result.display?.foundCurrencyIsoCode,
        expectedCurrencyIsoCode: result.display?.expectedCurrencyIsoCode,
        message: result.display?.renderedMessage,
        fixInstructions: result.display?.renderedFix,
        actionLabel: result.display?.actionLabel,
        actionUrl: result.display?.actionUrl,
        adminDetail: result.display?.adminDetail
      }
    : result;
  if (!VALID_RESULT_STATUSES.has(normalized.status)) {
    return synthesizeResult(
      check,
      "ERROR",
      "UNKNOWN_RESULT_STATUS",
      "The server returned an unsupported result status. Contact your administrator."
    );
  }
  return normalized;
}

/** Convert the card's flattened view model back to the Apex completion DTO. */
export function toCompletionResult(result, recordId) {
  return {
    evaluation: {
      recordId: result?.recordId || recordId,
      checkQualifiedApiName:
        result?.checkQualifiedApiName || result?.checkDeveloperName,
      status: result?.status,
      severity: result?.severity,
      reasonCode: result?.reasonCode
    }
  };
}

/** Developer names that participate in a RequiresCheck dependency cycle. */
export function detectDependencyCycles(checks) {
  const depMap = {};
  for (const check of checks) {
    if (check.dependsOnCheckDeveloperName) {
      depMap[check.developerName] = check.dependsOnCheckDeveloperName;
    }
  }
  const cycleMembers = new Set();
  for (const check of checks) {
    if (!depMap[check.developerName]) continue;
    const path = [];
    const pathSet = new Set();
    let current = check.developerName;
    while (depMap[current] && !cycleMembers.has(current)) {
      if (pathSet.has(current)) {
        // Found a cycle — add only the nodes from where the cycle starts
        const cycleStart = path.indexOf(current);
        for (let i = cycleStart; i < path.length; i++) {
          cycleMembers.add(path[i]);
        }
        break;
      }
      path.push(current);
      pathSet.add(current);
      current = depMap[current];
    }
  }
  return cycleMembers;
}

const ACCESS_REQUIRED_MESSAGE =
  "You don't have access to Record Health Check. Ask your Salesforce administrator for access.";

function isPlatformAccessError(err, message = "") {
  const errorCode =
    err?.body?.errorCode || err?.body?.output?.errors?.[0]?.errorCode;
  return (
    err?.status === 401 ||
    err?.status === 403 ||
    errorCode === "INSUFFICIENT_ACCESS" ||
    errorCode === "INSUFFICIENT_ACCESS_OR_READONLY" ||
    /(?:do not have access to the apex class|insufficient privileges|permission to run record health checks)/i.test(
      message
    )
  );
}

function accessRequiredError(diagnosticCode) {
  return {
    reasonCode: "NOT_AUTHORIZED",
    message: ACCESS_REQUIRED_MESSAGE,
    diagnosticCode
  };
}

/** Parse Aura error body; defaults to LOAD_FAILED when reason code is absent. */
export function parseAuraError(err) {
  const diagnosticCode =
    err?.body?.errorCode || err?.errorId || err?.status || newRunId();
  if (err?.reasonCode) {
    if (err.reasonCode === "NOT_AUTHORIZED") {
      return accessRequiredError(diagnosticCode);
    }
    return {
      reasonCode: err.reasonCode,
      message: err.message || "An error occurred loading health checks.",
      diagnosticCode
    };
  }
  try {
    const body = err.body && err.body.message ? err.body.message : "";
    const parsed = JSON.parse(body);
    if (parsed.reasonCode === "NOT_AUTHORIZED") {
      return accessRequiredError(parsed.diagnosticCode || diagnosticCode);
    }
    return {
      reasonCode: parsed.reasonCode || "LOAD_FAILED",
      message: parsed.message || "An error occurred loading health checks.",
      diagnosticCode: parsed.diagnosticCode || diagnosticCode
    };
  } catch {
    const message = err?.body?.message || err?.message || "";
    if (isPlatformAccessError(err, message)) {
      return accessRequiredError(diagnosticCode);
    }
    return {
      reasonCode: "LOAD_FAILED",
      message:
        "An unexpected error occurred loading health checks. Please try again.",
      diagnosticCode
    };
  }
}

/** Correlation id for one run's Apex log lines. */
export function newRunId() {
  try {
    if (
      typeof crypto !== "undefined" &&
      crypto &&
      typeof crypto.randomUUID === "function"
    ) {
      return crypto.randomUUID();
    }
  } catch {
    // fall through to the timestamp-based id
  }
  return `rhc-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}
