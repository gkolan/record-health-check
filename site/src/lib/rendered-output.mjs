const excludedRawMarkdownContent =
  /<(pre|code|script|style|textarea|table)\b[^>]*>[\s\S]*?<\/\1>/gi;
const excludedStructuralContent =
  /<(pre|script|style|textarea)\b[^>]*>[\s\S]*?<\/\1>/gi;
const blockTags =
  /<\/?(?:address|article|aside|blockquote|br|div|dl|dt|dd|figcaption|figure|footer|form|h[1-6]|header|hr|li|main|nav|ol|p|section|summary|ul)\b[^>]*>/gi;

function decodeHtml(value) {
  return value
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&#x([\da-f]+);/gi, (_, code) =>
      String.fromCodePoint(Number.parseInt(code, 16))
    )
    .replaceAll("&nbsp;", " ")
    .replaceAll("&amp;", "&")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&quot;", '"')
    .replaceAll("&#39;", "'");
}

function visibleText(html, { excludeInlineCodeAndTables = false } = {}) {
  return decodeHtml(
    html
      .replace(
        excludeInlineCodeAndTables
          ? excludedRawMarkdownContent
          : excludedStructuralContent,
        " "
      )
      .replace(blockTags, "\n")
      .replace(/<[^>]+>/g, " ")
  );
}

function attributeValue(attributes, name) {
  const match = attributes.match(
    new RegExp(`\\b${name}\\s*=\\s*(["'])(.*?)\\1`, "i")
  );
  return match?.[2]?.trim() ?? "";
}

/**
 * Inspect one generated HTML page for defects that source-Markdown checks cannot see.
 * Browser-only behavior and visual layout remain the responsibility of the screenshot audit.
 */
export function renderedOutputIssues(html, pagePath) {
  const issues = [];
  const mainMatch = html.match(/<main\b[^>]*>([\s\S]*?)<\/main>/i);
  if (!mainMatch) return [`${pagePath}: missing main content`];

  const main = mainMatch[1];
  const text = visibleText(main);
  if (!text.trim()) issues.push(`${pagePath}: empty main content`);

  const headingMatches = [
    ...main.matchAll(/<h([1-6])\b[^>]*>([\s\S]*?)<\/h\1>/gi)
  ];
  const h1Count = headingMatches.filter((match) => match[1] === "1").length;
  if (pagePath !== "/404.html" && h1Count !== 1) {
    issues.push(`${pagePath}: expected one main h1, found ${h1Count}`);
  }
  for (let index = 1; index < headingMatches.length; index += 1) {
    const previous = Number(headingMatches[index - 1][1]);
    const current = Number(headingMatches[index][1]);
    if (current > previous + 1) {
      issues.push(`${pagePath}: heading jump ${previous}→${current}`);
    }
  }
  for (const heading of headingMatches) {
    if (!visibleText(heading[2]).trim()) {
      issues.push(`${pagePath}: empty heading h${heading[1]}`);
    }
  }

  const rawMarkdownText = visibleText(main, {
    excludeInlineCodeAndTables: true
  });
  const rawMarkdownPatterns = [
    ["fence", /```/],
    ["callout", /\[!(?:NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]/],
    ["link", /\[[^\]\n]+\]\((?:https?:|\.?\.?\/|#)[^)]+\)/],
    ["heading", /(?:^|\n)\s{0,3}#{1,6}\s+\S/],
    ["table", /(?:^|\n)\s*\|[^\n]+\|\s*(?:\n|$)/],
    ["MDX", /(?:^|\n)\s*(?:import|export)\s+.+\s+from\s+["']/]
  ];
  for (const [kind, pattern] of rawMarkdownPatterns) {
    if (pattern.test(rawMarkdownText)) {
      issues.push(`${pagePath}: raw Markdown ${kind}`);
    }
  }

  for (const item of main.matchAll(
    /<li\b[^>]*class=(["'])[^"']*\btask-list-item\b[^"']*\1[^>]*>([\s\S]*?)<\/li>/gi
  )) {
    for (const input of item[2].matchAll(/<input\b([^>]*)>/gi)) {
      const attributes = input[1];
      if (!/\btype\s*=\s*(["'])checkbox\1/i.test(attributes)) continue;
      if (
        !attributeValue(attributes, "aria-label") &&
        !attributeValue(attributes, "aria-labelledby") &&
        !attributeValue(attributes, "title")
      ) {
        issues.push(`${pagePath}: unnamed task-list checkbox`);
      }
    }
  }

  for (const anchor of main.matchAll(/<a\b([^>]*)>/gi)) {
    if (!/\bhref\s*=\s*(["'])[^"']+\1/i.test(anchor[1])) {
      issues.push(`${pagePath}: anchor without href`);
    }
  }
  if (/(?:\bundefined\b|\[object Object\])/.test(rawMarkdownText)) {
    issues.push(`${pagePath}: unresolved generated value`);
  }

  return [...new Set(issues)];
}
