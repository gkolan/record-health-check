import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { renderedOutputIssues } from "../src/lib/rendered-output.mjs";

const siteRoot = fileURLToPath(new URL("../", import.meta.url));
const distRoot = path.join(siteRoot, "dist");

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

function pagePathFor(filePath) {
  const relative = path.relative(distRoot, filePath).split(path.sep).join("/");
  if (relative === "index.html") return "/";
  if (relative.endsWith("/index.html")) {
    return `/${relative.slice(0, -"index.html".length)}`;
  }
  return `/${relative}`;
}

const files = await listHtmlFiles(distRoot);
const failures = (
  await Promise.all(
    files.map(async (file) =>
      renderedOutputIssues(await readFile(file, "utf8"), pagePathFor(file))
    )
  )
).flat();

if (failures.length > 0) {
  console.error(
    `Rendered documentation verification failed (${failures.length}):`
  );
  for (const failure of failures) console.error(`- ${failure}`);
  process.exitCode = 1;
} else {
  console.log(
    `Rendered documentation verification passed for ${files.length} built pages.`
  );
}
