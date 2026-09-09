import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import {
  assertExplicitScratchDevHub,
  assertReleaseQuotaPolicy
} from "./release-quota-policy.mjs";

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
const contributorSetup = fs.readFileSync(
  new URL("../contributor/setup.mjs", import.meta.url),
  "utf8"
);
const portableSetup = fs.readFileSync(
  new URL("../contributor/test-no-namespace.mjs", import.meta.url),
  "utf8"
);
const subscriberSetup = fs.readFileSync(
  new URL("../subscriber/setup.mjs", import.meta.url),
  "utf8"
);
const packageVerifier = fs.readFileSync(
  new URL("../release/verify-package-version.mjs", import.meta.url),
  "utf8"
);
const releaseOwnerChecklist = fs.readFileSync(
  new URL(
    "../../docs/quality-gates/manual-release-owner-checklist.md",
    import.meta.url
  ),
  "utf8"
);
const lifecycleGuide = fs.readFileSync(
  new URL("../../docs/quality-gates/scratch-org-lifecycle.md", import.meta.url),
  "utf8"
);

function releaseOrgPolicy() {
  return JSON.parse(
    fs.readFileSync(
      new URL("../../config/release-org-policy.json", import.meta.url),
      "utf8"
    )
  );
}

test("release scratch orgs use a rolling two-version LWS and Locker window", () => {
  const policy = releaseOrgPolicy();
  assert.equal(policy.scratchOrgsPerRelease, 2);
  assert.deepEqual(policy.securityModes, ["LWS", "Locker"]);
  assert.equal(policy.retainedReleasePairs, 2);
  assert.equal(policy.retireReleaseOffset, 2);
  assert.equal(policy.maximumLifetimeDays, 30);
  assert.match(lifecycleGuide, /2\.0\.11.*delete.*2\.0\.9/is);
  assert.match(lifecycleGuide, /four retained scratch orgs/i);
  assert.match(source, /name: Salesforce source validation \(non-release\)/);
  assert.match(subscriber, /--release-pair/);
  assert.match(subscriber, /--keep-org/);
  assert.doesNotMatch(subscriber, /validation_stage:/);
  assert.equal(
    [...subscriber.matchAll(/security_mode: (?:LWS|Locker)/g)].length,
    2
  );
  assert.equal(
    [...subscriber.matchAll(/npm run package:verify --/g)].length,
    1
  );
  assert.doesNotMatch(subscriber, /sf org delete scratch/);
  assert.match(packageVerifier, /function resetReleasePairForUpgrade/);
  assert.match(packageVerifier, /function assertReleasePairSlotAvailable/);
  assert.match(packageVerifier, /Two release pairs are already retained/);
  assert.match(packageVerifier, /"package",\s*"uninstall"/);
  assert.ok(
    packageVerifier.indexOf("Clean subscriber install gate passed.") <
      packageVerifier.lastIndexOf(
        "resetReleasePairForUpgrade(alias, candidateId)"
      )
  );
});

test("local scratch org defaults are short and can be selected explicitly", () => {
  assert.match(contributorSetup, /durationDays: "7"/);
  assert.match(contributorSetup, /token === "--duration-days"/);
  assert.match(portableSetup, /durationDays: "1"/);
  assert.match(portableSetup, /token === "--duration-days"/);
  assert.match(subscriberSetup, /process\.env\.RHC_SCRATCH_DAYS \?\? "7"/);
  assert.equal(
    [...packageVerifier.matchAll(/"--duration-days",\s*"1"/g)].length,
    1
  );
  assert.match(packageVerifier, /values\["release-pair"\] \? "30" : "1"/);
  assert.match(packageVerifier, /process\.once\("exit"/);
  assert.match(packageVerifier, /for \(const \[signal, exitCode\]/);
});

test("every direct scratch creation explicitly selects the authenticated Dev Hub", () => {
  const creations = [...source.matchAll(/sf org create scratch[^\n]*/g)];
  assert.equal(creations.length, 2);
  for (const [command] of creations) {
    const broken = source.replace(
      command,
      command.replace(" --target-dev-hub devhub", "")
    );
    assert.notEqual(broken, source);
    assert.throws(
      () => assertReleaseQuotaPolicy(broken, subscriber, workflows),
      /explicitly select --target-dev-hub devhub/
    );
  }
  for (const args of [
    "",
    "--set-default",
    "--target-dev-hub",
    "--target-dev-hub other",
    "--target-dev-hub devhub-other"
  ]) {
    assert.throws(() =>
      assertExplicitScratchDevHub([`run: sf org create scratch ${args}`])
    );
  }
  assert.doesNotThrow(() =>
    assertExplicitScratchDevHub([
      'run: sf org create scratch \\\n  --target-dev-hub "devhub" --wait 15'
    ])
  );
});

test("release workflows require owner authorization before scratch-org creation", () => {
  assert.doesNotThrow(() =>
    assertReleaseQuotaPolicy(source, subscriber, workflows)
  );
  assert.doesNotMatch(source, /[A-Z][A-Z0-9]+_API_KEY|model-drafts/);
  assert.doesNotMatch(source, /--no-namespace|portable-source-tests/);
  assert.match(
    source,
    /check:scratch-capacity -- --dev-hub devhub --required 2/
  );
  for (const workflow of [source, subscriber]) {
    assert.match(workflow, /authorize_scratch_org_creation:/);
    assert.match(
      workflow,
      /if: inputs\.authorize_scratch_org_creation != true/
    );
  }
  for (const command of source.matchAll(/sf org create scratch[^\n]*/g)) {
    assert.match(command[0], /--duration-days 1/);
  }
  assert.equal([...source.matchAll(/sf org delete scratch[^\n]*/g)].length, 2);
  for (const broken of [
    source.replace("on:\n", "on:\n  pull_request:\n"),
    source.replace("on:\n", "on:\n  repository_dispatch:\n"),
    source.replace("authorize_scratch_org_creation:", "authorization_removed:"),
    source.replace(
      "if: inputs.authorize_scratch_org_creation != true",
      "if: false"
    ),
    source.replace("needs: offline-preflight", "needs: something-else"),
    source.replace(
      "needs: [require-dev-hub-secret, package-source-tests]",
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

test("release-owner instructions make scratch-org workflows optional and authorized", () => {
  assert.match(
    releaseOwnerChecklist,
    /Scratch-org workflows are optional release evidence/
  );
  assert.match(releaseOwnerChecklist, /authorize_scratch_org_creation.*true/s);
  assert.doesNotMatch(
    releaseOwnerChecklist,
    /full\nrelease needs eight scratch-org creations|four-org source matrix|ten scratch-org creations/
  );
});
