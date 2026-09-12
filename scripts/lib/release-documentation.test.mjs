import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (file) => readFile(file, "utf8");

test("heading fixture index distinguishes implemented source from pending org evidence", async () => {
  const text = await read(
    "packages/record-health-check/integration-tests/README.md"
  );
  const section = text.slice(text.indexOf("## Card heading display"));
  assert.doesNotMatch(section, /runtime heading implementation[^.]*pending/i);
  assert.match(section, /rendering[^.]*implemented/i);
  assert.match(section, /org\/browser evidence[^.]*pending/i);
});

test("Batch architecture describes automatic formula-safe scopes rather than a fixed default", async () => {
  for (const file of [
    "docs/architecture/apex-implementation/README.md",
    "docs/architecture/apex-implementation/runtime-support.md"
  ]) {
    const text = await read(file);
    assert.match(
      text,
      /automatic formula-safe\s+scopes? of 1[–-]100/i,
      `${file} must distinguish automatic scope selection.`
    );
    assert.doesNotMatch(
      text,
      /default (?:of )?100 records/i,
      `${file} must not promise a fixed automatic scope.`
    );
  }
});

test("Batch architecture exposes the Check Set adapter supported by the public API", async () => {
  const text = await read(
    "docs/architecture/apex-implementation/runtime-support.md"
  );
  assert.doesNotMatch(
    text,
    /Runs a Check or Check Set when Apex already has the record IDs/
  );
  assert.match(text, /Runs a Check Set when Apex already has the record IDs/);
});

test("release reference describes the display result mode for Apex callers", async () => {
  const text = await read("docs/reference/release-2.0.10.md");
  assert.doesNotMatch(text, /Display execution is card-only/);
  assert.match(text, /EVALUATION_WITH_DISPLAY/);
});

test("partial plugin-definition sample is explicitly identified as an excerpt", async () => {
  const text = await read("docs/reference/release-2.0.10.md");
  const sample = text.indexOf("global with sharing class MyCheck");
  assert.ok(sample > 0, "The definition sample must remain discoverable.");
  assert.match(
    text.slice(Math.max(0, sample - 500), sample),
    /excerpt[\s\S]*evaluate/i,
    "A class that omits evaluate must not be presented as a complete plugin."
  );
});
