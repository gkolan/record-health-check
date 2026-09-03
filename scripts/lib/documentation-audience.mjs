// Catch recognizable internal review material in reader-facing documentation.
// This is a narrow regression check, not a substitute for editorial review.
export function documentationAudienceIssues(relativePath, markdown) {
  const file = relativePath.replaceAll("\\", "/");
  const maintainerPage =
    /^docs\/(?:contributing|quality-gates|architecture)\//.test(file) ||
    /^(?:\.github\/|AGENTS\.md$|PUBLISHING\.md$)/.test(file) ||
    file.startsWith("packages/record-health-check/integration-tests/");
  if (maintainerPage) return [];

  const visible = markdown.replace(/<!--[\s\S]*?-->/g, "");
  const rules = [
    [
      "internal quality scoring",
      /\bquality[\s-]+(?:gates?|scores?)\b|\bunderstandability\b|\blogic\s+depth\b|\|\s*(?:total|quality)\s*\/\s*(?:10|30)\s*\|/i
    ],
    [
      "editorial review instructions",
      /\bhuman[\s-]+review\s+specification\b|^#{1,6}\s+(?:Review rules|Approval questions before metadata changes)\s*$/im
    ],
    [
      "contributor-only procedure",
      /^#{1,6}\s+(?:Repository checks for contributors|Contributor-only alternative\b).*$/im
    ]
  ];
  if (/^docs\//.test(file) || file === "scripts/demo/README.md") {
    rules.push([
      "fixed release or tool version in evergreen guidance; link to maintained configuration",
      /\bSalesforce CLI\s+\d+\.\d+|\bNode\.js\s+\d+|\b(?:published package|package version)[:\s*`]+\d+\.\d+\.\d+|\b04t[A-Za-z0-9]{12,15}\b|\bgit checkout\s+(?:--detach\s+)?[a-f0-9]{40}\b/i
    ]);
  }
  if (/^docs\/examples\//.test(file)) {
    rules.push([
      "draft configuration labels in a published example",
      /\|\s*Proposed value\s*\|/i
    ]);
  }
  return rules
    .filter(([, pattern]) => pattern.test(visible))
    .map(([message]) => message);
}
