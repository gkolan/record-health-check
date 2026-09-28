import { cp, mkdir, readdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../../", import.meta.url));
const sourceRoot = path.join(repositoryRoot, "docs");
const contentRoot = path.join(repositoryRoot, "site/src/content/docs");
const publicAssets = path.join(repositoryRoot, "site/public/assets");
const sourceAssets = path.join(repositoryRoot, "site/src/assets");
const publicRoot = path.join(repositoryRoot, "site/public");

async function listMarkdownFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(
    entries.map(async (entry) => {
      const entryPath = path.join(directory, entry.name);
      return entry.isDirectory()
        ? listMarkdownFiles(entryPath)
        : entry.isFile() && entry.name.endsWith(".md")
          ? [entryPath]
          : [];
    })
  );
  return files.flat();
}

function outputPathFor(sourcePath) {
  const relativePath = path.relative(sourceRoot, sourcePath);
  return path.join(
    contentRoot,
    path.basename(relativePath) === "README.md"
      ? path.join(path.dirname(relativePath), "index.md")
      : relativePath
  );
}

function routeForOutputPath(outputPath) {
  const relativePath = path.relative(contentRoot, outputPath);
  const routePath =
    path.basename(relativePath) === "index.md"
      ? path.dirname(relativePath)
      : relativePath.replace(/\.md$/, "");
  // Astro normalizes dots out of content collection slugs. Mirror that here so
  // links to versioned pages resolve to the route Astro actually builds.
  const normalized = routePath
    .split(path.sep)
    .map((segment) => segment.replaceAll(".", ""))
    .join("/");
  return normalized === "." ? "/" : `/${normalized}/`;
}

function routeForSourceDirectory(directoryPath) {
  const relativePath = path.relative(sourceRoot, directoryPath);
  const normalized = relativePath
    .split(path.sep)
    .map((segment) => segment.replaceAll(".", ""))
    .join("/");
  return normalized === "." ? "/" : `/${normalized}/`;
}

function extractDescription(markdown, title) {
  const lines = markdown.split("\n");
  const paragraph = [];
  let inFence = false;

  for (const line of lines.slice(1)) {
    if (line.startsWith("```")) {
      inFence = !inFence;
      continue;
    }
    if (inFence || /^\s*(#|>|[-*+] |\d+\. |\||<)/.test(line)) {
      if (paragraph.length > 0) break;
      continue;
    }
    if (line.trim() === "") {
      if (paragraph.length > 0) break;
      continue;
    }
    paragraph.push(line.trim());
  }

  const plainText = (paragraph.join(" ") || `Learn about ${title}.`)
    .replace(/!\[([^\]]*)\]\([^)]+\)/g, "$1")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/<[^>]+>/g, " ")
    .replace(/[`*_~]/g, "")
    .replace(/\s+/g, " ")
    .trim();

  if (plainText.length <= 160) return plainText;
  const shortened = plainText
    .slice(0, 157)
    .replace(/\s+\S*$/, "")
    .trimEnd();
  return `${shortened}…`;
}

function agentIndex(sourceFiles) {
  const grouped = new Map();
  for (const sourcePath of sourceFiles) {
    const outputPath = outputPathFor(sourcePath);
    const route = routeForOutputPath(outputPath);
    const section = route.split("/").filter(Boolean)[0] ?? "home";
    const items = grouped.get(section) ?? [];
    items.push({ route, sourcePath });
    grouped.set(section, items);
  }

  const featured = [
    ["Start here", "/start-here/"],
    ["Build Checks", "/build-checks/"],
    ["Examples", "/examples/"],
    ["Developer guides", "/developer-guides/"],
    ["Reference", "/reference/"],
    ["Public contract", "/reference/current-contract/"],
    ["Agentforce and MCP", "/developer-guides/agentforce-and-mcp/"]
  ];

  const index = [
    "# Record Health Check documentation",
    "",
    "> Install, configure, operate, and extend Record Health Check for Salesforce.",
    "",
    "The canonical public documentation is static HTML at https://docs.recordhealthcheck.com/. Source Markdown is maintained in the public Record Health Check repository.",
    "",
    "## Primary documentation",
    "",
    ...featured.map(
      ([label, route]) =>
        `- [${label}](https://docs.recordhealthcheck.com${route})`
    ),
    "",
    "## Machine-readable resources",
    "",
    "- [Complete documentation corpus](https://docs.recordhealthcheck.com/llms-full.txt)",
    "- [XML sitemap](https://docs.recordhealthcheck.com/sitemap-index.xml)",
    "- [GitHub source](https://github.com/gkolan/record-health-check/tree/docs-v3/docs)",
    ""
  ].join("\n");

  return { grouped, index };
}

async function writeAgentDiscovery(sourceFiles) {
  const { grouped, index } = agentIndex(sourceFiles);
  const full = [index.trimEnd(), "", "# Complete documentation corpus", ""];

  for (const section of [...grouped.keys()].sort()) {
    full.push(`## ${section}`, "");
    for (const item of grouped.get(section)) {
      const markdown = await readFile(item.sourcePath, "utf8");
      full.push(
        `Source: https://docs.recordhealthcheck.com${item.route}`,
        "",
        markdown.trim(),
        ""
      );
    }
  }

  await mkdir(publicRoot, { recursive: true });
  await writeFile(path.join(publicRoot, "llms.txt"), index);
  await writeFile(
    path.join(publicRoot, "llms-full.txt"),
    `${full.join("\n")}\n`
  );
}

function rewriteLinks(markdown, sourcePath) {
  const withPublicAssets = markdown.replace(
    /\]\(((?:\.\.\/)+assets\/[^)\s]+)\)/g,
    (match, assetPath) => {
      const absoluteAsset = path.resolve(path.dirname(sourcePath), assetPath);
      if (!absoluteAsset.startsWith(path.join(repositoryRoot, "assets"))) {
        return match;
      }
      return `](/${path.relative(repositoryRoot, absoluteAsset).split(path.sep).join("/")})`;
    }
  );

  return withPublicAssets.replace(/\]\(([^)\s]+)\)/g, (match, destination) => {
    if (
      /^[a-z]+:/i.test(destination) ||
      destination.startsWith("#") ||
      destination.startsWith("/")
    ) {
      return match;
    }

    const hashIndex = destination.indexOf("#");
    const linkPath =
      hashIndex === -1 ? destination : destination.slice(0, hashIndex);
    const hash = hashIndex === -1 ? "" : destination.slice(hashIndex);
    const absoluteTarget = path.resolve(path.dirname(sourcePath), linkPath);

    if (
      absoluteTarget === sourceRoot ||
      absoluteTarget.startsWith(`${sourceRoot}${path.sep}`)
    ) {
      if (linkPath.endsWith(".md")) {
        return `](${routeForOutputPath(outputPathFor(absoluteTarget))}${hash})`;
      }
      return `](${routeForSourceDirectory(absoluteTarget)}${hash})`;
    }

    const repositoryPath = path
      .relative(repositoryRoot, absoluteTarget)
      .split(path.sep)
      .join("/");
    return `](https://github.com/gkolan/record-health-check/blob/main/${repositoryPath}${hash})`;
  });
}

function transformGitHubAlerts(markdown) {
  const variants = {
    NOTE: ["note", ""],
    TIP: ["tip", ""],
    IMPORTANT: ["caution", "Important"],
    WARNING: ["caution", "Warning"],
    CAUTION: ["danger", "Caution"]
  };
  const lines = markdown.split("\n");
  const transformed = [];

  for (let index = 0; index < lines.length; index += 1) {
    const alert = lines[index].match(
      /^>\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$/
    );
    if (!alert) {
      transformed.push(lines[index]);
      continue;
    }

    const [variant, title] = variants[alert[1]];
    transformed.push(`:::${variant}${title ? `[${title}]` : ""}`);

    while (index + 1 < lines.length && /^>/.test(lines[index + 1])) {
      index += 1;
      transformed.push(lines[index].replace(/^> ?/, ""));
    }

    transformed.push(":::");
  }

  return transformed.join("\n");
}

function transformMarkdown(markdown, sourcePath, outputPath) {
  const titleMatch = markdown.match(/^#\s+(.+)$/m);
  if (!titleMatch) {
    throw new Error(
      `Missing H1 in ${path.relative(repositoryRoot, sourcePath)}`
    );
  }

  const title = titleMatch[1].trim();
  const description = extractDescription(markdown, title);
  const repositoryPath = path
    .relative(repositoryRoot, sourcePath)
    .split(path.sep)
    .join("/");
  const withoutTitle = markdown.replace(/^#\s+.+\n+/, "");
  const withAsides = transformGitHubAlerts(withoutTitle);
  const content = rewriteLinks(withAsides, sourcePath);

  return [
    "---",
    `title: ${JSON.stringify(title)}`,
    `description: ${JSON.stringify(description)}`,
    `sourcePath: ${JSON.stringify(repositoryPath)}`,
    "---",
    "",
    content.trimStart()
  ].join("\n");
}

await rm(contentRoot, { recursive: true, force: true });
await rm(publicAssets, { recursive: true, force: true });
await rm(sourceAssets, { recursive: true, force: true });
await mkdir(contentRoot, { recursive: true });
await mkdir(path.dirname(publicAssets), { recursive: true });
await mkdir(sourceAssets, { recursive: true });

const homePage = await readFile(
  path.join(repositoryRoot, "site/src/content/home.mdx"),
  "utf8"
);
await writeFile(path.join(contentRoot, "index.mdx"), homePage);
await cp(
  path.join(repositoryRoot, "site/src/content/not-found.md"),
  path.join(contentRoot, "404.md")
);

const sourceFiles = (await listMarkdownFiles(sourceRoot)).filter(
  (sourcePath) => sourcePath !== path.join(sourceRoot, "README.md")
);

for (const sourcePath of sourceFiles) {
  const outputPath = outputPathFor(sourcePath);
  const markdown = await readFile(sourcePath, "utf8");
  await mkdir(path.dirname(outputPath), { recursive: true });
  await writeFile(
    outputPath,
    transformMarkdown(markdown, sourcePath, outputPath)
  );
}

await cp(path.join(repositoryRoot, "assets"), publicAssets, {
  recursive: true
});
await cp(
  path.join(repositoryRoot, "assets/img/RHC_LOGO.png"),
  path.join(sourceAssets, "RHC_LOGO.png")
);
await writeAgentDiscovery(sourceFiles);
console.log(
  `Prepared ${sourceFiles.length + 2} canonical documentation pages.`
);
