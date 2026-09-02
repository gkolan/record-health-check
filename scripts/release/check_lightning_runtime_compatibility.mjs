#!/usr/bin/env node

import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { extname, join, relative, resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const lwcRoot = resolve(
  root,
  "packages/record-health-check/force-app/main/default/lwc"
);

const forbiddenPatterns = [
  {
    pattern: /\bdocument\s*(?:\.|\[)/g,
    reason:
      "accesses page-owned DOM through document; Lightning Locker requires component-owned DOM through this.template"
  },
  {
    pattern: /\b(?:localStorage|sessionStorage|customElements)\b/g,
    reason:
      "uses a browser global whose namespace or availability differs between Lightning Locker and LWS"
  },
  {
    pattern: /\.(?:shadowRoot|innerHTML|outerHTML)\b/g,
    reason:
      "uses a DOM API that bypasses or is unavailable through Lightning security boundaries"
  },
  {
    pattern: /\beval\s*\(|\bnew\s+Function\s*\(/g,
    reason:
      "uses dynamic code evaluation with different Locker and LWS behavior"
  },
  {
    pattern: /(?:\$A|\b(?:Aura|Sfdc|sforce))\s*(?:\.|\[)/g,
    reason:
      "uses an Aura global that isn't available to Lightning web components"
  },
  {
    pattern: /\b(?:Worker|SharedWorker|ServiceWorker)\s*\(/g,
    reason:
      "uses a worker API that Lightning Web Security blocks from escaping its sandbox"
  },
  {
    pattern: /\bhref\s*=\s*["']\s*(?:javascript\s*:|data\s*:\s*text\/html)/gi,
    reason:
      "binds an executable URL scheme in markup, which violates Lightning CSP"
  }
];

function lineNumber(source, index) {
  return source.slice(0, index).split("\n").length;
}

function inspectSource(file, source) {
  const failures = [];
  for (const { pattern, reason } of forbiddenPatterns) {
    pattern.lastIndex = 0;
    for (const match of source.matchAll(pattern)) {
      failures.push(`${file}:${lineNumber(source, match.index)}: ${reason}`);
    }
  }

  if (/\blwc:dom\s*=\s*["']manual["']/.test(source)) {
    failures.push(
      `${file}: manual DOM requires an explicit Locker/LWS security review and dedicated runtime tests`
    );
  }

  if (/\bregisterRefreshHandler\s*\(/.test(source)) {
    const registrationMethod = source.match(
      /_registerRefreshViewHandler\s*\(\)\s*\{([\s\S]*?)\n\s*\}\n\n\s*_restartConfiguredLifecycle\s*\(/
    )?.[1];
    if (!registrationMethod) {
      failures.push(
        `${file}: RefreshView registration must be isolated in _registerRefreshViewHandler for compatibility auditing`
      );
      return failures;
    }
    if (!/registerRefreshHandler\s*\(\s*this\s*,/.test(registrationMethod)) {
      failures.push(
        `${file}: RefreshView must include the Lightning Web Security registration protocol`
      );
    }
    if (
      !/registerRefreshHandler\s*\(\s*this\.template\.host\s*,[\s\S]{0,160}\.bind\(this\)/.test(
        registrationMethod
      )
    ) {
      failures.push(
        `${file}: RefreshView must include the Lightning Locker host-and-bound-handler protocol`
      );
    }
    if ((registrationMethod.match(/\bcatch\s*\{/g) || []).length !== 2) {
      failures.push(
        `${file}: RefreshView protocol fallback and fail-safe handling are required so registration cannot prevent component connection`
      );
    }
  }

  return failures;
}

function walk(directory) {
  const files = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === "__tests__") continue;
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...walk(path));
    } else if ([".html", ".js"].includes(extname(entry.name))) {
      files.push(path);
    }
  }
  return files;
}

function selfTest() {
  assert.equal(
    inspectSource("safe.js", "this.template.querySelector('p')").length,
    0
  );
  assert.ok(inspectSource("unsafe.js", "document.body.classList").length > 0);
  assert.ok(inspectSource("unsafe.js", "element.innerHTML = value").length > 0);
  assert.ok(inspectSource("unsafe.js", "new Worker(url)").length > 0);
  assert.ok(
    inspectSource(
      "lws-only.js",
      `_registerRefreshViewHandler() {
        registerRefreshHandler(this, this.refreshHandler);
      }

      _restartConfiguredLifecycle(`
    ).some((failure) => failure.includes("Lightning Locker"))
  );
  assert.equal(
    inspectSource(
      "dual-runtime.js",
      `_registerRefreshViewHandler() {
        try {
          registerRefreshHandler(this, this.refreshHandler);
        } catch {
          try {
            registerRefreshHandler(this.template.host, this.refreshHandler.bind(this));
          } catch {}
        }
      }

      _restartConfiguredLifecycle(`
    ).length,
    0
  );
}

if (process.argv.includes("--self-test")) {
  selfTest();
}

const files = walk(lwcRoot);
const failures = files.flatMap((path) => {
  const file = relative(root, path).split("\\").join("/");
  return inspectSource(file, readFileSync(path, "utf8"));
});

const refreshTests = readFileSync(
  resolve(lwcRoot, "recordHealthCheck/__tests__/recordHealthCheck.test.js"),
  "utf8"
);
for (const requiredTest of [
  "uses the Lightning Locker registration protocol when LWS registration is rejected",
  "continues rendering when RefreshView registration is unavailable"
]) {
  if (!refreshTests.includes(requiredTest)) {
    failures.push(
      `recordHealthCheck.test.js: missing required runtime regression test "${requiredTest}"`
    );
  }
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  `Verified ${files.length} shipped LWC source files for Lightning Locker and Lightning Web Security compatibility.`
);
