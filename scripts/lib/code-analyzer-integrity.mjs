import fs from "node:fs";
import path from "node:path";

const ENGINE_ERROR =
  /(?:\]\s+Error\s+\S+\s+-|processing error|NullPointerException|emitted an error)/i;

export function analyzerIntegrityErrors(logDirectory, outputFiles) {
  const errors = [];
  if (!fs.existsSync(logDirectory)) {
    errors.push(`Analyzer log directory does not exist: ${logDirectory}`);
  } else {
    for (const entry of fs.readdirSync(logDirectory)) {
      if (!entry.endsWith(".log")) continue;
      const file = path.join(logDirectory, entry);
      const text = fs.readFileSync(file, "utf8");
      if (ENGINE_ERROR.test(text)) {
        errors.push(`${file} contains an analyzer engine processing error.`);
      }
    }
  }

  for (const outputFile of outputFiles) {
    if (!fs.existsSync(outputFile)) {
      errors.push(`Analyzer JSON output does not exist: ${outputFile}`);
      continue;
    }
    try {
      const report = JSON.parse(fs.readFileSync(outputFile, "utf8"));
      if (
        !report.versions ||
        !report.violationCounts ||
        !Array.isArray(report.violations)
      ) {
        errors.push(`${outputFile} is not a complete Code Analyzer report.`);
      }
    } catch (error) {
      errors.push(`${outputFile} is not valid JSON: ${error.message}`);
    }
  }
  return errors;
}
