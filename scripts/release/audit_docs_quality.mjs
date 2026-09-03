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
  if (relative === "docs/examples/account-check-builder-guide.md")
    return "Worked example";
  if (/docs\/examples\/[^/]+\/README\.md$/.test(relative))
    return "Evaluation Type examples home";
  if (relative === "docs/start-here/README.md") return "Task home";
  if (relative === "docs/developer-guides/integration-options.md")
    return "Integration home";
  if (relative === "docs/build-checks/README.md") return "Guides home";
  if (relative === "docs/reference/README.md")
    return "Technical reference home";
  if (
    /docs\/examples\/[^/]+\/[^/]+\.md$/.test(relative) &&
    !relative.endsWith("/README.md")
  )
    return "Worked example";
  if (
    /docs\/(?:reference\/evaluation\/(?:formula|query|compare-two-queries)|developer-guides\/write-an-apex-check)\.md$/.test(
      relative
    )
  )
    return "Evaluation reference";
  if (relative === "docs/reference/merge-syntax/README.md")
    return "Technical reference";
  if (
    /docs\/(?:flow-guides|save-results|developer-guides\/(?:async-apex|agentforce-and-mcp))\/README\.md$/.test(
      relative
    )
  )
    return "Integration area home";
  if (
    /docs\/reference\/(?:custom-metadata|platform-event-metadata)\/README\.md$/.test(
      relative
    )
  )
    return "Metadata area home";
  if (
    /docs\/(?:architecture(?:\/apex-implementation)?|quality-gates|reference\/(?:configuration|contracts|evaluation|platform|results))\/README\.md$/.test(
      relative
    )
  )
    return "Technical area home";
  if (
    /docs\/(?:contributing|developer-guides|faqs|lightning-record-page|production-operations)\/README\.md$/.test(
      relative
    )
  )
    return "Guide area home";
  if (
    /docs\/reference\/(?:contracts\/agent-tool-contract|architecture\/agentforce-and-mcp-threat-model)\.md$/.test(
      relative
    )
  )
    return "Technical reference";
  if (
    /docs\/(?:flow-guides|save-results|developer-guides\/(?:async-apex|agentforce-and-mcp))\//.test(
      relative
    ) ||
    /docs\/developer-guides\/(?:run-from-apex|receive-events-with-pub-sub)\.md$/.test(
      relative
    )
  )
    return "Integration reference";
  if (/docs\/start-here\/what-it-does\.md$/.test(relative))
    return "Concept guide";
  if (
    /docs\/(?:install\/install-demo-in-a-scratch-org|contributing\/source-development|step-by-step-guide\/create-your-first-check)\.md$/.test(
      relative
    )
  )
    return "Installation task";
  if (
    /docs\/start-here\/(?:choose-how-checks-run|choose-where-results-go|faq(?:\/.*)?)\.md$/.test(
      relative
    ) ||
    /docs\/step-by-step-guide\/README\.md$/.test(relative)
  )
    return relative.endsWith("/README.md") ? "Task home" : "Guide";
  if (/docs\/(?:start-here|install)\/README\.md$/.test(relative))
    return "Task home";
  if (/docs\/start-here\/when-to-use-record-health-check\.md$/.test(relative))
    return "Guide";
  if (/docs\/(?:start-here|install)\//.test(relative))
    return "Installation task";
  if (
    /docs\/reference\/(?:custom-metadata|platform-event-metadata)\//.test(
      relative
    )
  )
    return "Metadata reference";
  if (
    /docs\/(?:build-checks|production-operations|diagnostics|lightning-record-page)\//.test(
      relative
    )
  )
    return "Guide";
  if (/docs\/developer-guides\/verify-an-apex-check\.md$/.test(relative))
    return "Technical reference";
  if (/docs\/architecture(?:\/apex-implementation)?\//.test(relative))
    return "Technical reference";
  if (/docs\/quality-gates\/documentation-standard\.md$/.test(relative))
    return "Documentation standard";
  if (/docs\/quality-gates\//.test(relative)) return "Technical reference";
  if (/docs\/faqs\//.test(relative)) return "Guide";
  if (/docs\/reference\//.test(relative)) return "Technical reference";
  return "Documentation standard";
}

function hasAll(markdown, patterns) {
  return patterns.every((pattern) => pattern.test(markdown));
}

function areaHomeMatches(markdown, vocabulary) {
  const localLinkCount = [
    ...markdown.matchAll(/\[[^\]]+\]\((?!https?:|mailto:)[^)]+\)/g)
  ].length;
  return (
    vocabulary.test(markdown) &&
    localLinkCount >= 3 &&
    (/^\|.*\|$/m.test(markdown) || /^\d+\.\s+/m.test(markdown)) &&
    /^## Related$/m.test(markdown)
  );
}

function structureMatches(type, markdown) {
  switch (type) {
    case "Documentation home":
      return hasAll(markdown, [
        /^## New here\? Follow these steps$/m,
        /^## Pick your task$/m,
        /^## Choose how to build a Check$/m,
        /\| Folder \| Go here when you want to… \|/
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
        /\| Example \| Salesforce question \| (?:Distinct Framework technique|What .+ demonstrates) \|/,
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
        /^## Choose a reference area$/m,
        /^## Common lookups$/m,
        /\| Folder \| What you can find there \|/,
        /^## Related$/m
      ]);
    case "Integration area home":
      return areaHomeMatches(
        markdown,
        /Flow|Apex|Agentforce|MCP|integration|result|event/i
      );
    case "Metadata area home":
      return areaHomeMatches(
        markdown,
        /metadata|field|API name|Platform Event/i
      );
    case "Technical area home":
      return areaHomeMatches(
        markdown,
        /architecture|contract|configuration|evaluation|platform|quality|result|Apex/i
      );
    case "Guide area home":
      return areaHomeMatches(
        markdown,
        /guide|configure|developer|operation|troubleshoot|Lightning/i
      );
    case "Task home":
      return (
        /\b(use|choose|start|folder)\b/i.test(markdown) &&
        (/^\d+\.\s+/m.test(markdown) || /^\|.*\|$/m.test(markdown))
      );
    case "Worked example":
      return hasAll(markdown, [
        /^> On this page,/m,
        /^## Scenario$/m,
        /^## (?:Why use|Why this Evaluation Type)/m,
        /^## (?:Step \d+: )?Configure the Check$/m,
        /^## What the user sees$/m,
        /^## Security and access$/m,
        /^## (?:Step \d+: )?Test the Check$/m
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
        /read-only checklist|advisory guidance/i,
        /^## Terms to know$/m,
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
      "opening text is present",
      opening.replace(/^#.*$/m, "").trim().split(/\s+/).length >= 8
    ],
    [
      "opening contains a task or reference verb",
      /\b(use|learn|start|look up|configure|create|install|run|integrate|reference|describes?|explains?|shows?)\b/i.test(
        opening
      )
    ],
    ["expected section markers are present", structureMatches(type, markdown)],
    [
      "page contains a list, table, or code example",
      /^\d+\.\s+/m.test(markdown) ||
        /^\|.*\|$/m.test(markdown) ||
        /^```\w+/m.test(markdown) ||
        /^[-*]\s+/m.test(markdown)
    ],
    [
      "prose paragraphs are within the length limit",
      paragraphsAreReadable(markdown)
    ],
    ["table column counts are consistent", tablesAreReadable(markdown)],
    ["code fences identify their language", codeFencesHaveLanguages(markdown)],
    ["local links resolve", localLinksResolve(file, markdown)],
    [
      "related navigation appears near the end",
      file === path.join(docsRoot, "README.md") ||
        Boolean(
          navigation &&
          (type === "Task home" ||
            type.endsWith("area home") ||
            navigation.index >= markdown.length * 0.7)
        )
    ]
  ];
  return { relative, type, checks };
});

const failing = results.filter(({ checks }) =>
  checks.some(([, passed]) => !passed)
);
const report = [
  "# Documentation structure checks",
  "",
  `Checked **${results.length}** Markdown pages under \`docs/\`.`,
  "",
  "These automated checks inspect document structure, links, and formatting conventions. They do not establish technical accuracy, reader usefulness, completeness, or rendered layout. Editorial review and applicable walkthroughs remain separate requirements.",
  "",
  "| Page type | Page | Structural findings |",
  "| --- | --- | --- |",
  ...results.map(({ relative, type, checks }) => {
    const missed = checks.filter(([, passed]) => !passed).map(([name]) => name);
    return `| ${type} | [${relative}](../${relative}) | ${missed.length ? missed.join("; ") : "None"} |`;
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
  for (const { relative, checks } of failing) {
    const missed = checks
      .filter(([, passed]) => !passed)
      .map(([name]) => name)
      .join(", ");
    console.error(`${relative}: ${missed}`);
  }
  process.exit(1);
}

console.log(
  `Documentation structure checks passed for ${results.length} pages. Technical accuracy, usefulness, and rendered layout require separate review.`
);
