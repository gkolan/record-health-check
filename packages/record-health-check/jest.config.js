const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

const lwcRoot = "force-app/main/default/lwc/recordHealthCheck";

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  collectCoverageFrom: [
    `${lwcRoot}/recordHealthCheck.js`,
    `${lwcRoot}/healthCheckDiagnostics.js`,
    `${lwcRoot}/healthCheckModel.js`,
    `${lwcRoot}/healthCheckPresentation.js`,
    `${lwcRoot}/healthCheckRunner.js`
  ],
  coverageThreshold: {
    global: {
      branches: 75,
      functions: 98,
      lines: 98,
      statements: 98
    },
    [`${lwcRoot}/recordHealthCheck.js`]: {
      lines: 98
    },
    [`${lwcRoot}/healthCheckDiagnostics.js`]: {
      lines: 98
    },
    [`${lwcRoot}/healthCheckModel.js`]: {
      lines: 98
    },
    [`${lwcRoot}/healthCheckPresentation.js`]: {
      lines: 98
    },
    [`${lwcRoot}/healthCheckRunner.js`]: {
      lines: 98
    }
  }
};
