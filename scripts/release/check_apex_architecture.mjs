import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const baselinePath = path.join(
  root,
  "scripts/release/generated/apex-architecture-baseline.json"
);
const baseline = JSON.parse(fs.readFileSync(baselinePath, "utf8"));
const sourceRoots = [
  "packages/record-health-check/force-app",
  "packages/record-health-check/integration-tests"
];
const failures = [];

function filesUnder(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const child = path.join(directory, entry.name);
    return entry.isDirectory() ? filesUnder(child) : [child];
  });
}

function relative(file) {
  return path.relative(root, file).split(path.sep).join("/");
}

function count(text, expression) {
  return [...text.matchAll(expression)].length;
}

const apexFiles = sourceRoots
  .flatMap((sourceRoot) => filesUnder(path.join(root, sourceRoot)))
  .filter((file) => file.endsWith(".cls") || file.endsWith(".trigger"));

for (const file of apexFiles) {
  const fileName = relative(file);
  const source = fs.readFileSync(file, "utf8");
  const testVisibleCount = count(source, /@TestVisible\b/g);
  const testBranchCount = count(source, /Test\.isRunningTest\s*\(\s*\)/g);
  const debugCount = count(source, /System\.debug\s*\(/g);
  const lineCount =
    source.split(/\r?\n/).length - (source.endsWith("\n") ? 1 : 0);
  const testVisiblePolicy = baseline.testVisible[fileName];

  if (testVisibleCount > (testVisiblePolicy?.maximum ?? 0)) {
    failures.push(
      `${fileName}: @TestVisible count ${testVisibleCount} exceeds approved maximum ${testVisiblePolicy?.maximum ?? 0}`
    );
  }
  if (testVisiblePolicy && testVisibleCount < testVisiblePolicy.maximum) {
    failures.push(
      `${fileName}: @TestVisible count fell to ${testVisibleCount}; reduce the approved maximum ${testVisiblePolicy.maximum} in the same change`
    );
  }
  if (testBranchCount > (baseline.testRuntimeBranches[fileName] ?? 0)) {
    failures.push(
      `${fileName}: Test.isRunningTest() count ${testBranchCount} exceeds approved maximum ${baseline.testRuntimeBranches[fileName] ?? 0}`
    );
  }
  if (
    fileName in baseline.testRuntimeBranches &&
    testBranchCount < baseline.testRuntimeBranches[fileName]
  ) {
    failures.push(
      `${fileName}: remove the obsolete Test.isRunningTest() baseline entry`
    );
  }
  if (debugCount > (baseline.systemDebug[fileName] ?? 0)) {
    failures.push(
      `${fileName}: System.debug count ${debugCount} exceeds approved maximum ${baseline.systemDebug[fileName] ?? 0}`
    );
  }
  if (
    fileName in baseline.systemDebug &&
    debugCount < baseline.systemDebug[fileName]
  ) {
    failures.push(
      `${fileName}: reduce the obsolete System.debug baseline count`
    );
  }
  if (
    fileName.startsWith("packages/record-health-check/force-app/") &&
    lineCount >
      (baseline.maximumApexClassLinesByFile?.[fileName]?.maximum ??
        baseline.maximumApexClassLines)
  ) {
    const maximum =
      baseline.maximumApexClassLinesByFile?.[fileName]?.maximum ??
      baseline.maximumApexClassLines;
    failures.push(
      `${fileName}: ${lineCount} lines exceeds the ${maximum}-line review ceiling`
    );
  }
  if (/compatibility wrappers|prior API|older org/i.test(source)) {
    failures.push(
      `${fileName}: contains prohibited legacy-compatibility language`
    );
  }
  if (/@TestVisible\s+(?:public|global)\b/s.test(source)) {
    failures.push(
      `${fileName}: public/global members must not carry redundant @TestVisible`
    );
  }
}

for (const [fileName, policy] of Object.entries(
  baseline.maximumApexClassLinesByFile ?? {}
)) {
  if (!fs.existsSync(path.join(root, fileName))) {
    failures.push(`${fileName}: approved line-ceiling file no longer exists`);
  } else if (!policy.category?.trim()) {
    failures.push(`${fileName}: approved line-ceiling entry has no category`);
  }
}

for (const [fileName, policy] of Object.entries(baseline.testVisible)) {
  if (!fs.existsSync(path.join(root, fileName))) {
    failures.push(
      `${fileName}: approved @TestVisible file no longer exists; update the baseline`
    );
  } else if (!policy.category?.trim()) {
    failures.push(`${fileName}: approved @TestVisible entry has no category`);
  }
}

if (failures.length > 0) {
  console.error("Apex architecture policy failed:\n- " + failures.join("\n- "));
  process.exit(1);
}

const approvedTestVisible = Object.values(baseline.testVisible).reduce(
  (total, policy) => total + policy.maximum,
  0
);
console.log(
  `Apex architecture policy passed: ${apexFiles.length} files checked; ` +
    `${approvedTestVisible} @TestVisible annotations form the no-growth ceiling.`
);
