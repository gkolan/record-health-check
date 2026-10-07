#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const controller = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckController.cls"
  ),
  "utf8"
);
const component = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.js"
  ),
  "utf8"
);
const definitionValidation = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/healthCheckDefinitions.js"
  ),
  "utf8"
);
const componentMetadata = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.js-meta.xml"
  ),
  "utf8"
);
const runner = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/healthCheckRunner.js"
  ),
  "utf8"
);
const constants = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckConstants.cls"
  ),
  "utf8"
);
const formulaEvaluator = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckFormulaEvaluator.cls"
  ),
  "utf8"
);
const activityCheck = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/AccountHasRecentActivityCheck.cls"
  ),
  "utf8"
);
const configService = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckConfigService.cls"
  ),
  "utf8"
);
const definitionLoader = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckDefinitionLoader.cls"
  ),
  "utf8"
);
const metadataSetValidator = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckMetadataSetValidator.cls"
  ),
  "utf8"
);
const metadataSetValidatorTest = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RHCMetadataSetValidatorTest.cls"
  ),
  "utf8"
);
const definitionLoaderTest = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckDefinitionLoaderTest.cls"
  ),
  "utf8"
);
const componentTemplate = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.html"
  ),
  "utf8"
);
const componentStyles = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.css"
  ),
  "utf8"
);
const componentTest = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/__tests__/recordHealthCheck.test.js"
  ),
  "utf8"
);
const componentDiagnostics = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/healthCheckDiagnostics.js"
  ),
  "utf8"
);
const componentModel = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/healthCheckModel.js"
  ),
  "utf8"
);
const controllerErrorTest = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckControllerErrorTest.cls"
  ),
  "utf8"
);
const headingIntegrationTest = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/integration-tests/main/default/classes/RHCCardHeadingTest.cls"
  ),
  "utf8"
);
const headingFixtureContract = JSON.parse(
  fs.readFileSync(
    path.join(root, "tests/fixtures/card-heading/contract.json"),
    "utf8"
  )
);
const headingFixtureGuide = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/integration-tests/card-heading-display.md"
  ),
  "utf8"
);
const failures = [];

const expectedHiddenHeadingConfigurationErrors = [
  ["RHC_Heading_Action", "LABEL_AND_ICON"],
  ["RHC_Heading_NoneLabelManual", "LABEL_ONLY"],
  ["RHC_Heading_NoneIconManual", "ICON_ONLY"],
  ["RHC_Heading_NoneManual", "HIDE"]
].map(([fixture, button]) => ({
  fixture,
  heading: "HIDE",
  button,
  run: "RUN_ON_REQUEST",
  outcome: "INVALID_CONFIG"
}));
const expectedHiddenHeadingPageLoadCases = [
  ["RHC_Heading_NoneBothAuto", "LABEL_AND_ICON"],
  ["RHC_Heading_NoneLabelAuto", "LABEL_ONLY"],
  ["RHC_Heading_NoneIconAuto", "ICON_ONLY"],
  ["RHC_Heading_None", "HIDE"]
].map(([fixture, button]) => ({
  fixture,
  heading: "HIDE",
  button,
  run: "RUN_ON_LOAD",
  outcome: "VALID"
}));

if (
  JSON.stringify(headingFixtureContract.configurationErrorMatrix) !==
  JSON.stringify(expectedHiddenHeadingConfigurationErrors)
) {
  failures.push(
    "Hidden-heading Manual configuration-error matrix must cover all four button styles with INVALID_CONFIG."
  );
}
if (
  JSON.stringify(headingFixtureContract.hiddenHeadingPageLoadMatrix) !==
  JSON.stringify(expectedHiddenHeadingPageLoadCases)
) {
  failures.push(
    "Hidden-heading page-load matrix must keep all four button styles valid."
  );
}
for (const expected of [
  ...expectedHiddenHeadingConfigurationErrors,
  ...expectedHiddenHeadingPageLoadCases
]) {
  const fixture = headingFixtureContract.sets.find(
    ({ name }) => name === expected.fixture
  );
  if (
    !fixture ||
    fixture.heading !== expected.heading ||
    fixture.button !== expected.button ||
    fixture.run !== expected.run
  ) {
    failures.push(
      `Heading outcome matrix does not match fixture ${expected.fixture}.`
    );
  }
}

const requiredIntegrationFixtures = [
  "Record_Health_Check_Set.Review_Summary_Above_Checks.md-meta.xml",
  "Record_Health_Check.Review_Summary_Account_Name.md-meta.xml",
  "Record_Health_Check.Review_Summary_Account_Industry.md-meta.xml"
];
const integrationMetadataDirectory = path.join(
  root,
  "packages/record-health-check/integration-tests/main/default/customMetadata"
);
const checkSetMetadataDirectories = [
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/customMetadata"
  ),
  integrationMetadataDirectory
];

for (const fixture of requiredIntegrationFixtures) {
  if (!fs.existsSync(path.join(integrationMetadataDirectory, fixture))) {
    failures.push(`Missing required integration-test fixture: ${fixture}`);
  }
}

for (const directory of checkSetMetadataDirectories) {
  for (const fileName of fs
    .readdirSync(directory)
    .filter((name) => name.startsWith("Record_Health_Check_Set."))) {
    const metadata = fs.readFileSync(path.join(directory, fileName), "utf8");
    const summaryDisplay = metadata.match(
      /<field>SummaryDisplay__c<\/field>\s*<value[^>]*>(TOP|BOTTOM|HIDE)<\/value>/
    )?.[1];
    if (!summaryDisplay) {
      failures.push(
        `Check Set must explicitly set SummaryDisplay__c to TOP, BOTTOM or HIDE: ${fileName}`
      );
    }
  }
}

const appBuilderProperties = [
  ...componentMetadata.matchAll(
    /<property\s+[\s\S]*?name="([^"]+)"[\s\S]*?\/>/g
  )
].map((match) => match[1]);
const requiredAppBuilderProperties = ["checkSetName"];
if (
  appBuilderProperties.length !== requiredAppBuilderProperties.length ||
  requiredAppBuilderProperties.some(
    (property, index) => appBuilderProperties[index] !== property
  )
) {
  failures.push(
    `Lightning App Builder must expose only checkSetName; found: ${appBuilderProperties.join(", ") || "none"}`
  );
}
if (componentMetadata.includes('name="whenChecksRun"')) {
  failures.push(
    "Lightning App Builder must not duplicate the Check Set run mode"
  );
}

for (const parameter of [
  "String checkSetQualifiedApiName",
  "String checkQualifiedApiName"
]) {
  if (!controller.includes(parameter)) {
    failures.push(
      `Apex controller is missing required parameter: ${parameter}`
    );
  }
}

for (const retiredKey of ["checkSetDeveloperName:", "checkDeveloperName:"]) {
  if (component.includes(retiredKey) || runner.includes(retiredKey)) {
    failures.push(`Lightning Apex payload uses prohibited key: ${retiredKey}`);
  }
}

for (const requiredKey of [
  "checkSetQualifiedApiName:",
  "checkQualifiedApiName:"
]) {
  if (!component.includes(requiredKey) && !runner.includes(requiredKey)) {
    failures.push(
      `Lightning Apex payload is missing required key: ${requiredKey}`
    );
  }
}

if (/qualifiedApiName\s*\|\|\s*[^\n]*developerName/.test(component + runner)) {
  failures.push("Lightning contains a QualifiedApiName-to-DeveloperName retry");
}

const prohibitedFallbacks = [
  {
    source: runner,
    pattern:
      /source\s*===\s*["']USER_INITIATED["']\s*\?[^:]+:\s*["']RUN_ON_LOAD["']/,
    message: "Lightning silently coerces an unknown execution source"
  },
  {
    source: formulaEvaluator,
    pattern: /resolveFormulaSingleValue\(formulaExpression,\s*record,\s*null\)/,
    message: "Formula evaluation treats a missing return type as AUTO"
  },
  {
    source: activityCheck,
    pattern: /\?\s*DEFAULT_DAYS_BACK\s*:\s*parsed/,
    message: "Recent-activity configuration silently replaces invalid daysBack"
  },
  {
    source: configService,
    pattern:
      /String\.isBlank\(checkSet\.FoundExpectedDisplay__c\)\s*\?\s*["']ON_DEMAND["']/,
    message: "Check Set comparison display has an implicit runtime default"
  }
];

for (const check of prohibitedFallbacks) {
  if (check.pattern.test(check.source)) {
    failures.push(check.message);
  }
}

for (const requiredContract of [
  [
    constants,
    "throw new IllegalArgumentException",
    "strict Apex enum rejection"
  ],
  [formulaEvaluator, "'INVALID_CONFIG'", "formula return-type rejection"],
  [activityCheck, "unableToEvaluate('INVALID_CONFIG')", "daysBack rejection"],
  [
    definitionLoader,
    "Card Title is required",
    "required Card Title validation"
  ],
  [
    configService,
    "normalized == 'HIDE' && cardRunMode == 'RUN_ON_REQUEST'",
    "hidden-heading Manual rejection"
  ],
  [
    metadataSetValidator,
    "Card Heading Display cannot be Hide when checks run only after a user clicks Run.",
    "metadata validation for hidden Manual headings"
  ],
  [
    definitionValidation,
    'response.triggerMode === "Manual" && cardHeadingDisplay === "HIDE"',
    "client-side hidden Manual heading defense"
  ],
  [
    component,
    "validateDefinitions(response, this.frameworkMaxChecks)",
    "definition validation before applying component state"
  ],
  [
    component,
    "return !this.hasComponentError && !this.showNormalHeader",
    "error-header body spacing guard"
  ],
  [
    metadataSetValidatorTest,
    "rejectsHiddenManualHeadingForEveryButtonStyle",
    "metadata validator button-style matrix test"
  ],
  [
    definitionLoaderTest,
    "rejectsHiddenManualHeadingForEveryButtonStyleAtDefinitionBoundary",
    "definition boundary button-style matrix test"
  ],
  [
    componentTest,
    "keeps a page-load hidden heading valid without an action row for %s",
    "rendered valid hidden-heading matrix test"
  ],
  [
    componentTest,
    "loads the full definition to reject a hidden Manual heading for %s",
    "rendered shell configuration-error matrix test"
  ],
  [
    componentTest,
    "rejects a hidden Manual heading in a definition response for %s",
    "rendered definition configuration-error matrix test"
  ],
  [
    controller,
    "buildAuraException(ex.reasonCode, ex.getMessage(), true)",
    "server-verified detail entitlement on configuration errors"
  ],
  [
    componentModel,
    'typeof parsed.canViewDetails === "boolean"',
    "structured error detail-entitlement parsing"
  ],
  [
    component,
    'typeof parsed.canViewDetails === "boolean"',
    "component application of verified detail entitlement"
  ],
  [
    componentDiagnostics,
    'guidance: "Ask your Salesforce admin to review this Check Set in Setup.",\n    retryable: true',
    "retryable invalid-configuration presentation"
  ],
  [
    controllerErrorTest,
    "getCheckDefinitionsCarriesVerifiedAdministratorEntitlement",
    "Apex administrator-entitlement regression test"
  ],
  [
    headingIntegrationTest,
    "headingModesPreserveIndependentPassAndFailOutcomes",
    "integration PASS/FAIL heading-independence regression test"
  ],
  [
    headingIntegrationTest,
    "hiddenManualHeadingConfigurationsFailBeforeEvaluation",
    "integration invalid-heading pre-evaluation regression test"
  ],
  [
    componentTest,
    "shows exact invalid configuration only when detail entitlement is %s",
    "administrator-detail visibility regression test"
  ],
  [
    componentTest,
    "recovers after a hidden Manual heading is corrected to page-load",
    "invalid-configuration recovery regression test"
  ],
  [
    headingFixtureGuide,
    "All four must report\nINVALID_CONFIG with no evaluations.",
    "manual verification outcome for every invalid hidden-heading fixture"
  ],
  [
    headingFixtureGuide,
    "After correcting the Set to `RUN_ON_LOAD`, select **Try\nAgain**",
    "manual invalid-configuration recovery procedure"
  ]
]) {
  if (!requiredContract[0].includes(requiredContract[1])) {
    failures.push(`Missing ${requiredContract[2]}`);
  }
}

for (const [sourceName, source] of [
  ["template", componentTemplate],
  ["styles", componentStyles],
  ["component", component]
]) {
  if (source.includes("rhc-body-action-row")) {
    failures.push(
      `Record-page card ${sourceName} must not restore a separate body action row.`
    );
  }
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  "Verified exact QualifiedApiName identity, metadata-owned run scheduling, hidden-heading configuration errors, strict configuration contracts, and required integration-test fixtures."
);
