#!/usr/bin/env node

/**
 * Records what the lowest-cost model returns from the AI drafting prompts, so
 * the release gate can hold the prompts to the model an administrator is most
 * likely to be using rather than to the model that wrote them.
 *
 * Each run saves the model's complete answer under `tests/ai-drafts` and
 * records, in `recorded.json`, which model answered and the fingerprint of the
 * exact prompt block it answered. `npm run check:ai-prompts` fails when a
 * prompt changes and its recording was not remade, which is what stops a
 * release from shipping evidence that describes an older prompt.
 *
 * Usage:
 *   ANTHROPIC_API_KEY=... node scripts/release/draft_with_model.mjs --all
 *   ANTHROPIC_API_KEY=... node scripts/release/draft_with_model.mjs \
 *     --type query --model <model id>
 *
 * `--all` records every Evaluation Type with the lowest-cost model, which is
 * what the release gate runs. `--model` records an additional model beside it;
 * the file name keeps each model's evidence separate.
 */

import fs from "node:fs";
import path from "node:path";
import { parseArgs } from "node:util";
import { paths } from "../lib/paths.mjs";
import {
  EVALUATION_TYPES,
  LOWEST_COST_MODEL,
  promptBlock,
  promptFingerprint
} from "../lib/ai-draft-validation.mjs";

const { values } = parseArgs({
  options: {
    all: { type: "boolean", default: false },
    type: { type: "string" },
    model: { type: "string", default: LOWEST_COST_MODEL }
  }
});

const types = values.all ? Object.keys(EVALUATION_TYPES) : [values.type];
if (types.some((type) => !(type in EVALUATION_TYPES))) {
  console.error(
    "Usage: ANTHROPIC_API_KEY=... node scripts/release/draft_with_model.mjs " +
      "--all | --type <" +
      Object.keys(EVALUATION_TYPES).join("|") +
      "> [--model <model id>]"
  );
  process.exit(1);
}

const key = process.env.ANTHROPIC_API_KEY;
if (!key) {
  console.error(
    "ANTHROPIC_API_KEY is not set. Recording what the lowest-cost model " +
      "returns is a live call to that model; there is no offline substitute " +
      "for it, because the point of the gate is what the model really does."
  );
  process.exit(1);
}

const drafts = path.join(paths.repoRoot, "tests/ai-drafts");
const manifestFile = path.join(drafts, "recorded.json");
const manifest = fs.existsSync(manifestFile)
  ? JSON.parse(fs.readFileSync(manifestFile, "utf8"))
  : { recordings: {} };

/**
 * Asks one model to answer one Evaluation Type's prompt.
 *
 * @param {string} type The Evaluation Type slug.
 * @returns {Promise<string>} The model's complete answer.
 */
async function draft(type) {
  const page = fs.readFileSync(
    path.join(
      paths.repoRoot,
      `docs/build-checks/draft-with-ai/prompt-${type}.md`
    ),
    "utf8"
  );
  const system = promptBlock(page);
  if (!system) throw new Error(`prompt-${type}.md has no prompt block`);
  const requirement = fs.readFileSync(
    path.join(drafts, `requirement-${type}.txt`),
    "utf8"
  );

  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": key,
      "anthropic-version": "2023-06-01"
    },
    body: JSON.stringify({
      model: values.model,
      max_tokens: 8000,
      system,
      messages: [{ role: "user", content: requirement }]
    })
  });
  if (!response.ok) {
    throw new Error(
      `${values.model} returned ${response.status}: ${await response.text()}`
    );
  }
  const body = await response.json();
  const answer = body.content
    .filter((block) => block.type === "text")
    .map((block) => block.text)
    .join("");

  const file = `${values.model.replace(/[^a-z0-9]+/gi, "-")}-${type}.md`;
  fs.writeFileSync(
    path.join(drafts, file),
    answer.endsWith("\n") ? answer : `${answer}\n`
  );
  manifest.recordings[type] = {
    file,
    model: values.model,
    promptSha256: promptFingerprint(system),
    recordedAt: new Date().toISOString().slice(0, 10)
  };
  return file;
}

for (const type of types) {
  console.log(`Recording ${type} with ${values.model}`);
  console.log(`  wrote tests/ai-drafts/${await draft(type)}`);
}

fs.writeFileSync(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Updated tests/ai-drafts/recorded.json`);
