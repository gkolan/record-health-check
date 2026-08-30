#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const docsRoot = path.join(root, "docs");
const markdownFiles = [];
const narrativeHeaders = /^(notes?|description|purpose|detail)$/i;
const apiName = /\b[A-Za-z][A-Za-z0-9_]*__(?:c|mdt|e)\b/g;
const plainLanguageAvoidList = [
  "payload",
  "short-circuit",
  "idempotent",
  "sentinel",
  "headroom",
  "allowlist",
  "allowlisted",
  "verbatim",
  "lockstep",
  "canonical",
  "authoritative",
  "opt-in",
  "well-formed",
  "fail-fast",
  "buffered",
  "transaction-scoped",
  "package surface",
  "integration surface",
  "fluent builder",
  "result shell",
  "row cap",
  "request caps",
  "invocation",
  "population"
];

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === "site") continue;
      walk(entryPath);
    } else if (entry.name.endsWith(".md")) markdownFiles.push(entryPath);
  }
}

function slug(heading) {
  return heading
    .toLowerCase()
    .trim()
    .replace(/<[^>]*>/g, "")
    .replace(/[`*~]/g, "")
    .replace(/\s+/g, "-")
    .replace(/[^\p{L}\p{N}_-]/gu, "");
}

function headings(markdown) {
  return new Set(
    [...markdown.matchAll(/^#{1,6}\s+(.+)$/gm)].map((match) => slug(match[1]))
  );
}

function splitTableRow(row) {
  const escapedPipe = "\u0000RHC_ESCAPED_PIPE\u0000";
  return row
    .replaceAll("&#124;", escapedPipe)
    .replaceAll("\\|", escapedPipe)
    .split("|")
    .slice(1, -1)
    .map((cell) => cell.replaceAll(escapedPipe, "|").trim());
}

walk(docsRoot);
const failures = [];
for (const file of markdownFiles) {
  if (/^\d{2}-/.test(path.basename(file))) {
    failures.push(
      `${path.relative(root, file)}: public documentation filenames must use stable unnumbered slugs`
    );
  }
}
const projectMarkdownFiles = [
  ...markdownFiles,
  ...fs
    .readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
    .map((entry) => path.join(root, entry.name))
];
const supplementalDocumentationFiles = [
  path.join(root, ".github/CONTRIBUTING.md"),
  path.join(root, ".github/ISSUE_TEMPLATE/bug_report.yml"),
  path.join(root, "packages/record-health-check-mcp/README.md"),
  path.join(root, "packages/record-health-check/integration-tests/README.md")
];

const documentationContractSources = [
  ...projectMarkdownFiles,
  ...supplementalDocumentationFiles
];
for (const file of documentationContractSources) {
  const source = fs.readFileSync(file, "utf8");
  const relativeFile = path.relative(root, file);
  for (const [obsolete, replacement] of [
    [
      "docs/guides/troubleshoot-with-show-diagnostics.md",
      "docs/diagnostics/browser-console.md"
    ],
    ["rhc__Account_Data_Quality", "rhc__Example_Account_Check_Builder_Guide"],
    ["VALUE_MISSING", "VALUE_IS_EMPTY"],
    ["retained for compatibility", "the exact day-one contract meaning"],
    ["retained for existing plugins", "the exact day-one contract meaning"],
    ["legacy DeveloperName", "unqualified DeveloperName"]
  ]) {
    if (source.includes(obsolete)) {
      failures.push(
        `${relativeFile}: replace obsolete documentation value ${obsolete} with ${replacement}`
      );
    }
  }
}

const packagedMetadataIdentities = new Set();
for (const directory of [
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/customMetadata"
  )
]) {
  for (const name of fs.readdirSync(directory)) {
    const developerName = name.match(
      /^Record_Health_Check(?:_Set)?\.([^.]+)\.md-meta\.xml$/
    )?.[1];
    if (developerName) packagedMetadataIdentities.add(`rhc__${developerName}`);
  }
}
for (const file of documentationContractSources) {
  const source = fs.readFileSync(file, "utf8");
  for (const match of source.matchAll(/\brhc__Example_[A-Za-z0-9_]+\b/g)) {
    if (!packagedMetadataIdentities.has(match[0])) {
      failures.push(
        `${path.relative(root, file)}: ${match[0]} is not shipped package metadata`
      );
    }
  }
}

const permissionSetDirectory = path.join(
  root,
  "packages/record-health-check/force-app/main/default/permissionsets"
);
const permissionSetCount = fs
  .readdirSync(permissionSetDirectory)
  .filter((name) => name.endsWith(".permissionset-meta.xml")).length;
const countWords = [
  "Zero",
  "One",
  "Two",
  "Three",
  "Four",
  "Five",
  "Six",
  "Seven",
  "Eight",
  "Nine",
  "Ten"
];
const frameworkDocumentation = fs.readFileSync(
  path.join(docsRoot, "architecture/framework.md"),
  "utf8"
);
if (
  !frameworkDocumentation.includes(
    `${countWords[permissionSetCount] || permissionSetCount} Permission Sets`
  )
) {
  failures.push(
    `docs/architecture/framework.md: permission-set inventory must report ${permissionSetCount}`
  );
}

const reasonCodeSource = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckReasonCodes.cls"
  ),
  "utf8"
);
const reasonCodeReference = fs.readFileSync(
  path.join(docsRoot, "reference/results/reason-codes.md"),
  "utf8"
);
const restApiReference = fs.readFileSync(
  path.join(
    docsRoot,
    "developer-guides/agentforce-and-mcp/agent-tool-rest-api.md"
  ),
  "utf8"
);
for (const match of restApiReference.matchAll(
  /"reasonCode":\s*"([A-Z0-9_]+)"/g
)) {
  if (!reasonCodeSource.includes(`= '${match[1]}'`)) {
    failures.push(
      `docs/developer-guides/agentforce-and-mcp/agent-tool-rest-api.md: sample reason code ${match[1]} is not a runtime constant`
    );
  }
}
for (const match of reasonCodeSource.matchAll(
  /public static final String ([A-Z0-9_]+)\s*=/g
)) {
  if (!reasonCodeReference.includes(`\`${match[1]}\``)) {
    failures.push(
      `docs/reference/results/reason-codes.md: missing runtime reason code ${match[1]}`
    );
  }
}

for (const relativeFile of [
  "packages/record-health-check-mcp/README.md",
  "docs/developer-guides/agentforce-and-mcp/agent-tool-rest-api.md",
  "docs/developer-guides/agentforce-and-mcp/deploy-mcp-service.md"
]) {
  const source = fs.readFileSync(path.join(root, relativeFile), "utf8");
  if (!source.includes("Record Health Check MCP Integration")) {
    failures.push(
      `${relativeFile}: dedicated MCP access must name Record Health Check MCP Integration`
    );
  }
}

// The README framework snapshot is intentionally concise, but its inventory
// values must remain derived from the shipped source. Structural and link
// checks cannot otherwise detect a plausible-looking stale count.
const readme = fs.readFileSync(path.join(root, "README.md"), "utf8");
const apexClassFiles = fs
  .readdirSync(
    path.join(
      root,
      "packages/record-health-check/force-app/main/default/classes"
    )
  )
  .filter((name) => name.endsWith(".cls"));
const apexTestClassCount = apexClassFiles.filter((name) => {
  const source = fs.readFileSync(
    path.join(
      root,
      "packages/record-health-check/force-app/main/default/classes",
      name
    ),
    "utf8"
  );
  return name.endsWith("Test.cls") || /@IsTest\b/i.test(source);
}).length;
const customMetadataFieldCount = (objectName) =>
  fs
    .readdirSync(
      path.join(
        root,
        "packages/record-health-check/force-app/main/default/objects",
        objectName,
        "fields"
      )
    )
    .filter((name) => name.endsWith(".field-meta.xml")).length;
const practicalExampleCount = [
  "formula",
  "query",
  "compare-two-queries",
  "apex"
].reduce(
  (count, folder) =>
    count +
    fs
      .readdirSync(path.join(docsRoot, "examples", folder))
      .filter((name) => name.endsWith(".md") && name !== "README.md").length,
  0
);
const expectedSnapshotClaims = [
  `${apexClassFiles.length} classes, including ${apexTestClassCount} test classes`,
  `Record Health Check Set (${customMetadataFieldCount("Record_Health_Check_Set__mdt")} fields) and Record Health Check (${customMetadataFieldCount("Record_Health_Check__mdt")} fields)`,
  `${markdownFiles.length} maintained pages, including ${practicalExampleCount} documented Check examples`
];
for (const claim of expectedSnapshotClaims) {
  if (!readme.includes(claim)) {
    failures.push(
      `README.md: stale or missing framework snapshot claim: ${claim}`
    );
  }
}

for (const file of projectMarkdownFiles) {
  const markdown = fs.readFileSync(file, "utf8");
  const relativeFile = path.relative(root, file);
  if (
    markdown.includes("```mermaid") &&
    !/Text fallback:|^## Reading the diagram$/m.test(markdown)
  ) {
    failures.push(
      `${relativeFile}: Mermaid diagrams require an adjacent text or table fallback`
    );
  }
  if (markdown.includes("—")) {
    failures.push(
      `${path.relative(root, file)}: replace em dashes with natural sentence punctuation`
    );
  }
  if (file.startsWith(`${docsRoot}${path.sep}`)) {
    // Lead with bare tokens (`{!record.Name}`); fallback is optional. Require at
    // least one fallback example on any page that shows merge tokens, so readers
    // still see the quoted fallback attribute without repeating it on every tag.
    let countedMergeToken = false;
    let countedFallbackToken = false;
    for (const match of markdown.matchAll(/\{!([^}\n]+)\}/g)) {
      const body = match[1];
      const lineStart = markdown.lastIndexOf("\n", match.index) + 1;
      const lineEnd = markdown.indexOf("\n", match.index);
      const nextLineEnd = markdown.indexOf(
        "\n",
        lineEnd === -1 ? markdown.length : lineEnd + 1
      );
      let lookbackStart = lineStart;
      for (let i = 0; i < 8; i += 1) {
        if (lookbackStart <= 0) {
          lookbackStart = 0;
          break;
        }
        lookbackStart =
          markdown.lastIndexOf("\n", Math.max(0, lookbackStart - 2)) + 1;
      }
      const exampleContext = markdown.slice(
        lookbackStart,
        nextLineEnd === -1 ? markdown.length : nextLineEnd
      );
      // Intentionally rejected examples such as `{!Id}` are not teaching tokens.
      if (exampleContext.includes("rejected-token-fixture")) continue;
      countedMergeToken = true;
      if (/\bfallback\s*=\s*"/.test(body)) {
        countedFallbackToken = true;
      }
    }
    if (countedMergeToken && !countedFallbackToken) {
      failures.push(
        `${relativeFile}: pages with merge tokens must include at least one fallback example`
      );
    }
  }
  const isFieldReference = [
    path.join(docsRoot, "reference/custom-metadata/check-fields.md"),
    path.join(docsRoot, "reference/custom-metadata/check-set-fields.md"),
    path.join(docsRoot, "reference/platform-event-metadata/check-result.md"),
    path.join(docsRoot, "reference/platform-event-metadata/error-log.md"),
    path.join(docsRoot, "reference/platform-event-metadata/check-set-run.md")
  ].includes(file);
  const isPlainLanguageSource =
    file.startsWith(`${docsRoot}${path.sep}`) && !isFieldReference;
  if (isPlainLanguageSource) {
    for (const avoided of plainLanguageAvoidList) {
      const pattern = new RegExp(
        `\\b${avoided.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replaceAll("-", "[- ]")}\\b`,
        "i"
      );
      if (pattern.test(markdown)) {
        failures.push(
          `${relativeFile}: replace plain-language avoid-list term "${avoided}"`
        );
      }
    }
  }
}

const canonicalFieldAnchors = new Map();
for (const reference of [
  path.join(docsRoot, "reference/custom-metadata/check-fields.md"),
  path.join(docsRoot, "reference/custom-metadata/check-set-fields.md")
]) {
  const markdown = fs.readFileSync(reference, "utf8");
  for (const match of markdown.matchAll(/^###\s+.+\s+\(`([^`]+)`\)$/gm)) {
    canonicalFieldAnchors.set(
      `${reference}:${match[1]}`,
      slug(match[0].replace(/^###\s+/, ""))
    );
  }
}

for (const folder of ["formula", "query", "compare-two-queries", "apex"]) {
  const examplesDirectory = path.join(docsRoot, "examples", folder);
  const reference =
    folder === "apex"
      ? path.join(docsRoot, "developer-guides/write-an-apex-check.md")
      : path.join(
          docsRoot,
          "reference",
          "evaluation",
          folder === "formula"
            ? "formula.md"
            : folder === "query"
              ? "query.md"
              : "compare-two-queries.md"
        );
  if (!fs.existsSync(reference))
    failures.push(`missing ${folder} reference page`);

  const practicalExamples = fs
    .readdirSync(examplesDirectory)
    .filter((name) => name !== "README.md" && name.endsWith(".md"));
  if (practicalExamples.length === 0)
    failures.push(`missing ${folder} practical example`);
}

for (const [objectName, referenceName] of [
  ["Record_Health_Check__mdt", "check-fields.md"],
  ["Record_Health_Check_Set__mdt", "check-set-fields.md"]
]) {
  const reference = path.join(
    docsRoot,
    "reference",
    "custom-metadata",
    referenceName
  );
  const fieldsDirectory = path.join(
    root,
    "packages/record-health-check/force-app/main/default/objects",
    objectName,
    "fields"
  );
  for (const fieldFile of fs.readdirSync(fieldsDirectory)) {
    if (!fieldFile.endsWith(".field-meta.xml")) continue;
    const api = fieldFile.replace(/\.field-meta\.xml$/, "");
    if (!canonicalFieldAnchors.has(`${reference}:${api}`))
      failures.push(`${referenceName}: missing shipped field ${api}`);
  }
}

for (const [eventName, referenceName] of [
  ["Record_Health_Check_Set_Run__e", "check-set-run.md"],
  ["Record_Health_Check_Result__e", "check-result.md"],
  ["Record_Health_Check_Log__e", "error-log.md"]
]) {
  const eventReference = fs.readFileSync(
    path.join(docsRoot, "reference", "platform-event-metadata", referenceName),
    "utf8"
  );
  const fieldsDirectory = path.join(
    root,
    "packages/record-health-check/force-app/main/default/objects",
    eventName,
    "fields"
  );
  for (const fieldFile of fs.readdirSync(fieldsDirectory)) {
    if (!fieldFile.endsWith(".field-meta.xml")) continue;
    const api = fieldFile.replace(/\.field-meta\.xml$/, "");
    if (!eventReference.includes(`\`${api}\``))
      failures.push(`${referenceName}: missing shipped event field ${api}`);
  }
}

// Every production Apex class must have a real class entry in the Apex
// reference, not merely appear in an index or a related class's prose. This
// catches both newly shipped classes and entries accidentally reduced to a
// name-only mention during documentation maintenance.
const apexClassesDirectory = path.join(
  root,
  "packages/record-health-check/force-app/main/default/classes"
);
const productionApexClasses = fs
  .readdirSync(apexClassesDirectory)
  .filter((name) => {
    if (
      !name.endsWith(".cls") ||
      name.endsWith("Test.cls") ||
      name.includes("Coverage") ||
      name === "RecordHealthCheckTestDataFactory.cls"
    ) {
      return false;
    }
    const source = fs.readFileSync(
      path.join(apexClassesDirectory, name),
      "utf8"
    );
    return !/@IsTest\b/i.test(source);
  })
  .map((name) => name.replace(/\.cls$/, ""));
const apexReferenceDirectory = path.join(
  docsRoot,
  "architecture",
  "apex-implementation"
);
const apexReferenceHeadings = fs
  .readdirSync(apexReferenceDirectory)
  .filter((name) => name.endsWith(".md"))
  .flatMap((name) =>
    fs
      .readFileSync(path.join(apexReferenceDirectory, name), "utf8")
      .split("\n")
      .filter((line) => line.startsWith("### "))
  );
for (const apexClass of productionApexClasses) {
  if (
    !apexReferenceHeadings.some((heading) =>
      heading.includes(`\`${apexClass}\``)
    )
  ) {
    failures.push(
      `architecture/apex-implementation/: missing detailed production Apex class entry ${apexClass}`
    );
  }
}

for (const file of markdownFiles) {
  const markdown = fs.readFileSync(file, "utf8");
  const relativeFile = path.relative(root, file);
  const isPracticalExample =
    /^docs\/examples\/[^/]+\/[^/]+\.md$/.test(relativeFile) &&
    !relativeFile.endsWith("/README.md");

  const openingAfterTitle = markdown
    .replace(/^# .+\n+/, "")
    .split(/^##\s/m, 1)[0]
    .trim();
  const hasOnThisPageNote = /^> \[!NOTE\]\n> On this page,/.test(
    openingAfterTitle
  );
  const openingWordCount = openingAfterTitle
    .replace(/[`*_>#\[\]()]/g, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean).length;
  if (!hasOnThisPageNote && openingWordCount < 12) {
    failures.push(
      `${relativeFile}: page must begin with a substantive introduction or an On this page note`
    );
  }

  if (isPracticalExample) {
    const opening = markdown.split(/^##\s/m, 1)[0];
    if (
      !/> \[!NOTE\]/.test(opening) ||
      !/> On this page,/.test(opening) ||
      !/> \*\*Setup reference\*\*/.test(opening)
    ) {
      failures.push(
        `${relativeFile}: example must open with On this page and Setup reference`
      );
    }

    const userResultSection = markdown
      .split(/^## What the user sees\s*$/m)[1]
      ?.split(/^## /m)[0];
    for (const requiredRow of [
      "| **`PASS`** |",
      "| **`FAIL`** |",
      "| **`SKIPPED`** |",
      "| **Found** |",
      "| **Expected** |"
    ]) {
      if (!userResultSection?.includes(requiredRow)) {
        failures.push(
          `${relativeFile}: What the user sees must include ${requiredRow.replaceAll("|", "").trim()}`
        );
      }
    }
  }

  if (
    /reference\/custom-metadata\/(check-fields|check-set-fields)\.md$/.test(
      file
    )
  ) {
    const sections = markdown.split(/^###\s+/m).slice(1);
    for (const section of sections) {
      const heading = section.split(/\r?\n/, 1)[0];
      const api = heading.match(/\(`([^`]+)`\)$/)?.[1];
      if (!api && heading !== "Label and Developer Name") {
        failures.push(`${relativeFile}: ${heading} missing API name`);
      }
      const fieldWordCount = section
        .replace(/```[\s\S]*?```/g, "")
        .replace(/[`*_>#\[\]()]/g, " ")
        .trim()
        .split(/\s+/)
        .filter(Boolean).length;
      if (fieldWordCount < 12) {
        failures.push(
          `${relativeFile}: ${heading} needs substantive field guidance`
        );
      }
      if (
        !/\b(?:required|optional|default|select|choose|enter|use|leave|clear|controls?|identifies?|stores?|shows?|publishes?)\b/i.test(
          section
        )
      ) {
        failures.push(
          `${relativeFile}: ${heading} needs usage or default guidance`
        );
      }
    }
  }

  if (file !== path.join(docsRoot, "README.md")) {
    const hasNavigation =
      /^## (Related|Related documentation|Related guides|Next steps|See also)$/m.test(
        markdown
      );
    if (!hasNavigation)
      failures.push(`${relativeFile}: missing final navigation section`);
  }

  const lines = markdown.split(/\r?\n/);
  let inCodeFence = false;
  for (let index = 0; index < lines.length - 1; index += 1) {
    if (/^```/.test(lines[index])) {
      inCodeFence = !inCodeFence;
      continue;
    }
    if (!inCodeFence && /^#{2,6} .*: [a-z]/.test(lines[index])) {
      failures.push(
        `${relativeFile}:${index + 1}: capitalize the first word after a heading colon`
      );
    }
    if (
      !/^\|.*\|$/.test(lines[index]) ||
      !/^\|[ :|-]+\|$/.test(lines[index + 1])
    ) {
      continue;
    }
    const headers = splitTableRow(lines[index]);

    const exampleApiColumn =
      headers[0] === "Setup field" && headers[1] === "API name" ? 1 : -1;
    if (headers.length > 6) {
      failures.push(
        `${relativeFile}:${index + 1}: table has more than six columns`
      );
    }
    const narrativeIndex = headers.findIndex((header) =>
      narrativeHeaders.test(header)
    );
    if (narrativeIndex !== -1 && narrativeIndex !== headers.length - 1) {
      failures.push(
        `${relativeFile}:${index + 1}: explanatory column must be last`
      );
    }

    let rowIndex = index + 2;
    while (rowIndex < lines.length && /^\|.*\|$/.test(lines[rowIndex])) {
      const cells = splitTableRow(lines[rowIndex]);
      if (exampleApiColumn !== -1) {
        const cell = cells[exampleApiColumn] || "";
        const api = cell.match(/`([^`]+)`/)?.[1];
        const link = cell.match(/\]\(([^)]+)\)/)?.[1];
        const [targetPart, anchor] = (link || "").split("#");
        const target = targetPart
          ? path.resolve(path.dirname(file), targetPart)
          : "";
        const canonical = api
          ? canonicalFieldAnchors.get(`${target}:${api}`)
          : null;
        if (!api || !link || !canonical) {
          failures.push(
            `${relativeFile}:${rowIndex + 1}: example API name must link to its canonical field section`
          );
        } else {
          if (anchor !== canonical) {
            failures.push(
              `${relativeFile}:${rowIndex + 1}: ${api} must link to #${canonical}`
            );
          }
        }
      }
      for (const cell of cells) {
        const visibleCell = cell.replace(/\]\([^)]+\)/g, "]");
        for (const match of visibleCell.matchAll(apiName)) {
          const before = visibleCell.slice(0, match.index);
          const isInsideCode = (before.match(/`/g) || []).length % 2 === 1;
          if (!isInsideCode) {
            failures.push(
              `${relativeFile}:${rowIndex + 1}: API name ${match[0]} must use backticks`
            );
          }
        }
      }
      rowIndex += 1;
    }
    index = rowIndex - 1;
  }

  for (const match of markdown.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
    const link = match[1];
    if (/^(https?:|mailto:)/.test(link)) continue;
    const [relativeTarget, anchor] = link.split("#");
    const target = path.resolve(
      path.dirname(file),
      relativeTarget || path.basename(file)
    );
    if (!fs.existsSync(target)) {
      failures.push(`${relativeFile}: missing local target ${link}`);
      continue;
    }
    if (anchor && target.endsWith(".md")) {
      const targetHeadings = headings(fs.readFileSync(target, "utf8"));
      if (!targetHeadings.has(anchor.toLowerCase())) {
        failures.push(`${relativeFile}: missing heading anchor ${link}`);
      }
    }
  }
}

for (const file of supplementalDocumentationFiles.filter((candidate) =>
  candidate.endsWith(".md")
)) {
  const markdown = fs.readFileSync(file, "utf8");
  const relativeFile = path.relative(root, file);
  for (const match of markdown.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
    const link = match[1];
    if (/^(https?:|mailto:)/.test(link)) continue;
    const [relativeTarget, anchor] = link.split("#");
    const target = path.resolve(
      path.dirname(file),
      relativeTarget || path.basename(file)
    );
    if (!fs.existsSync(target)) {
      failures.push(`${relativeFile}: missing local target ${link}`);
      continue;
    }
    if (anchor && target.endsWith(".md")) {
      const targetHeadings = headings(fs.readFileSync(target, "utf8"));
      if (!targetHeadings.has(anchor.toLowerCase())) {
        failures.push(`${relativeFile}: missing heading anchor ${link}`);
      }
    }
  }
}

for (const file of supplementalDocumentationFiles) {
  const source = fs.readFileSync(file, "utf8");
  for (const match of source.matchAll(
    /https:\/\/github\.com\/gkolan\/record-health-check\/blob\/main\/([^\s)]+)/g
  )) {
    const target = path.join(root, decodeURIComponent(match[1]));
    if (!fs.existsSync(target)) {
      failures.push(
        `${path.relative(root, file)}: missing repository target ${match[0]}`
      );
    }
  }
}

if (failures.length > 0) {
  process.stderr.write(`${failures.join("\n")}\n`);
  process.exit(1);
}

process.stdout.write(
  `Verified ${markdownFiles.length} Markdown files: tables, local targets, heading anchors, and navigation.\n`
);
