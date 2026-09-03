import assert from "node:assert/strict";
import test from "node:test";
import { documentationAudienceIssues } from "./documentation-audience.mjs";

test("rejects scoring and editorial material from user guides", () => {
  for (const markdown of [
    "### 25-check quality gate",
    "The quality-score tables are below.",
    "| Order | Understandability | Business value | Logic depth |",
    "| Rating | Logic depth 10 · **30/30** |",
    "| Total /30 | Quality /10 |",
    "This is a human-review specification.",
    "## Review rules",
    "## Approval questions before metadata changes",
    "## Repository checks for contributors",
    "## Contributor-only alternative: Remove development source"
  ]) {
    assert.ok(
      documentationAudienceIssues("docs/install/demo.md", markdown).length,
      markdown
    );
  }
  assert.ok(
    documentationAudienceIssues(
      "scripts/demo/README.md",
      "See the quality-score table."
    ).length
  );
  assert.ok(
    documentationAudienceIssues(
      "docs/examples/example.md",
      "| Check field | Proposed value |"
    ).length
  );
});

test("preserves user verification, business scores, and AI drafting instructions", () => {
  for (const [file, markdown] of [
    [
      "docs/install/demo.md",
      "25 Checks: 7 Passed and 17 Failed. Verify setup."
    ],
    ["docs/examples/apex/strategic-readiness.md", "A score of 100 passes."],
    [
      "docs/examples/formula/account.md",
      "Account Rating is Hot, Warm, or Cold."
    ],
    ["docs/build-checks/draft-with-ai.md", "| Field | Proposed value |"],
    ["docs/developer-guides/mcp.md", "Verify each authentication gate."],
    [
      "docs/install/demo.md",
      "## Review checklist\nTest with the intended user."
    ],
    ["docs/reference/fields.md", "<!-- Maintainer quality gate reminder -->"]
  ]) {
    assert.deepEqual(documentationAudienceIssues(file, markdown), []);
  }
});

test("keeps maintainer standards in their designated documentation", () => {
  for (const file of [
    "docs/quality-gates/documentation-standard.md",
    "docs/contributing/source-development.md",
    "docs/architecture/framework.md",
    ".github/CONTRIBUTING.md",
    "PUBLISHING.md",
    "packages/record-health-check/integration-tests/README.md"
  ]) {
    assert.deepEqual(
      documentationAudienceIssues(file, "## Quality gates\n## Review rules"),
      []
    );
  }
});

test("keeps installation defaults tied to maintained release and tool configuration", () => {
  for (const markdown of [
    "Install Salesforce CLI 9.8.7.",
    "Use Node.js 99.",
    "### Published package: 9.8.7.6",
    "The published package **9.8.7.6** is available.",
    "sf package install --package 04tABCDEFGHIJKLMNO",
    "git checkout --detach 0123456789abcdef0123456789abcdef01234567"
  ]) {
    assert.ok(
      documentationAudienceIssues("docs/install/demo.md", markdown).length,
      markdown
    );
  }
  for (const markdown of [
    "Install the latest released package.",
    "Use Salesforce CLI from [toolchain configuration](../../config/toolchain.json).",
    "Copy stable.subscriberPackageVersionId from the release configuration.",
    "sf package install --package PACKAGE_VERSION_ID"
  ]) {
    assert.deepEqual(
      documentationAudienceIssues("docs/install/demo.md", markdown),
      []
    );
  }
});
