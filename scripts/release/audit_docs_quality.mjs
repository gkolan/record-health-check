#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const docsRoot = path.join(root, "docs");
const reportFile = path.join(root, "reports", "docs-quality-audit.md");
const checkOnly = process.argv.includes("--check");
const minimumStructuralScore = 9.8;
const files = [];

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === "site") continue;
      walk(entryPath);
    } else if (entry.name.endsWith(".md")) files.push(entryPath);
  }
}

function stripNonProse(markdown) {
  return markdown
    .replace(/```[\s\S]*?```/g, "")
    .replace(/^\s*\|.*\|\s*$/gm, "")
    .replace(/^>.*$/gm, "")
    .replace(/^#{1,6}\s+.*$/gm, "")
    .replace(/^\s*[-*]\s+.*$/gm, "")
    .replace(/^\s*\[[ xX]\]\s+.*$/gm, "")
    .replace(/^\s*\d+\.\s+.*$/gm, "");
}

function localLinksResolve(file, markdown) {
  for (const match of markdown.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
    const link = match[1].trim().replace(/^<|>$/g, "");
    if (/^(https?:|mailto:)/.test(link)) continue;
    const targetPart = link.split("#")[0];
    const target = path.resolve(
      path.dirname(file),
      decodeURIComponent(targetPart || path.basename(file))
    );
    if (!fs.existsSync(target)) return false;
  }
  return true;
}

function tablesAreReadable(markdown) {
  const columnCount = (row) =>
    row.replaceAll("&#124;", "").replaceAll("\\|", "").split("|").slice(1, -1)
      .length;
  const lines = markdown.split(/\r?\n/);
  for (let index = 0; index < lines.length - 1; index += 1) {
    if (
      !/^\|.*\|$/.test(lines[index]) ||
      !/^\|[ :|-]+\|$/.test(lines[index + 1])
    ) {
      continue;
    }
    const columns = columnCount(lines[index]);
    if (columns > 6) return false;
    let row = index + 2;
    while (row < lines.length && /^\|.*\|$/.test(lines[row])) {
      if (columnCount(lines[row]) !== columns) return false;
      row += 1;
    }
  }
  return true;
}

function codeFencesHaveLanguages(markdown) {
  let insideFence = false;
  for (const line of markdown.split(/\r?\n/)) {
    if (!line.startsWith("```")) continue;
    if (!insideFence && !/^```[A-Za-z0-9_-]+\s*$/.test(line)) return false;
    insideFence = !insideFence;
  }
  return !insideFence;
}

function topLevelTitleCount(markdown) {
  let insideFence = false;
  let count = 0;
  for (const line of markdown.split(/\r?\n/)) {
    if (line.startsWith("```")) {
      insideFence = !insideFence;
      continue;
    }
    if (!insideFence && /^#\s+.+$/.test(line)) count += 1;
  }
  return count;
}

function classify(relative) {
  if (relative === "docs/README.md") return "Documentation home";
  if (relative === "docs/examples/README.md") return "Examples home";
  if (/docs\/examples\/[^/]+\/README\.md$/.test(relative))
    return "Evaluation Type examples home";
  if (relative === "docs/installation/README.md") return "Installation home";
  if (relative === "docs/integration/README.md") return "Integration home";
  if (relative === "docs/guides/README.md") return "Guides home";
  if (relative === "docs/reference/README.md")
    return "Technical reference home";
  if (/docs\/examples\/[^/]+\/\d[^/]+\.md$/.test(relative))
    return "Worked example";
  if (
    /docs\/reference\/evaluation\/(?:formula|query|compare-two-queries|apex-rule-contract)\.md$/.test(
      relative
    )
  )
    return "Evaluation reference";
  if (/docs\/(?:api|platform-events)\//.test(relative))
    return "Integration reference";
  if (/docs\/installation\/01-how-it-works\.md$/.test(relative))
    return "Concept guide";
  if (/docs\/installation\//.test(relative)) return "Installation task";
  if (/docs\/integration\/apex-api\/README\.md$/.test(relative))
    return "Navigation page";
  if (
    /docs\/(?:integration|flow|lwc)\//.test(relative) ||
    /lifecycle-events\.md$/.test(relative)
  )
    return "Integration reference";
  if (/docs\/metadata\//.test(relative)) return "Metadata reference";
  if (/docs\/guides\//.test(relative)) return "Guide";
  if (/docs\/reference\//.test(relative)) return "Technical reference";
  return "Documentation standard";
}

function hasAll(markdown, patterns) {
  return patterns.every((pattern) => pattern.test(markdown));
}

function structureMatches(type, markdown) {
  switch (type) {
    case "Documentation home":
      return hasAll(markdown, [
        /^## What do you want to do\?$/m,
        /^## Recommended path for new users$/m,
        /^## Learn by example$/m,
        /\| I want to… \| Start here \| What you will learn \|/
      ]);
    case "Examples home":
      return hasAll(markdown, [
        /^## Choose the right Evaluation Type$/m,
        /^## How to use an example$/m,
        /^## Formula examples$/m,
        /^## Query examples$/m,
        /^## Compare-two-queries examples$/m,
        /^## Apex examples$/m,
        /\| Example \| What it checks \| What you will learn \|/
      ]);
    case "Evaluation Type examples home":
      return hasAll(markdown, [
        /^## Choose .+ example$/m,
        /^## When .+ (?:is|are) the right choice$/m,
        /\| Example \| Salesforce question \| Distinct Framework technique \|/,
        /^## Related$/m
      ]);
    case "Installation home":
      return hasAll(markdown, [
        /^## Choose your path$/m,
        /^## New installation sequence$/m,
        /^## (?:Upgrade|Existing-installation) sequence$/m,
        /\| Your starting point \| Follow this path \| What you will accomplish \|/,
        /^## Next steps$/m
      ]);
    case "Integration home":
      return hasAll(markdown, [
        /^## Choose an integration$/m,
        /^## Compare integration outputs$/m,
        /\| Goal \| Start here \| What you will learn \|/,
        /^## Next steps$/m
      ]);
    case "Guides home":
      return hasAll(markdown, [
        /^## Recommended path$/m,
        /^## Pick a task$/m,
        /\| I want to… \| Guide \|/,
        /^## Related$/m
      ]);
    case "Technical reference home":
      return hasAll(markdown, [
        /^## Recommended path/m,
        /^## Evaluation Types$/m,
        /^## Contracts$/m,
        /\| Step \| Reference \| What it provides \|/,
        /^## Related$/m
      ]);
    case "Worked example":
      return hasAll(markdown, [
        /^> On this page,/m,
        /^## Scenario$/m,
        /^## (?:Why use|Why this Evaluation Type)/m,
        /^## (?:Step \d+: )?Configure the Rule$/m,
        /^## What the user sees$/m,
        /^## Security and access$/m,
        /^## (?:Step \d+: )?Test the Rule$/m
      ]);
    case "Evaluation reference":
      return hasAll(markdown, [
        /^> On this page,/m,
        /security|access/i,
        /Outcome|Reason code|Failure/,
        /Compatibility|deprecation|Version/i,
        /^## (?:Related|See also)$/m
      ]);
    case "Concept guide":
      return hasAll(markdown, [
        /^## The plain-English model$/m,
        /^## The words you need$/m,
        /^## Example:/m,
        /troubleshooting/i,
        /^## Next steps$/m
      ]);
    case "Installation task":
      return hasAll(markdown, [
        /prerequisite|before (?:you start|the upgrade)|you need/i,
        /^## (?:Step |\d+\.|Upgrade procedure|Verification)/m,
        /verify|verification|confirm|expected result|test both results/i,
        /fails|troubleshoot|rollback|does not work/i,
        /^## Next steps$/m
      ]);
    case "Integration reference":
      return hasAll(markdown, [
        /quick start|quick examples|basic .* pattern|choose an integration|choose an api|choose a platform event|subscribe|example/i,
        /access|running user|permission/i,
        /limit|bulk|transaction/i,
        /status|outcome|failure|fault|error/i,
        /^## (?:Related|Next steps|See also)$/m
      ]);
    case "Navigation page":
      return (
        /(?:folder landing page|retained as a navigation page)/i.test(
          markdown
        ) &&
        /\| Integration surface \| Documentation \|/.test(markdown) &&
        /^## Related$/m.test(markdown)
      );
    case "Metadata reference":
      return (
        /API name|Field|Stored maximum/.test(markdown) &&
        /^## (?:Related|See also)$/m.test(markdown)
      );
    case "Guide":
      return (
        /\b(use|configure|choose|turn on|deploy|review)\b/i.test(markdown) &&
        (/example|step|checklist|pattern/i.test(markdown) ||
          /^\|.*\|$/m.test(markdown)) &&
        /^## (?:Related|Next steps|See also)$/m.test(markdown)
      );
    case "Technical reference":
      return (
        /^##\s+.+$/m.test(markdown) &&
        /limit|behavior|mapping|responsibilit|reason|design|migration/i.test(
          markdown
        ) &&
        /^## (?:Related|Related guides|See also)$/m.test(markdown)
      );
    default:
      return (
        /standard|checklist|requirement/i.test(markdown) &&
        /^## Related$/m.test(markdown)
      );
  }
}

function paragraphsAreReadable(markdown) {
  const prose = stripNonProse(markdown);
  return prose
    .split(/\n\s*\n/)
    .map((paragraph) => paragraph.replace(/\s+/g, " ").trim())
    .filter(Boolean)
    .every((paragraph) => paragraph.split(/\s+/).length <= 120);
}

walk(docsRoot);

const results = files.sort().map((file) => {
  const markdown = fs.readFileSync(file, "utf8");
  const relative = path.relative(root, file);
  const type = classify(relative);
  const opening = markdown.split(/^##\s+/m, 1)[0];
  const navigation = [
    ...markdown.matchAll(
      /^## (Related|Related documentation|Related guides|Next steps|See also)$/gm
    )
  ].at(-1);
  const checks = [
    ["one clear page title", topLevelTitleCount(markdown) === 1],
    [
      "reader-oriented opening",
      opening.replace(/^#.*$/m, "").trim().split(/\s+/).length >= 8
    ],
    [
      "purpose or outcome is explicit",
      /\b(use|learn|start|look up|configure|create|install|run|integrate|reference|describes?|explains?|shows?)\b/i.test(
        opening
      )
    ],
    [
      "information architecture matches the page purpose",
      structureMatches(type, markdown)
    ],
    [
      "page provides an actionable aid",
      /^\d+\.\s+/m.test(markdown) ||
        /^\|.*\|$/m.test(markdown) ||
        /^```\w+/m.test(markdown) ||
        /^[-*]\s+/m.test(markdown)
    ],
    ["paragraphs are concise", paragraphsAreReadable(markdown)],
    ["tables are structurally readable", tablesAreReadable(markdown)],
    ["code fences identify their language", codeFencesHaveLanguages(markdown)],
    ["local links resolve", localLinksResolve(file, markdown)],
    [
      "final navigation is easy to find",
      file === path.join(docsRoot, "README.md") ||
        Boolean(navigation && navigation.index >= markdown.length * 0.7)
    ]
  ];
  const score = checks.filter(([, passed]) => passed).length;
  return { relative, type, score, checks };
});

const failing = results.filter(({ score }) => score < minimumStructuralScore);
const average =
  results.reduce((sum, result) => sum + result.score, 0) / results.length;
const report = [
  "# Documentation structural-readiness audit",
  "",
  `Audited **${results.length}** Markdown pages under \`docs/\`. The structural threshold is **${minimumStructuralScore}/10** and the current average is **${average.toFixed(2)}/10**.`,
  "",
  "This automated score measures structural readiness only. It cannot score voice, usefulness, narrative quality, technical judgment, or the single-link experience, and it never replaces a human editorial review. Each page earns one point for: a clear title, a reader-oriented opening, an explicit purpose, page-type-specific information architecture, an actionable aid, concise paragraphs, readable tables, labeled code fences, valid local links, and final navigation.",
  "",
  "| Score | Page type | Page | Result |",
  "| ---: | --- | --- | --- |",
  ...results.map(({ relative, type, score, checks }) => {
    const missed = checks.filter(([, passed]) => !passed).map(([name]) => name);
    return `| ${score.toFixed(1)}/10 | ${type} | [${relative}](../${relative}) | ${missed.length ? `Improve: ${missed.join("; ")}` : "Pass"} |`;
  }),
  ""
].join("\n");

if (checkOnly) {
  // Validate the current documentation directly. Generated reports are local-only
  // evidence and are not required in a clean checkout or continuous integration.
} else {
  fs.mkdirSync(path.dirname(reportFile), { recursive: true });
  fs.writeFileSync(reportFile, report);
}

if (failing.length) {
  for (const { relative, score, checks } of failing) {
    const missed = checks
      .filter(([, passed]) => !passed)
      .map(([name]) => name)
      .join(", ");
    console.error(`${relative}: ${score}/10 — ${missed}`);
  }
  process.exit(1);
}

console.log(
  `Documentation structural-readiness audit passed: ${results.length} pages, ${average.toFixed(2)}/10 average, minimum ${minimumStructuralScore}/10.`
);
