import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const css = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.css"
  ),
  "utf8"
);

test("the exact hovered or focused inline link overrides row discovery with a solid underline", () => {
  const targetedRule = css.match(
    /\.rhc-row:hover \.rhc-inline-link:hover,\s*\.rhc-row:focus-within \.rhc-inline-link:focus-visible\s*\{([^}]*)\}/
  );

  assert.ok(
    targetedRule,
    "The exact link state must have a higher-specificity rule than the dotted row state."
  );
  assert.match(targetedRule[1], /text-decoration-style:\s*solid\s*;/);
  assert.match(targetedRule[1], /text-decoration-line:\s*underline\s*;/);
});
