import fs from "node:fs";
import path from "node:path";

function apexWithoutComments(source) {
  let result = "";
  let index = 0;
  let state = "code";

  while (index < source.length) {
    const character = source[index];
    const next = source[index + 1];

    if (state === "line-comment") {
      if (character === "\n") {
        state = "code";
        result += character;
      } else {
        result += " ";
      }
      index += 1;
      continue;
    }

    if (state === "block-comment") {
      if (character === "*" && next === "/") {
        result += "  ";
        index += 2;
        state = "code";
      } else {
        result += character === "\n" ? "\n" : " ";
        index += 1;
      }
      continue;
    }

    if (state === "string") {
      result += character;
      if (character === "\\" && next !== undefined) {
        result += next;
        index += 2;
      } else if (character === "'") {
        state = "code";
        index += 1;
      } else {
        index += 1;
      }
      continue;
    }

    if (character === "/" && next === "/") {
      result += "  ";
      index += 2;
      state = "line-comment";
    } else if (character === "/" && next === "*") {
      result += "  ";
      index += 2;
      state = "block-comment";
    } else {
      result += character;
      if (character === "'") {
        state = "string";
      }
      index += 1;
    }
  }

  return result;
}

function classFiles(directory) {
  if (!fs.existsSync(directory)) {
    return [];
  }

  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      return classFiles(absolutePath);
    }
    return entry.isFile() && entry.name.endsWith(".cls") ? [absolutePath] : [];
  });
}

function hasExecutableTestMethod(source, classDeclarationEnd) {
  const classBody = source.slice(classDeclarationEnd);
  return (
    /@istest(?:\s*\([^)]*\))?\s+(?:(?:private|public|protected|global|static)\s+)*void\s+[a-z_$][\w$]*\s*\(/i.test(
      classBody
    ) || /\bstatic\s+testmethod\s+void\s+[a-z_$][\w$]*\s*\(/i.test(classBody)
  );
}

function testSetupMethodCount(source, classDeclarationEnd) {
  const classBody = source.slice(classDeclarationEnd);
  return (
    classBody.match(
      /@testsetup\s+(?:(?:private|public|protected|global|static)\s+)*void\s+[a-z_$][\w$]*\s*\(/gi
    ) ?? []
  ).length;
}

export function discoverApexTestClasses(
  root,
  sourceDirectories,
  { overlayClassNames = [] } = {}
) {
  const inventoryByName = new Map();
  const annotatedFilesByName = new Map();
  const approvedOverlays = new Set(
    overlayClassNames.map((className) => className.toLowerCase())
  );

  for (const sourceDirectory of sourceDirectories) {
    const absoluteDirectory = path.resolve(root, sourceDirectory);
    for (const file of classFiles(absoluteDirectory)) {
      const source = apexWithoutComments(fs.readFileSync(file, "utf8"));
      const className = path.basename(file, ".cls");
      const classDeclaration = new RegExp(
        `\\bclass\\s+${className}\\b`,
        "i"
      ).exec(source);
      if (
        !classDeclaration ||
        !/@istest\b/i.test(source.slice(0, classDeclaration.index))
      ) {
        continue;
      }
      const entry = {
        className,
        file: path.relative(root, file).split(path.sep).join("/"),
        testSetupMethodCount: testSetupMethodCount(
          source,
          classDeclaration.index + classDeclaration[0].length
        )
      };
      const key = className.toLowerCase();
      const annotatedFiles = [
        ...(annotatedFilesByName.get(key) ?? []),
        entry.file
      ];
      annotatedFilesByName.set(key, annotatedFiles);
      if (annotatedFiles.length > 1 && !approvedOverlays.has(key)) {
        throw new Error(
          `Unexpected duplicate Apex test class ${className}: ${annotatedFiles.join(", ")}`
        );
      }
      if (
        !hasExecutableTestMethod(
          source,
          classDeclaration.index + classDeclaration[0].length
        )
      ) {
        continue;
      }
      const existing = inventoryByName.get(key);
      inventoryByName.set(key, {
        ...entry,
        files: annotatedFiles
      });
    }
  }

  const inventory = [...inventoryByName.values()];
  for (const entry of inventory) {
    entry.files = annotatedFilesByName.get(entry.className.toLowerCase());
  }
  inventory.sort((left, right) =>
    left.className.localeCompare(right.className)
  );
  const invalidOverlays = [...approvedOverlays].filter(
    (key) => (annotatedFilesByName.get(key)?.length ?? 0) !== 2
  );
  if (invalidOverlays.length > 0) {
    throw new Error(
      `Approved Apex test overlays must each resolve to exactly two files: ${invalidOverlays
        .map((key) => inventoryByName.get(key)?.className ?? key)
        .join(", ")}`
    );
  }

  return inventory;
}

export function verifyApexTestResult(inventory, result) {
  const summary = result?.summary;
  const tests = result?.tests;
  if (!summary || !Array.isArray(tests)) {
    throw new Error("Salesforce Apex test result is missing summary or tests.");
  }

  const failures = tests.filter(
    (entry) => String(entry.Outcome).toLowerCase() !== "pass"
  );
  if (
    summary.outcome !== "Passed" ||
    Number(summary.failing) !== 0 ||
    failures.length > 0
  ) {
    throw new Error(
      `Apex tests did not pass: outcome=${summary.outcome}, failing=${summary.failing}, non-pass results=${failures.length}.`
    );
  }

  const requestedByKey = new Map(
    inventory.map((entry) => [entry.className.toLowerCase(), entry.className])
  );
  const executed = new Set(
    tests
      .map((entry) => entry?.ApexClass?.Name)
      .filter(
        (className) => typeof className === "string" && className.length > 0
      )
  );
  const executedByKey = new Map(
    [...executed].map((className) => [className.toLowerCase(), className])
  );
  const missing = [...requestedByKey].flatMap(([key, className]) =>
    executedByKey.has(key) ? [] : [className]
  );
  const unexpected = [...executed].filter(
    (className) => !requestedByKey.has(className.toLowerCase())
  );

  if (missing.length > 0 || unexpected.length > 0) {
    throw new Error(
      [
        missing.length > 0 ? `Missing test classes: ${missing.join(", ")}` : "",
        unexpected.length > 0
          ? `Unexpected test classes: ${unexpected.join(", ")}`
          : ""
      ]
        .filter(Boolean)
        .join("\n")
    );
  }

  const expectedSetupMethodCount = inventory.reduce(
    (total, entry) => total + Number(entry.testSetupMethodCount ?? 0),
    0
  );
  const expectedSummaryMethodCount = tests.length + expectedSetupMethodCount;
  if (Number(summary.testsRan) !== expectedSummaryMethodCount) {
    throw new Error(
      `Apex test summary reports ${summary.testsRan} methods but contains ${tests.length} test results and the inventory declares ${expectedSetupMethodCount} TestSetup methods.`
    );
  }

  return {
    requestedClassCount: requestedByKey.size,
    executedClassCount: executed.size,
    executedMethodCount: tests.length,
    testSetupMethodCount: expectedSetupMethodCount,
    salesforceMethodCount: expectedSummaryMethodCount,
    testRunId: summary.testRunId,
    outcome: summary.outcome,
    orgWideCoverage: summary.orgWideCoverage,
    testRunCoverage: summary.testRunCoverage
  };
}
