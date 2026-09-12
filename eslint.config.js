const { defineConfig } = require("eslint/config");
const eslintJs = require("@eslint/js");
const jestPlugin = require("eslint-plugin-jest");
const auraConfig = require("@salesforce/eslint-plugin-aura");
const lwcConfig = require("@salesforce/eslint-config-lwc/recommended");
const lockerConfig = require("@locker/eslint-config-locker/recommended");
const globals = require("globals");

module.exports = defineConfig([
  // Aura configuration
  {
    files: ["**/aura/**/*.js"],
    extends: [...auraConfig.configs.recommended, ...auraConfig.configs.locker]
  },

  // LWC configuration
  {
    files: ["**/lwc/**/*.js"],
    extends: [lwcConfig]
  },

  // Salesforce's security-specific rules model browser APIs that are blocked
  // or distorted by Lightning Web Security. Keep test-only browser fixtures
  // out of this production-source gate.
  {
    files: ["**/lwc/**/*.js"],
    ignores: ["**/lwc/**/__tests__/**", "**/lwc/**/__mocks__/**"],
    extends: [...lockerConfig]
  },

  // Enforce braces on maintained source, not saved org-readback evidence.
  {
    files: ["packages/**/lwc/**/*.js", "subscriber-app/**/lwc/**/*.js"],
    ignores: ["**/__tests__/**", "**/__mocks__/**"],
    rules: {
      curly: ["error", "all"]
    }
  },

  // LWC configuration with override for LWC test files
  {
    files: ["**/lwc/**/*.test.js"],
    extends: [lwcConfig],
    rules: {
      "@lwc/lwc/no-unexpected-wire-adapter-usages": "off"
    },
    languageOptions: {
      globals: {
        ...globals.node
      }
    }
  },

  // Gate scripts, browser-test drivers, and root tooling configs. These are the
  // code that enforces every release gate, so they get the same baseline as any
  // other source in the repo. Node globals only - nothing here runs in a browser.
  {
    files: ["scripts/**/*.mjs", "tests/**/*.mjs", "*.mjs"],
    languageOptions: {
      sourceType: "module",
      ecmaVersion: "latest",
      globals: {
        ...globals.node
      }
    },
    plugins: {
      eslintJs
    },
    extends: ["eslintJs/recommended"],
    rules: {
      // An underscore prefix is this repo's existing marker for a binding that
      // is named for the reader but deliberately unused - dropping a key with
      // rest destructuring is the common case.
      "no-unused-vars": [
        "error",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
          caughtErrorsIgnorePattern: "^_",
          ignoreRestSiblings: true
        }
      ]
    }
  },

  // Jest mocks configuration
  {
    files: ["**/jest-mocks/**/*.js"],
    languageOptions: {
      sourceType: "module",
      ecmaVersion: "latest",
      globals: {
        ...globals.node,
        ...globals.es2021,
        ...jestPlugin.environments.globals.globals
      }
    },
    plugins: {
      eslintJs
    },
    extends: ["eslintJs/recommended"]
  }
]);
