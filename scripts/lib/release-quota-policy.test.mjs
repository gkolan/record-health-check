import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import { assertReleaseQuotaPolicy } from "./release-quota-policy.mjs";

const directory = new URL("../../.github/workflows/", import.meta.url);
const source = fs.readFileSync(
  new URL("salesforce-validate.yml", directory),
  "utf8"
);
const subscriber = fs.readFileSync(
  new URL("subscriber-validate.yml", directory),
  "utf8"
);
const workflows = fs
  .readdirSync(directory)
  .filter((file) => /\.ya?ml$/.test(file))
  .map((file) => fs.readFileSync(new URL(file, directory), "utf8"));

test("release workflows protect quota before starting fresh-org validation", () => {
  assert.doesNotThrow(() =>
    assertReleaseQuotaPolicy(source, subscriber, workflows)
  );
  for (const broken of [
    source.replace("on:\n", "on:\n  pull_request:\n"),
    source.replace("on:\n", "on:\n  repository_dispatch:\n"),
    source.replace("needs: offline-preflight", "needs: something-else"),
    source.replace(
      "needs: [require-dev-hub-secret, portable-source-tests]",
      "needs: require-dev-hub-secret"
    ),
    source.replace("max-parallel: 1", "max-parallel: 2"),
    source.replace("fail-fast: true", "fail-fast: false"),
    source.replace(
      "run: npm run release:preflight",
      "run: sf org create scratch"
    )
  ])
    assert.throws(() =>
      assertReleaseQuotaPolicy(broken, subscriber, workflows)
    );
  assert.throws(() =>
    assertReleaseQuotaPolicy(
      source,
      subscriber.replace("npm run check:hosted-validation", "echo skip"),
      workflows
    )
  );
  for (const unsafe of [
    "run: sf package version create",
    "run: npm run package:promote",
    "uses: actions/upload-artifact@v4",
    "env: ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true"
  ]) {
    assert.throws(() =>
      assertReleaseQuotaPolicy(source, subscriber, [...workflows, unsafe])
    );
  }
});
