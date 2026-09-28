import { chromium } from "@playwright/test";
import { createReadStream } from "node:fs";
import { mkdir, readFile, readdir, stat, writeFile } from "node:fs/promises";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { renderedOutputIssues } from "../src/lib/rendered-output.mjs";

const siteRoot = fileURLToPath(new URL("../", import.meta.url));
const repositoryRoot = path.resolve(siteRoot, "..");
const distRoot = path.join(siteRoot, "dist");
const runId = new Date().toISOString().replaceAll(":", "-").replace(".", "-");
const outputRoot = path.join(
  repositoryRoot,
  "reports",
  "docs-render-audit",
  runId
);

async function listHtml(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...(await listHtml(entryPath)));
    else if (entry.name.endsWith(".html")) files.push(entryPath);
  }
  return files;
}

function routeFor(file) {
  const relative = path.relative(distRoot, file).split(path.sep).join("/");
  if (relative === "index.html") return "/";
  if (relative.endsWith("/index.html")) {
    return `/${relative.slice(0, -"index.html".length)}`;
  }
  return `/${relative}`;
}

function screenshotName(route) {
  if (route === "/") return "home.png";
  return `${route.replace(/^\//, "").replace(/\/$/, "").replaceAll("/", "--")}.png`;
}

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function contentType(file) {
  return (
    {
      ".css": "text/css; charset=utf-8",
      ".html": "text/html; charset=utf-8",
      ".ico": "image/x-icon",
      ".js": "text/javascript; charset=utf-8",
      ".json": "application/json; charset=utf-8",
      ".png": "image/png",
      ".svg": "image/svg+xml",
      ".webp": "image/webp"
    }[path.extname(file)] ?? "application/octet-stream"
  );
}

const server = http.createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(
      new URL(request.url, "http://local").pathname
    );
    let relative = pathname.replace(/^\/+/, "");
    if (!relative || relative.endsWith("/")) relative += "index.html";
    const file = path.resolve(distRoot, relative);
    if (file !== distRoot && !file.startsWith(`${distRoot}${path.sep}`)) {
      response.writeHead(403).end("Forbidden");
      return;
    }
    const details = await stat(file);
    if (!details.isFile()) throw new Error("Not a file");
    response.writeHead(200, { "content-type": contentType(file) });
    createReadStream(file).pipe(response);
  } catch {
    response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    response.end("Not found");
  }
});

await new Promise((resolve, reject) => {
  server.once("error", reject);
  server.listen(0, "127.0.0.1", resolve);
});
const address = server.address();
const baseUrl = `http://127.0.0.1:${address.port}`;

const htmlFiles = await listHtml(distRoot);
const allRoutes = htmlFiles.map(routeFor).sort();
const fileByRoute = new Map(htmlFiles.map((file) => [routeFor(file), file]));
const requestedRoutes = (process.env.AUDIT_ROUTES ?? "")
  .split(",")
  .map((route) => route.trim())
  .filter(Boolean);
const routes = requestedRoutes.length
  ? allRoutes.filter((route) => requestedRoutes.includes(route))
  : allRoutes;
await mkdir(outputRoot, { recursive: true });

const viewports = [
  { name: "desktop", width: 1440, height: 1000 },
  { name: "mobile", width: 390, height: 844 }
];
const results = [];
let browser;

try {
  browser = await chromium.launch({ headless: true });
  for (const viewport of viewports) {
    const screenshotRoot = path.join(outputRoot, viewport.name);
    await mkdir(screenshotRoot, { recursive: true });
    const context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      colorScheme: "light",
      reducedMotion: "reduce"
    });

    for (const route of routes) {
      const page = await context.newPage();
      const runtimeIssues = [];
      page.on("console", (message) => {
        if (message.type() === "error") {
          runtimeIssues.push(`console: ${message.text()}`);
        }
      });
      page.on("pageerror", (error) =>
        runtimeIssues.push(`page error: ${error.message}`)
      );
      page.on("requestfailed", (request) => {
        if (request.url().startsWith(baseUrl)) {
          runtimeIssues.push(
            `request failed: ${request.url()} (${request.failure()?.errorText ?? "unknown"})`
          );
        }
      });

      const response = await page.goto(`${baseUrl}${route}`, {
        waitUntil: "networkidle",
        timeout: 30_000
      });
      await page.evaluate(() => document.fonts.ready);
      const browserState = await page.evaluate(() => ({
        brokenImages: [...document.images]
          .filter((image) => !image.complete || image.naturalWidth === 0)
          .map(
            (image) =>
              image.currentSrc || image.src || image.alt || "unnamed image"
          ),
        horizontalOverflow:
          document.documentElement.scrollWidth -
          document.documentElement.clientWidth
      }));
      const screenshot = path.join(screenshotRoot, screenshotName(route));
      await page.screenshot({
        path: screenshot,
        fullPage: true,
        animations: "disabled"
      });

      const source = await readFile(fileByRoute.get(route), "utf8");
      const issues = renderedOutputIssues(source, route);
      if (!response?.ok() && route !== "/404.html") {
        issues.push(`HTTP ${response?.status() ?? "no response"}`);
      }
      for (const image of browserState.brokenImages) {
        issues.push(`broken image: ${image}`);
      }
      if (browserState.horizontalOverflow > 2) {
        issues.push(`viewport overflow: ${browserState.horizontalOverflow}px`);
      }
      issues.push(...runtimeIssues);
      results.push({
        route,
        viewport: viewport.name,
        screenshot: path.relative(outputRoot, screenshot),
        title: await page.title(),
        issues: [...new Set(issues)]
      });
      await page.close();
    }
    await context.close();
  }
} finally {
  await browser?.close();
  await new Promise((resolve) => server.close(resolve));
}

const issueResults = results.filter((result) => result.issues.length);
const manifest = {
  generatedAt: new Date().toISOString(),
  baseUrl,
  pageCount: routes.length,
  screenshotCount: results.length,
  issuePageCount: issueResults.length,
  results
};
await writeFile(
  path.join(outputRoot, "manifest.json"),
  `${JSON.stringify(manifest, null, 2)}\n`
);

const cards = results
  .map(
    (result) => `<article class="${result.issues.length ? "issue" : "pass"}">
  <h2>${escapeHtml(`${result.viewport}: ${result.route}`)}</h2>
  <img loading="lazy" src="${escapeHtml(result.screenshot)}" alt="${escapeHtml(`${result.viewport} screenshot of ${result.route}`)}">
  <pre>${escapeHtml(result.issues.length ? result.issues.join("\n") : "PASS")}</pre>
</article>`
  )
  .join("\n");
await writeFile(
  path.join(outputRoot, "index.html"),
  `<!doctype html><html><head><meta charset="utf-8"><title>Documentation render audit</title><style>body{font:14px system-ui;margin:20px;background:#eef2f6}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px}article{background:white;padding:12px;border:2px solid #2e844a;border-radius:8px}article.issue{border-color:#ba0517}h2{font-size:14px;overflow-wrap:anywhere}img{display:block;width:100%;height:440px;object-fit:contain;object-position:top;background:#f3f3f3}pre{white-space:pre-wrap;overflow-wrap:anywhere}</style></head><body><h1>Documentation render audit</h1><p>${routes.length} pages, ${results.length} screenshots, ${issueResults.length} viewport results with findings.</p><main>${cards}</main></body></html>`
);

console.log(`AUDIT_ROOT=${outputRoot}`);
console.log(`PAGES=${routes.length}`);
console.log(`SCREENSHOTS=${results.length}`);
console.log(`ISSUE_RESULTS=${issueResults.length}`);
for (const result of issueResults) {
  console.log(
    `${result.viewport} ${result.route}: ${result.issues.join(" | ")}`
  );
}
if (issueResults.length) process.exitCode = 1;
