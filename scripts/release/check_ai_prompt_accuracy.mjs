#!/usr/bin/env node

/**
 * Fails when the AI drafting prompts under `docs/build-checks/draft-with-ai`
 * name a field or stored value that `Record_Health_Check__mdt` or
 * `Record_Health_Check_Set__mdt` does not declare, or when a configurable field
 * is unreachable from every page.
 *
 * These pages are pasted into an assistant as its entire product reference, so
 * a stale value there is a Check that will not save. Nothing else in the gate
 * set reads documentation against the field metadata.
 */

import fs from "node:fs";
import path from "node:path";
import { paths } from "../lib/paths.mjs";
import { fieldLength, picklistValues } from "../lib/fixture-value-coverage.mjs";
import {
  CROSS_CUTTING,
  EVALUATION_TYPES,
  coverageGaps,
  draftFields,
  draftNarrativeProblems,
  inventedNameProblems,
  draftProblems,
  promptBlock
} from "../lib/ai-draft-validation.mjs";
import {
  capabilityGaps,
  currentContractProblems,
  fieldNameProblems,
  mergeSyntaxProblems,
  picklistValueProblems,
  sharedBlockDrift
} from "../lib/ai-prompt-accuracy.mjs";

const objects = ["Record_Health_Check__mdt", "Record_Health_Check_Set__mdt"];

/**
 * Field API names an administrator can set that the drafting pages deliberately
 * do not offer to an assistant, with the reason. Keep this empty unless a field
 * genuinely cannot be part of a drafted proposal.
 */
const WITHHELD = new Map();

const declared = new Set();
const picklists = new Map();
const lengths = new Map();
for (const object of objects) {
  const directory = path.join(
    paths.forceApp,
    "main/default/objects",
    object,
    "fields"
  );
  for (const fileName of fs.readdirSync(directory).sort()) {
    if (!fileName.endsWith(".field-meta.xml")) continue;
    const field = fileName.replace(".field-meta.xml", "");
    declared.add(field);
    const fieldXml = fs.readFileSync(path.join(directory, fileName), "utf8");
    const values = picklistValues(fieldXml);
    if (values.length > 0) picklists.set(field, values);
    const limit = fieldLength(fieldXml);
    if (limit !== null) lengths.set(field, limit);
  }
}

const folder = path.join(paths.repoRoot, "docs/build-checks/draft-with-ai");
const pages = fs
  .readdirSync(folder)
  .filter((fileName) => fileName.endsWith(".md"))
  .sort()
  .map((fileName) => ({
    file: path.posix.join("docs/build-checks/draft-with-ai", fileName),
    text: fs.readFileSync(path.join(folder, fileName), "utf8")
  }));

if (pages.length === 0) {
  console.error(`No AI drafting pages found in ${folder}`);
  process.exit(1);
}

// Documented result reason codes read like stored values and appear in the
// prompts for a reason: an assistant that knows INVALID_APEX_PARAMETERS can
// explain the failure. They are not picklist values, so they are read from
// their own reference page rather than allowlisted by hand.
const reasonCodes = new Set(
  fs
    .readFileSync(
      path.join(paths.repoRoot, "docs/reference/results/reason-codes.md"),
      "utf8"
    )
    .match(/\b[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+\b/g) ?? []
);

// Object API names an administrator supplies from their own org. The pages use
// them in examples, and this repository cannot declare them.
const external = new Set(["Customer_Tier__c"]);

// The shared rules live once in `shared-rules.md` and are repeated verbatim in
// every type prompt, because an assistant that cannot open a link still needs
// them. Only the first fenced block on that page is the shared text.
const sharedPage = pages.find((page) => page.file.endsWith("shared-rules.md"));
const shared = promptBlock(sharedPage?.text ?? "");
if (!shared) {
  console.error("shared-rules.md has no ```text block to compare prompts with");
  process.exit(1);
}
const prompts = pages.filter((page) => /prompt-[a-z-]+\.md$/.test(page.file));

const problems = [
  ...sharedBlockDrift(shared, prompts),
  ...fieldNameProblems(pages, declared, external),
  ...picklistValueProblems(pages, picklists, reasonCodes),
  ...mergeSyntaxProblems(pages),
  ...currentContractProblems(pages),
  ...capabilityGaps(pages, [...declared], WITHHELD)
];

// A release must never regain a provider-specific credential or live-model
// requirement. Keep this policy on the user-facing and executable release
// surfaces; the gate itself remains an offline metadata-and-fixture validator.
const providerCredential = /\b[A-Z][A-Z0-9]*_API_KEY\b/;
const releaseSurfaces = [
  "package.json",
  ".github/RELEASING.md",
  ".github/workflows/salesforce-validate.yml",
  "docs/quality-gates/manual-release-owner-checklist.md",
  "tests/ai-drafts/README.md"
];
for (const file of releaseSurfaces) {
  const source = fs.readFileSync(path.join(paths.repoRoot, file), "utf8");
  if (providerCredential.test(source)) {
    problems.push(
      `${file} must not require a provider API key for AI prompt validation`
    );
  }
}

// Provider-neutral reference answers, one per Evaluation Type. They keep the
// prompt's required output contract executable without making a network call or
// requiring a vendor credential. Reviewers may try any assistant separately;
// release correctness depends only on these deterministic fixtures.
const draftsDirectory = path.join(paths.repoRoot, "tests/ai-drafts");
const schema = { declared, picklists, lengths };
const drafts = fs
  .readdirSync(draftsDirectory)
  .filter(
    (fileName) => fileName.startsWith("reference-") && fileName.endsWith(".md")
  )
  .sort();

const expectedDrafts = Object.keys(EVALUATION_TYPES).map(
  (type) => `reference-${type}.md`
);
for (const fileName of expectedDrafts) {
  if (!drafts.includes(fileName)) {
    problems.push(
      `Missing provider-neutral AI fixture tests/ai-drafts/${fileName}`
    );
  }
}
for (const fileName of drafts) {
  if (!expectedDrafts.includes(fileName)) {
    problems.push(
      `Unexpected provider-neutral AI fixture tests/ai-drafts/${fileName}`
    );
  }
}

const types = new Set();
for (const fileName of drafts) {
  const draft = fs.readFileSync(path.join(draftsDirectory, fileName), "utf8");
  const normalizedDraft = draft.replaceAll("\\_", "_");
  const fields = draftFields(draft);
  // `reference-<type>.md`, and the longest matching slug wins so that
  // "compare-two-queries" is not read as "queries".
  const slug = Object.keys(EVALUATION_TYPES)
    .filter((type) => fileName.endsWith(`-${type}.md`))
    .sort((a, b) => b.length - a.length)[0];
  if (fields.size === 0) {
    problems.push(
      `tests/ai-drafts/${fileName} has no readable Check table, so the prompt's ` +
        `required output format was not followed`
    );
    continue;
  }
  types.add(fields.get("EvaluationType__c"));
  // Mentioning a field, even to mark it N/A, is the assistant deciding about
  // it. Silence is the failure this looks for.
  const ignored = CROSS_CUTTING.filter(
    (field) => !normalizedDraft.includes(field)
  );
  if (ignored.length > 0) {
    problems.push(
      `tests/ai-drafts/${fileName} never considers ${ignored.join(", ")}`
    );
  }
  const unfilled = coverageGaps(fields);
  if (unfilled.length > 0) {
    problems.push(
      `tests/ai-drafts/${fileName} leaves ${unfilled.join(", ")} for the ` +
        `administrator to work out; the prompt must draft a usable value for ` +
        `every field this Evaluation Type reads`
    );
  }
  problems.push(
    ...draftProblems(fields, schema).map(
      (problem) => `tests/ai-drafts/${fileName}: ${problem}`
    ),
    // The requirement is the only place an administrator's own field names can
    // come from, so anything else the draft spells with __c was invented.
    ...(slug
      ? inventedNameProblems(
          normalizedDraft,
          fs.readFileSync(
            path.join(draftsDirectory, `requirement-${slug}.txt`),
            "utf8"
          ),
          declared
        ).map((problem) => `tests/ai-drafts/${fileName}: ${problem}`)
      : []),
    ...draftNarrativeProblems(draft, fields).map(
      (problem) => `tests/ai-drafts/${fileName}: ${problem}`
    )
  );
}
for (const type of Object.values(EVALUATION_TYPES)) {
  if (!types.has(type)) {
    problems.push(
      `No provider-neutral reference draft covers EvaluationType__c ${type}`
    );
  }
}

if (problems.length > 0) {
  console.error(
    "AI drafting prompts do not match the Check metadata:\n" +
      problems.map((problem) => `  ${problem}`).join("\n")
  );
  process.exit(1);
}

console.log(
  `Verified ${pages.length} AI drafting pages and ${drafts.length} provider-neutral ` +
    `reference drafts against ${declared.size} declared fields and ` +
    `${picklists.size} picklists without a live model or provider credential.`
);
