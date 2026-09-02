#!/usr/bin/env node

import path from "node:path";
import { analyzerIntegrityErrors } from "../lib/code-analyzer-integrity.mjs";

function option(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function repeatedOption(name) {
  return process.argv.flatMap((value, index) =>
    value === name && process.argv[index + 1] ? [process.argv[index + 1]] : []
  );
}

const logDirectory = path.resolve(option("--log-dir") ?? "code-analyzer/logs");
const outputFiles = repeatedOption("--output").map((file) =>
  path.resolve(file)
);
if (outputFiles.length === 0) {
  console.error("Pass at least one analyzer JSON file with --output.");
  process.exit(2);
}

const errors = analyzerIntegrityErrors(logDirectory, outputFiles);
if (errors.length > 0) {
  throw new Error(
    `Code Analyzer integrity gate failed:\n- ${errors.join("\n- ")}`
  );
}

console.log(
  `Code Analyzer integrity passed for ${outputFiles.length} complete report(s); no engine processing errors were logged.`
);
