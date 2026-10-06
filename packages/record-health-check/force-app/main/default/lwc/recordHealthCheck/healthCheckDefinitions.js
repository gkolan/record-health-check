/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

import { checkNamespace } from "./healthCheckModel";

export const DEFAULT_RUN_BUTTON_DISPLAY = "LABEL_AND_ICON";
export const DEFAULT_CARD_HEADING_DISPLAY = "TITLE_AND_SUBTITLE";
export const CARD_HEADING_DISPLAYS = [
  "TITLE_AND_SUBTITLE",
  "TITLE_ONLY",
  "HIDE"
];
export const RUN_BUTTON_DISPLAYS = [
  "LABEL_AND_ICON",
  "LABEL_ONLY",
  "ICON_ONLY",
  "HIDE"
];

/** Validate without mutating component state; preserve first-error precedence. */
export function validateDefinitions(response, frameworkMaxChecks) {
  if (!response || typeof response !== "object") {
    throw clientDefinitionError(
      "The server returned an invalid health-check definition response."
    );
  }
  if (!Array.isArray(response.checks)) {
    throw clientDefinitionError(
      "The server returned an invalid health-check definition response."
    );
  }
  // Older servers can still return a truncated definition response. Block
  // it here so an upgrade mismatch cannot silently run only part of a Set.
  if (response.checksOmittedByLimit === true) {
    const configured =
      typeof response.totalAvailableCheckCount === "number"
        ? response.totalAvailableCheckCount
        : "more than the supported number of";
    const error = new Error(
      `FRAMEWORK_MAX_CHECKS_EXCEEDED: configured=${configured}, ceiling=${frameworkMaxChecks}. No Checks were run.`
    );
    error.reasonCode = "FRAMEWORK_MAX_CHECKS_EXCEEDED";
    throw error;
  }

  const seenQualifiedNames = new Set();
  for (const def of response.checks) {
    if (!def || !def.developerName) {
      throw clientDefinitionError(
        "A health-check definition is missing its developer name."
      );
    }
    if (!def.qualifiedApiName) {
      throw clientDefinitionError(
        "A health-check definition is missing its qualified API name."
      );
    }
    if (seenQualifiedNames.has(def.qualifiedApiName)) {
      throw clientDefinitionError(
        `Duplicate health-check qualified API name: ${def.qualifiedApiName}.`
      );
    }
    seenQualifiedNames.add(def.qualifiedApiName);
  }
  const canonicalChecks = canonicalizeCheckIdentities(response.checks);

  const cardHeadingDisplay =
    typeof response.cardHeadingDisplay !== "string" ||
    response.cardHeadingDisplay.trim() === ""
      ? DEFAULT_CARD_HEADING_DISPLAY
      : response.cardHeadingDisplay;
  const runButtonDisplay =
    response.runButtonDisplay || DEFAULT_RUN_BUTTON_DISPLAY;
  requireMode(response.triggerMode, ["Automatic", "Manual"], "When Checks Run");
  requireMode(runButtonDisplay, RUN_BUTTON_DISPLAYS, "Run Button Display");
  if (response.triggerMode === "Manual" && runButtonDisplay === "HIDE") {
    const configurationError = new Error(
      "Run Button Display cannot be Hide when checks run only after a user clicks Run. Use a visible Run Button Display or run checks when the page opens."
    );
    configurationError.reasonCode = "INVALID_CONFIG";
    throw configurationError;
  }
  requireMode(
    cardHeadingDisplay,
    CARD_HEADING_DISPLAYS,
    "Card Heading Display"
  );
  if (response.triggerMode === "Manual" && cardHeadingDisplay === "HIDE") {
    const configurationError = new Error(
      "Card Heading Display cannot be Hide when checks run only after a user clicks Run. Show the heading or run checks when the page opens."
    );
    configurationError.reasonCode = "INVALID_CONFIG";
    throw configurationError;
  }
  requireMode(response.revealMode, ["OneAtATime", "AllAtOnce"], "Reveal Mode");
  requireMode(
    response.successDisplayMode,
    ["Show", "Hide"],
    "Passed Checks Display"
  );
  requireMode(
    response.skippedDisplayMode,
    ["Show", "Hide"],
    "Skipped Checks Display"
  );
  requireMode(
    response.comparisonDisplay,
    ["OnDemand", "FailuresOnly", "AllRows"],
    "Found/Expected Display"
  );
  requireMode(
    response.summaryDisplay || "BOTTOM",
    ["TOP", "BOTTOM", "HIDE"],
    "Summary Display"
  );
  return { checks: canonicalChecks, cardHeadingDisplay, runButtonDisplay };
}

function requireMode(value, allowed, label) {
  if (!allowed.includes(value)) {
    throw Object.assign(
      new Error(`${label} has an invalid configured value.`),
      {
        reasonCode: "INVALID_CONFIG"
      }
    );
  }
}

function clientDefinitionError(message) {
  return Object.assign(new Error(message), {
    reasonCode: "CLIENT_DEFINITION_INVALID"
  });
}

function canonicalizeCheckIdentities(definitions) {
  const byDeveloperName = new Map();
  for (const definition of definitions) {
    const candidates = byDeveloperName.get(definition.developerName) || [];
    candidates.push(definition);
    byDeveloperName.set(definition.developerName, candidates);
  }

  return definitions.map((definition) => {
    const explicitQualifiedDependency =
      definition.dependsOnCheckQualifiedApiName;
    const developerNameDependency = definition.dependsOnCheckDeveloperName;
    if (!explicitQualifiedDependency && !developerNameDependency) {
      return { ...definition, dependsOnCheckQualifiedApiName: null };
    }
    if (explicitQualifiedDependency) {
      return {
        ...definition,
        dependsOnCheckQualifiedApiName: explicitQualifiedDependency
      };
    }

    const candidates = byDeveloperName.get(developerNameDependency) || [];
    if (candidates.length === 0) {
      return {
        ...definition,
        dependsOnCheckQualifiedApiName: developerNameDependency
      };
    }
    if (candidates.length === 1) {
      return {
        ...definition,
        dependsOnCheckQualifiedApiName: candidates[0].qualifiedApiName
      };
    }

    const sourceNamespace = checkNamespace(definition);
    const sameNamespace = candidates.filter(
      (candidate) => checkNamespace(candidate) === sourceNamespace
    );
    if (sameNamespace.length !== 1) {
      throw clientDefinitionError(
        `Prerequisite Check "${developerNameDependency}" is ambiguous across namespaces.`
      );
    }
    return {
      ...definition,
      dependsOnCheckQualifiedApiName: sameNamespace[0].qualifiedApiName
    };
  });
}
