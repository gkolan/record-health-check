import { access, readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const siteRoot = fileURLToPath(new URL("../", import.meta.url));
const distRoot = path.join(siteRoot, "dist");
const siteOrigin = "https://docs.recordhealthcheck.com";

async function listHtmlFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(
    entries.map(async (entry) => {
      const entryPath = path.join(directory, entry.name);
      return entry.isDirectory()
        ? listHtmlFiles(entryPath)
        : entry.isFile() && entry.name.endsWith(".html")
          ? [entryPath]
          : [];
    })
  );
  return files.flat();
}

function pagePathFor(filePath) {
  const relative = path.relative(distRoot, filePath).split(path.sep).join("/");
  if (relative === "index.html") return "/";
  if (relative.endsWith("/index.html")) {
    return `/${relative.slice(0, -"index.html".length)}`;
  }
  return `/${relative}`;
}

function destinationFileFor(pathname) {
  const relative = pathname.replace(/^\/+/, "");
  if (pathname.endsWith("/"))
    return path.join(distRoot, relative, "index.html");
  if (path.extname(relative)) return path.join(distRoot, relative);
  return path.join(distRoot, `${relative}.html`);
}

async function exists(filePath) {
  try {
    await access(filePath);
    return true;
  } catch {
    return false;
  }
}

function decodeHtml(value) {
  return value.replaceAll("&amp;", "&").replaceAll("&quot;", '"');
}

const files = await listHtmlFiles(distRoot);
const htmlByFile = new Map(
  await Promise.all(
    files.map(async (filePath) => [filePath, await readFile(filePath, "utf8")])
  )
);
const failures = [];
let checkedLinks = 0;

for (const [sourceFile, html] of htmlByFile) {
  const sourcePage = pagePathFor(sourceFile);
  // Inspect actual anchors only. Documentation code samples intentionally contain
  // strings such as href="..." and Salesforce /lightning URLs; those are text,
  // not browser navigation.
  const links = html.matchAll(/<a\b[^>]*\bhref=(['"])(.*?)\1[^>]*>/gi);

  for (const match of links) {
    const href = decodeHtml(match[2]);
    if (
      !href ||
      /^(?:mailto:|tel:|javascript:|data:)/i.test(href) ||
      href.startsWith("//")
    ) {
      continue;
    }

    let destination;
    try {
      destination = new URL(href, `${siteOrigin}${sourcePage}`);
    } catch {
      failures.push(`${sourcePage}: invalid href ${href}`);
      continue;
    }
    if (destination.origin !== siteOrigin) continue;

    checkedLinks += 1;
    const destinationFile = destinationFileFor(
      decodeURIComponent(destination.pathname)
    );
    if (!(await exists(destinationFile))) {
      failures.push(`${sourcePage}: ${href} points to a missing page`);
      continue;
    }

    if (destination.hash) {
      const destinationHtml =
        htmlByFile.get(destinationFile) ??
        (await readFile(destinationFile, "utf8"));
      const fragment = decodeURIComponent(destination.hash.slice(1));
      const escaped = fragment.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      if (!new RegExp(`(?:id|name)=["']${escaped}["']`).test(destinationHtml)) {
        failures.push(`${sourcePage}: ${href} points to a missing fragment`);
      }
    }
  }
}

if (failures.length > 0) {
  console.error(`Internal link verification failed (${failures.length}):`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exitCode = 1;
} else {
  console.log(
    `Internal link verification passed for ${checkedLinks} links across ${files.length} built pages.`
  );
}
