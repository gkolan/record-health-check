#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const matrix = JSON.parse(
  fs.readFileSync(path.join(root, "config/release-runtime-matrix.json"), "utf8")
);
const errors = [];
const expectedTypes = ["APEX", "COMPARE_TWO_QUERIES", "FORMULA", "QUERY"];
const requiredEntryPoints = [
  "lwc-run-on-load",
  "lwc-manual",
  "apex-api",
  "flow-interview",
  "rest-mcp",
  "agentforce-actions",
  "platform-events",
  "queueable",
  "batch",
  "scheduled"
];
const requiredScenarios = [
  "lwc-run-on-load",
  "lwc-manual-run",
  "lwc-refresh-view",
  "page-load-no-overlay",
  "browser-runtime-errors",
  "app-builder-with-config",
  "app-builder-without-config",
  "record-navigation",
  "component-disconnect-reconnect",
  "fresh-package-install",
  "upgrade-2.0.6.2-to-2.0.7.1",
  "post-install-lwc",
  "post-upgrade-lwc",
  "post-install-apex-api",
  "post-upgrade-apex-api",
  "post-install-flow",
  "post-upgrade-flow",
  "post-install-rest-mcp",
  "post-upgrade-rest-mcp",
  "post-install-agentforce",
  "post-upgrade-agentforce",
  "post-install-platform-events",
  "post-upgrade-platform-events",
  "post-install-queueable",
  "post-upgrade-queueable",
  "post-install-batch",
  "post-upgrade-batch",
  "post-install-scheduled",
  "post-upgrade-scheduled",
  "post-install-metadata-validation",
  "post-upgrade-metadata-validation",
  "restricted-persona",
  "administrator-persona"
];

function sorted(values) {
  return [...values].sort();
}

function requireEqual(actual, expected, label) {
  if (JSON.stringify(sorted(actual)) !== JSON.stringify(sorted(expected))) {
    errors.push(`${label} must be exactly: ${expected.join(", ")}.`);
  }
}

function requireText(file, snippets) {
  const text = fs.readFileSync(path.join(root, file), "utf8");
  for (const snippet of snippets) {
    if (!text.includes(snippet)) {
      errors.push(`${file} is missing release-gate marker: ${snippet}`);
    }
  }
}

function requireOrderedText(file, snippets) {
  const text = fs.readFileSync(path.join(root, file), "utf8");
  let cursor = -1;
  for (const snippet of snippets) {
    const index = text.indexOf(snippet, cursor + 1);
    if (index === -1) {
      errors.push(
        `${file} must retain release-gate order; missing or misplaced marker: ${snippet}`
      );
      return;
    }
    cursor = index;
  }
}

function rejectText(file, expression, message) {
  const text = fs.readFileSync(path.join(root, file), "utf8");
  if (expression.test(text)) {
    errors.push(`${file} ${message}`);
  }
}

function requireFailClosedArtifactUploads(file) {
  const text = fs.readFileSync(path.join(root, file), "utf8");
  const stepBlocks = text.split(/(?=^      - (?:name:|uses:))/m);
  const uploads = stepBlocks.filter((block) =>
    block.includes("uses: actions/upload-artifact@")
  );
  if (uploads.length === 0) {
    errors.push(`${file} must retain required release-evidence uploads.`);
    return;
  }
  for (const upload of uploads) {
    const name = upload.match(/^\s*name:\s*(.+)$/m)?.[1] ?? "unnamed upload";
    if (!/^\s*if-no-files-found:\s*error\s*$/m.test(upload)) {
      errors.push(
        `${file} artifact step ${name} must set if-no-files-found: error.`
      );
    }
  }
}

function requireSecureDevHubAuthentication(file, expectedStepCount) {
  const text = fs.readFileSync(path.join(root, file), "utf8");
  const stepBlocks = text.split(/(?=^      - (?:name:|uses:))/m);
  const authSteps = stepBlocks.filter((block) =>
    block.includes("name: Authenticate Dev Hub")
  );
  if (authSteps.length !== expectedStepCount) {
    errors.push(
      `${file} must contain exactly ${expectedStepCount} Dev Hub authentication steps; found ${authSteps.length}.`
    );
  }
  for (const authStep of authSteps) {
    for (const marker of [
      'auth_file="$RUNNER_TEMP/devhub-auth-url.txt"',
      `trap 'rm -f "$auth_file"' EXIT`,
      `printf '%s' "$SFDX_AUTH_URL" > "$auth_file"`,
      'chmod 600 "$auth_file"',
      'sf org login sfdx-url --sfdx-url-file "$auth_file" --alias devhub --set-default-dev-hub'
    ]) {
      if (!authStep.includes(marker)) {
        errors.push(
          `${file} Dev Hub authentication must retain secure file-based CLI marker: ${marker}`
        );
      }
    }
    if (authStep.includes("--sfdx-url-stdin")) {
      errors.push(
        `${file} Dev Hub authentication must not use --sfdx-url-stdin because the pinned CLI parses the following alias flag as its value.`
      );
    }
  }
}

function requireUniqueXmlValues(file, elementName) {
  const text = fs.readFileSync(path.join(root, file), "utf8");
  const values = [
    ...text.matchAll(
      new RegExp(`<${elementName}>([^<]+)</${elementName}>`, "g")
    )
  ].map((match) => match[1]);
  const duplicates = values.filter(
    (value, index) => values.indexOf(value) !== index
  );
  if (duplicates.length > 0) {
    errors.push(
      `${file} contains duplicate ${elementName} values: ${[
        ...new Set(duplicates)
      ].join(", ")}.`
    );
  }
}

function requireUniqueRegionNames(file) {
  const text = fs.readFileSync(path.join(root, file), "utf8");
  const values = [
    ...text.matchAll(/<flexiPageRegions>([\s\S]*?)<\/flexiPageRegions>/g)
  ]
    .map((match) => [...match[1].matchAll(/<name>([^<]+)<\/name>/g)])
    .map((matches) => matches.at(-1)?.[1])
    .filter(Boolean);
  const duplicates = values.filter(
    (value, index) => values.indexOf(value) !== index
  );
  if (duplicates.length > 0) {
    errors.push(
      `${file} contains duplicate region names: ${[...new Set(duplicates)].join(
        ", "
      )}.`
    );
  }
}

requireEqual(matrix.evaluationTypes, expectedTypes, "Evaluation types");
requireEqual(
  matrix.sourceTopologies,
  ["namespaced", "no-namespace"],
  "Source topologies"
);
requireEqual(
  matrix.lightningSecurityModes,
  ["LWS", "Locker"],
  "Lightning security modes"
);
requireEqual(matrix.browserEngines, ["chromium", "firefox"], "Browser engines");
requireEqual(
  matrix.entryPoints.map(({ id }) => id),
  requiredEntryPoints,
  "Entry points"
);
requireEqual(
  matrix.lifecycleScenarios,
  requiredScenarios,
  "Lifecycle scenarios"
);
requireEqual(
  Object.keys(matrix.lifecycleEvidence ?? {}),
  requiredScenarios,
  "Lifecycle evidence scenarios"
);
if (matrix.candidateVersion !== "2.0.7.1") {
  errors.push("Candidate version must be exactly 2.0.7.1.");
}
if (matrix.upgradeFromVersion !== "2.0.6.2") {
  errors.push("Upgrade base version must be exactly 2.0.6.2.");
}
for (const scenario of requiredScenarios) {
  const evidence = matrix.lifecycleEvidence?.[scenario];
  if (!Array.isArray(evidence) || evidence.length === 0) {
    errors.push(`${scenario} must name executable lifecycle evidence.`);
    continue;
  }
  for (const relativePath of evidence) {
    if (!fs.existsSync(path.join(root, relativePath))) {
      errors.push(
        `${scenario} is blocked: lifecycle evidence does not exist: ${relativePath}`
      );
    }
  }
}

for (const entryPoint of matrix.entryPoints) {
  requireEqual(
    entryPoint.evaluationTypes,
    expectedTypes,
    `${entryPoint.id} evaluation types`
  );
  if (!Array.isArray(entryPoint.evidence) || entryPoint.evidence.length === 0) {
    errors.push(`${entryPoint.id} must name at least one evidence artifact.`);
    continue;
  }
  for (const relativePath of entryPoint.evidence) {
    if (!fs.existsSync(path.join(root, relativePath))) {
      errors.push(
        `${entryPoint.id} is blocked: required evidence does not exist: ${relativePath}`
      );
    }
  }
}

requireText(".github/workflows/salesforce-validate.yml", [
  "npm run test:apex:exact -- --target-org rhc-ci --topology namespaced-package --scope package",
  "npm run test:apex:exact -- --target-org rhc-ci --topology namespaced-full --scope full",
  "npm run test:apex:exact -- --target-org rhc-ci-portable --topology no-namespace-package --scope package",
  "npm run test:apex:exact -- --target-org rhc-ci-portable --topology no-namespace-full --scope full",
  "apex-inventory-namespaced-package",
  "apex-inventory-namespaced-full",
  "apex-inventory-no-namespace-package",
  "apex-inventory-no-namespace-full",
  "--namespace rhc",
  '--namespace ""',
  "--security-mode LWS",
  "--security-mode Locker",
  "topology: namespaced",
  "topology: no-namespace",
  "browser-fixtures/namespaced/main/default/flexipages",
  "browser-fixtures/no-namespace/main/default/flexipages",
  "matrix.browser_fixture",
  "npx playwright install --with-deps chromium firefox",
  "--workspace subscriber-app",
  "--rule-selector AppExchange",
  "--rule-selector Recommended:Security",
  "--rule-selector flow:all",
  "check_code_analyzer_integrity.mjs",
  "appexchange-security.json",
  "javascript-security.json"
]);
requireText(".github/workflows/subscriber-validate.yml", [
  "package_version_id",
  "required: true",
  "upgrade_from",
  "--upgrade-from",
  "--upgrade-only",
  "security_mode: LWS",
  "security_mode: Locker",
  'security-mode "${{ matrix.security_mode }}"',
  "subscriber-clean-install-${{ matrix.artifact_suffix }}",
  "subscriber-upgrade-evidence-${{ matrix.artifact_suffix }}"
]);
for (const workflow of [
  ".github/workflows/salesforce-validate.yml",
  ".github/workflows/subscriber-validate.yml"
]) {
  requireFailClosedArtifactUploads(workflow);
}
requireSecureDevHubAuthentication(
  ".github/workflows/salesforce-validate.yml",
  3
);
requireSecureDevHubAuthentication(
  ".github/workflows/subscriber-validate.yml",
  2
);
requireText("scripts/release/create-package-version.mjs", [
  '"salesforce-validate.yml"',
  "runtimeMatrix.candidateVersion",
  'createArguments.push("--version-number", versionNumber)'
]);
requireOrderedText("scripts/release/create-package-version.mjs", [
  'run("npm", ["run", "release:preflight"]',
  '"scripts/release/check_hosted_validation.mjs"',
  "const createArguments = [",
  'run("sf", createArguments'
]);
requireText("scripts/release/promote-package-version.mjs", [
  '"salesforce-validate.yml"',
  '"subscriber-validate.yml"',
  "runtimeMatrix.candidateVersion",
  "reportedVersion !== runtimeMatrix.candidateVersion",
  '["status", "--porcelain"]'
]);
requireOrderedText("scripts/release/promote-package-version.mjs", [
  '["status", "--porcelain"]',
  '"salesforce-validate.yml"',
  '"subscriber-validate.yml"',
  "const report = runJson",
  '"promote"'
]);
requireText("scripts/release/verify-package-version.mjs", [
  "runInstalledSurfaceGates(alias, securityMode)",
  "const configurationBeforeUpgrade = subscriberConfiguration(alias)",
  "deployUpgradePreservationFixture(alias)",
  "runUpgradeBaseVerification(alias)",
  "assertSubscriberConfigurationPreserved(",
  "writeUpgradeEvidence(",
  "preservationVerified: true",
  "verifyUpgradeBase.apex",
  "runtimeMatrix.candidateVersion",
  "runtimeMatrix.upgradeFromVersion",
  '"contract:org"',
  '"test:browser:salesforce"',
  '"--security-mode"',
  'securityMode === "Locker"',
  "paths.lockerScratchDef"
]);
requireText("scripts/subscriber/data/verifyUpgradeBase.apex", [
  "Subscriber_Smoke_Extension",
  "rhc.RecordHealthCheck.evaluate",
  "baselineResponse.results.size()"
]);
requireText("scripts/release/run_salesforce_browser_gate.mjs", [
  'for (const browser of ["chromium", "firefox"])',
  "`--project=${browser}`",
  "sf",
  '"org"',
  '"open"',
  "RHC_SECOND_ACCOUNT_ID",
  "RHC_SECOND_ACCOUNT_NAME",
  "RHC_BUILDER_URL",
  "RHC_RESTRICTED_BROWSER_URL",
  "RHC_RESTRICTED_CURRENT_PASSWORD",
  "tests/browser/restricted-user-setup.spec.mjs",
  "RHCReleaseMatrixBuilderPage"
]);
requireText("tests/browser/restricted-user-setup.spec.mjs", [
  "completes mandatory first login for the restricted scratch user",
  "Change Your Password",
  "Current Password",
  "Confirm New Password",
  "/\\/lightning\\/page\\/home/"
]);
requireText("tests/browser/app-builder.spec.mjs", [
  "RHC_BUILDER_URL is required; App Builder validation cannot skip.",
  "Select a Check Set in the component properties.",
  'components.locator("lightning-spinner")',
  "RecordHealthCheckController",
  "expect(recordHealthCheckApexRequests).toEqual([])",
  "expect(pageErrors).toEqual([])"
]);
requireText("tests/browser/restricted-persona.spec.mjs", [
  "RHC_RESTRICTED_BROWSER_URL is required; restricted-persona validation cannot skip.",
  "expectCompleted(automaticCard, 4)",
  "expectCompleted(manualCard, 25)",
  "Administrator detail:",
  "expect(pageErrors).toEqual([])"
]);
requireText("tests/browser/lifecycle.mjs", [
  'button[title="Edit Phone"]',
  'performance.getEntriesByType("navigation").length',
  "navigationEntriesAfterClick",
  "expectAutomaticRunCompleted(page)"
]);
requireText("scripts/release/verify_mcp_salesforce_contract.mjs", [
  "RUN_CHECK_SET must account for every Check in the four-type release set.",
  "checkSet.systemError",
  "25"
]);
requireText(
  "packages/record-health-check/integration-tests/main/default/classes/RecordHealthCheckApiIT.cls",
  [
    "The Apex API must return every Check in the four-evaluator release set.",
    "The Apex API response must contain results from every evaluator type."
  ]
);
requireText(
  "packages/record-health-check/integration-tests/main/default/classes/RecordHealthCheckAgentRestResourceIT.cls",
  [
    "REST must account for every Check in the four-evaluator release set.",
    "The REST release set must contain every evaluator type."
  ]
);
requireText(
  "packages/record-health-check/integration-tests/main/default/classes/RecordHealthCheckScopePipelineIT.cls",
  [
    "releaseMatrixEventsContainEveryEvaluationType",
    "RHCIntegrationEventReceipt.receivedEvaluationTypes()",
    "new Set<String>{ 'APEX_API' }"
  ]
);
requireText("subscriber-app/main/default/classes/RHCSubscriberSmokeTest.cls", [
  "packagedCheckSetContainsEveryEvaluationType",
  "subscriberOnLoadSetContainsEveryEvaluationType",
  "installedAgentActionExecutesReleaseMatrixSet",
  "installedPlatformEventsCoverReleaseMatrixSet",
  "restrictedSubscriberIsDeniedAtEveryServerEntryPoint",
  "installedQueueableExecutesReleaseMatrixSet",
  "installedBatchExecutesReleaseMatrixSet",
  "installedScheduledAdapterExecutesReleaseMatrixSet",
  "installedMetadataValidationActionExecutes",
  "rhc.RecordHealthCheckValidateMetadataAction.validateConfiguration()",
  "assertAllTypeAsyncEvents",
  "RHCSubscriberEventReceipt.checkResultCount",
  "RHCSubscriberEventReceipt.setRunCount"
]);
for (const [file, evaluationType] of [
  [
    "subscriber-app/main/default/customMetadata/rhc__Record_Health_Check.Subscriber_On_Load_Formula.md-meta.xml",
    "FORMULA"
  ],
  [
    "subscriber-app/main/default/customMetadata/rhc__Record_Health_Check.Subscriber_On_Load_Query.md-meta.xml",
    "QUERY"
  ],
  [
    "subscriber-app/main/default/customMetadata/rhc__Record_Health_Check.Subscriber_On_Load_Compare.md-meta.xml",
    "COMPARE_TWO_QUERIES"
  ],
  [
    "subscriber-app/main/default/customMetadata/rhc__Record_Health_Check.Subscriber_On_Load_Apex.md-meta.xml",
    "APEX"
  ]
]) {
  requireText(file, ["Subscriber_On_Load", evaluationType]);
}
requireText(
  "subscriber-app/main/default/flexipages/RHCSubscriberReleaseMatrixRecordPage.flexipage-meta.xml",
  [
    "<componentName>rhc:recordHealthCheck</componentName>",
    "<value>rhc__Example_Account_Check_Builder_Guide</value>",
    "<value>Subscriber_On_Load</value>"
  ]
);

for (const file of [
  "packages/record-health-check/config/project-scratch-def.json",
  "config/subscriber-scratch-def.json",
  "config/lws-scratch-def.json"
]) {
  const definition = JSON.parse(fs.readFileSync(path.join(root, file), "utf8"));
  if (
    definition.settings?.securitySettings?.sessionSettings
      ?.lockerServiceNext !== true
  ) {
    errors.push(`${file} must explicitly enable Lightning Web Security.`);
  }
}
const lockerDefinition = JSON.parse(
  fs.readFileSync(path.join(root, "config/locker-scratch-def.json"), "utf8")
);
if (
  lockerDefinition.settings?.securitySettings?.sessionSettings
    ?.lockerServiceNext !== false
) {
  errors.push(
    "config/locker-scratch-def.json must explicitly enable Lightning Locker."
  );
}

const browserPages = [
  {
    file: "packages/record-health-check/integration-tests/browser-fixtures/namespaced/main/default/flexipages/RHCReleaseMatrixRecordPage.flexipage-meta.xml",
    markers: [
      "<componentName>rhc:recordHealthCheck</componentName>",
      "<value>rhc__Example_Account_Check_Builder_Guide</value>",
      "<value>rhc__Account_Data_Quality</value>"
    ]
  },
  {
    file: "packages/record-health-check/integration-tests/browser-fixtures/no-namespace/main/default/flexipages/RHCReleaseMatrixRecordPage.flexipage-meta.xml",
    markers: [
      "<componentName>c:recordHealthCheck</componentName>",
      "<value>Example_Account_Check_Builder_Guide</value>",
      "<value>Account_Data_Quality</value>"
    ]
  }
];
for (const { file, markers } of browserPages) {
  requireUniqueXmlValues(file, "identifier");
  requireUniqueRegionNames(file);
  requireText(file, [...markers, "<name>main</name>"]);
}
for (const { file, markers } of [
  {
    file: "packages/record-health-check/integration-tests/browser-fixtures/namespaced/main/default/flexipages/RHCReleaseMatrixBuilderPage.flexipage-meta.xml",
    markers: [
      "<componentName>rhc:recordHealthCheck</componentName>",
      "<value>rhc__Example_Account_Check_Builder_Guide</value>",
      "rhc_recordHealthCheck_builderUnconfigured"
    ]
  },
  {
    file: "packages/record-health-check/integration-tests/browser-fixtures/no-namespace/main/default/flexipages/RHCReleaseMatrixBuilderPage.flexipage-meta.xml",
    markers: [
      "<componentName>c:recordHealthCheck</componentName>",
      "<value>Example_Account_Check_Builder_Guide</value>",
      "c_recordHealthCheck_builderUnconfigured"
    ]
  },
  {
    file: "subscriber-app/main/default/flexipages/RHCReleaseMatrixBuilderPage.flexipage-meta.xml",
    markers: [
      "<componentName>rhc:recordHealthCheck</componentName>",
      "<value>rhc__Example_Account_Check_Builder_Guide</value>",
      "rhc_recordHealthCheck_builderUnconfigured"
    ]
  }
]) {
  requireUniqueXmlValues(file, "identifier");
  requireUniqueRegionNames(file);
  requireText(file, markers);
}
requireText("tests/browser/release-matrix.spec.mjs", [
  "RHC_BROWSER_URL is required; browser validation cannot skip.",
  "Invalid contextElement",
  '"c-record-health-check, rhc-record-health-check"',
  'components.locator("lightning-spinner")',
  'page.locator(".slds-spinner_container:visible")',
  "expectRunCompleted(automaticCard, 4)",
  "expectRunCompleted(manualCard, 25)",
  "expect(pageErrors).toEqual([])"
]);
requireText(
  "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/__tests__/recordHealthCheck.test.js",
  [
    "keeps the App Builder preview quiet without a record context",
    "keeps the App Builder preview quiet when Salesforce supplies a sample record",
    "does not render runtime actions in a configured Builder preview",
    "shows Builder guidance without Apex when no Check Set is selected",
    "uses the Lightning Locker registration protocol when LWS registration is rejected"
  ]
);
requireText(
  "packages/record-health-check/integration-tests/main/default/classes/RecordHealthCheckSandboxAsyncTest.cls",
  [
    "new Set<String>{ 'APEX', 'COMPARE_TWO_QUERIES', 'FORMULA', 'QUERY' }",
    "configuredByQualifiedName",
    "configuredCheck.QualifiedApiName",
    "The Queueable should complete.",
    "The Batch should complete."
  ]
);
requireText(
  "packages/record-health-check/integration-tests/main/default/classes/RecordHealthCheckAutomationAsyncTest.cls",
  [
    "queueableExecutesEveryEvaluationType",
    "batchExecutesEveryEvaluationType",
    "scheduledExecutesEveryEvaluationType",
    "RHCIntegrationEventReceipt.checkQualifiedNames",
    "new Set<String>{ 'APEX', 'COMPARE_TWO_QUERIES', 'FORMULA', 'QUERY' }",
    "RecordHealthCheckEventPublication.ALL",
    "Test.getEventBus().deliver()"
  ]
);
requireText("subscriber-app/main/default/classes/RHCSubscriberSmokeTest.cls", [
  "assertEventIdentitiesCoverEveryEvaluationType",
  "RHCSubscriberEventReceipt.checkQualifiedNames",
  "RHCSubscriberEventReceipt.checkSources"
]);

if (errors.length > 0) {
  throw new Error(
    `Release runtime matrix is blocked:\n- ${errors.join("\n- ")}`
  );
}

process.stdout.write(
  "Release runtime matrix is structurally complete and every required evidence artifact exists.\n"
);
