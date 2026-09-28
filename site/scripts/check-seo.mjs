import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const siteRoot = fileURLToPath(new URL("../", import.meta.url));
const distRoot = path.join(siteRoot, "dist");
const origin = "https://docs.recordhealthcheck.com";

async function listHtmlFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  return (
    await Promise.all(
      entries.map((entry) => {
        const entryPath = path.join(directory, entry.name);
        if (entry.isDirectory()) return listHtmlFiles(entryPath);
        return entry.isFile() && entry.name.endsWith(".html")
          ? [entryPath]
          : [];
      })
    )
  ).flat();
}

function routeFor(file) {
  const relative = path.relative(distRoot, file).split(path.sep).join("/");
  if (relative === "index.html") return "/";
  if (relative.endsWith("/index.html")) {
    return `/${relative.slice(0, -"index.html".length)}`;
  }
  return `/${relative}`;
}

function attribute(tag, attributeName) {
  return tag.match(
    new RegExp(`\\b${attributeName}=["']([^"']+)["']`, "i")
  )?.[1];
}

function meta(html, key, value) {
  for (const tag of html.matchAll(/<meta\b[^>]*>/gi)) {
    if (attribute(tag[0], key) === value) return attribute(tag[0], "content");
  }
  return undefined;
}

function link(html, key, value, attributeName) {
  for (const tag of html.matchAll(/<link\b[^>]*>/gi)) {
    if (attribute(tag[0], key) === value) {
      return attribute(tag[0], attributeName);
    }
  }
  return undefined;
}

function title(html) {
  return html.match(/<title>([^<]+)<\/title>/i)?.[1]?.trim();
}

function structuredData(html) {
  const match = html.match(
    /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/i
  );
  if (!match) return undefined;
  return JSON.parse(match[1]);
}

const files = await listHtmlFiles(distRoot);
const pages = await Promise.all(
  files.map(async (file) => ({
    file,
    route: routeFor(file),
    html: await readFile(file, "utf8")
  }))
);
const publicPages = pages.filter(({ route }) => route !== "/404.html");
const failures = [];
const titles = new Map();
const descriptions = new Map();

for (const { html, route } of publicPages) {
  const pageTitle = title(html);
  const description = meta(html, "name", "description");
  const canonical = link(html, "rel", "canonical", "href");
  const expectedCanonical = `${origin}${route}`;
  const expectedSocialImage = `${origin}/social-card.png`;
  const checks = [
    ["title", pageTitle],
    ["description", description],
    ["canonical URL", canonical === expectedCanonical],
    [
      "indexable robots directive",
      meta(html, "name", "robots")?.startsWith("index, follow")
    ],
    ["Open Graph title", meta(html, "property", "og:title")],
    [
      "Open Graph description",
      meta(html, "property", "og:description") === description
    ],
    ["Open Graph URL", meta(html, "property", "og:url") === expectedCanonical],
    [
      "Open Graph image",
      meta(html, "property", "og:image") === expectedSocialImage
    ],
    [
      "Open Graph image type",
      meta(html, "property", "og:image:type") === "image/png"
    ],
    [
      "Open Graph image width",
      meta(html, "property", "og:image:width") === "1200"
    ],
    [
      "Open Graph image height",
      meta(html, "property", "og:image:height") === "630"
    ],
    ["Open Graph image alt", meta(html, "property", "og:image:alt")],
    [
      "Twitter card",
      meta(html, "name", "twitter:card") === "summary_large_image"
    ],
    ["Twitter title", meta(html, "name", "twitter:title")],
    [
      "Twitter description",
      meta(html, "name", "twitter:description") === description
    ],
    [
      "Twitter image",
      meta(html, "name", "twitter:image") === expectedSocialImage
    ],
    ["Twitter image alt", meta(html, "name", "twitter:image:alt")],
    [
      "agent discovery link",
      link(html, "href", "/llms.txt", "rel") === "alternate"
    ]
  ];
  for (const [label, passed] of checks) {
    if (!passed) failures.push(`${route}: missing or invalid ${label}`);
  }

  if (description && description.length > 160) {
    failures.push(
      `${route}: description exceeds 160 characters (${description.length})`
    );
  }

  if (pageTitle) {
    const previous = titles.get(pageTitle);
    if (previous)
      failures.push(`${route}: duplicate title also used by ${previous}`);
    titles.set(pageTitle, route);
  }
  if (description) {
    const previous = descriptions.get(description);
    if (previous)
      failures.push(`${route}: duplicate description also used by ${previous}`);
    descriptions.set(description, route);
  }

  try {
    const data = structuredData(html);
    if (!data) failures.push(`${route}: missing JSON-LD`);
    else {
      const expectedType = route === "/" ? "WebSite" : "TechArticle";
      if (data["@context"] !== "https://schema.org") {
        failures.push(`${route}: JSON-LD has the wrong context`);
      }
      if (data["@type"] !== expectedType) {
        failures.push(`${route}: JSON-LD expected ${expectedType}`);
      }
      if (data.url !== expectedCanonical) {
        failures.push(`${route}: JSON-LD URL does not match canonical`);
      }
    }
  } catch (error) {
    failures.push(`${route}: invalid JSON-LD (${error.message})`);
  }
}

const notFound = pages.find(({ route }) => route === "/404.html");
if (
  !notFound ||
  meta(notFound.html, "name", "robots") !== "noindex, nofollow"
) {
  failures.push("/404.html: expected noindex, nofollow");
}

const [robots, sitemap, llms, llmsFull, socialCard] = await Promise.all([
  readFile(path.join(distRoot, "robots.txt"), "utf8"),
  readFile(path.join(distRoot, "sitemap-0.xml"), "utf8"),
  readFile(path.join(distRoot, "llms.txt"), "utf8"),
  readFile(path.join(distRoot, "llms-full.txt"), "utf8"),
  readFile(path.join(distRoot, "social-card.png"))
]);

if (!robots.includes(`Sitemap: ${origin}/sitemap-index.xml`)) {
  failures.push("robots.txt: missing canonical sitemap URL");
}
for (const { route } of publicPages) {
  if (!sitemap.includes(`<loc>${origin}${route}</loc>`)) {
    failures.push(`${route}: missing from sitemap`);
  }
}
if (
  !llms.includes(`${origin}/llms-full.txt`) ||
  !llms.includes(`${origin}/reference/`)
) {
  failures.push("llms.txt: missing full corpus or reference entry");
}
if (
  !llmsFull.includes("# Complete documentation corpus") ||
  llmsFull.length < 100_000
) {
  failures.push(
    "llms-full.txt: complete documentation corpus was not generated"
  );
}
if (
  socialCard.toString("ascii", 1, 4) !== "PNG" ||
  socialCard.readUInt32BE(16) !== 1200 ||
  socialCard.readUInt32BE(20) !== 630
) {
  failures.push("social-card.png: expected a 1200x630 PNG");
}

if (failures.length > 0) {
  console.error(`SEO verification failed (${failures.length}):`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exitCode = 1;
} else {
  console.log(
    `SEO verification passed for ${publicPages.length} indexable pages, one noindex page, social embeds, sitemap, robots, and agent discovery files.`
  );
}
