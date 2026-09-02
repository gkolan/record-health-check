import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const allowedRoot = "code-analyzer/";
const ignoredDirectories = new Set([".git", "node_modules", "code-analyzer"]);
const searchableExtensions = new Set([
  ".json",
  ".md",
  ".mjs",
  ".sh",
  ".yaml",
  ".yml"
]);
const analyzerArtifactPattern =
  /(?:^|\/)(?:code-analyzer(?:-results)?|sfca)[^/]*\.(?:html|json|log|sarif)$/i;
const analyzerPolicyFiles = new Set([
  "config/code-analyzer-inline-suppressions.json"
]);
const violations = [];

function relative(filePath) {
  return path.relative(root, filePath).split(path.sep).join("/");
}

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (ignoredDirectories.has(entry.name)) {
      continue;
    }

    const absolutePath = path.join(directory, entry.name);
    const relativePath = relative(absolutePath);
    if (entry.isDirectory()) {
      walk(absolutePath);
      continue;
    }

    if (
      analyzerArtifactPattern.test(relativePath) &&
      !analyzerPolicyFiles.has(relativePath)
    ) {
      violations.push(
        `${relativePath}: Code Analyzer artifacts belong under ${allowedRoot}`
      );
    }

    if (!searchableExtensions.has(path.extname(entry.name))) {
      continue;
    }

    const contents = fs.readFileSync(absolutePath, "utf8");
    if (/^code-analyzer(?:-neutral)?\.ya?ml$/.test(relativePath)) {
      const logFolder = contents.match(
        /^log_folder:\s*["']?([^"'\n]+)["']?\s*$/m
      )?.[1];
      if (logFolder !== "code-analyzer/logs") {
        violations.push(
          `${relativePath}: log_folder must be code-analyzer/logs`
        );
      }
    }

    for (const match of contents.matchAll(
      /--output-file(?:=|\s+)(?:["']([^"']+)["']|([^\s\\]+))/g
    )) {
      const outputPath = (match[1] ?? match[2]).replace(/^\.\//, "");
      if (!/\.(?:html|json|log|sarif)$/i.test(outputPath)) {
        continue;
      }
      if (!outputPath.startsWith(allowedRoot)) {
        violations.push(
          `${relativePath}: Code Analyzer --output-file must be under ${allowedRoot} (found ${outputPath})`
        );
      }
    }
  }
}

walk(root);

if (violations.length > 0) {
  console.error(
    "Code Analyzer output-path policy failed:\n" +
      violations.map((item) => `- ${item}`).join("\n")
  );
  process.exit(1);
}

console.log("Code Analyzer output-path policy passed.");
