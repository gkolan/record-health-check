#!/usr/bin/env node

import fs from "node:fs";
import { codeAnalyzerSuppressionErrors } from "../lib/code-analyzer-suppressions.mjs";

const configFile = "code-analyzer.yml";
const errors = codeAnalyzerSuppressionErrors(
  fs.readFileSync(configFile, "utf8")
);
if (errors.length > 0) {
  throw new Error(
    `Code Analyzer suppression allowlist failed:\n- ${errors.join("\n- ")}`
  );
}

console.log(
  "Code Analyzer suppression allowlist passed: exactly four file-scoped, single-finding ProtectSensitiveData exceptions."
);
