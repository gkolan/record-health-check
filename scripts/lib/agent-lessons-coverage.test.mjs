import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

/*
 * Every lesson in docs/quality-gates/agent-lessons.md names at least one
 * positive guard (the correct behavior passes) and one negative guard (the
 * recurrence fails). Each entry is [repository path, exact test identifier].
 * Apex entries pin presence only; Salesforce execution remains separate.
 */
const classes = "packages/record-health-check/force-app/main/default/classes";
const integrationClasses =
  "packages/record-health-check/integration-tests/main/default/classes";
const card =
  "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/__tests__/recordHealthCheck.test.js";
const lib = "scripts/lib";

const lessonGuards = {
  1: {
    positive: [
      [
        `${classes}/RecordHealthCheckConfigValidationTest.cls`,
        "checkSetValidationAcceptsTheUnchangedBaseline"
      ],
      [
        `${classes}/RecordHealthCheckConfigValidationTest.cls`,
        "checkValidationAcceptsEachUnchangedBaselineCheck"
      ],
      [
        `${classes}/RecordHealthCheckDefinitionLoaderTest.cls`,
        "acceptsEveryReachableHeadingAndRunModeAtDefinitionBoundary"
      ],
      [
        `${classes}/RHCMetadataSetValidatorTest.cls`,
        "acceptsDefaultAndExactCardHeadingDisplays"
      ]
    ],
    negative: [
      [
        `${classes}/RecordHealthCheckConfigValidationTest.cls`,
        "checkSetValidationRejectsEveryInvalidSetting"
      ],
      [
        `${classes}/RecordHealthCheckDefinitionLoaderTest.cls`,
        "rejectsHiddenManualHeadingForEveryButtonStyleAtDefinitionBoundary"
      ],
      [
        `${classes}/RecordHealthCheckDefinitionLoaderTest.cls`,
        "retainsRunButtonValidationPrecedence"
      ],
      [
        `${classes}/RHCMetadataSetValidatorTest.cls`,
        "reportsRunButtonIssueBeforeHeadingIssue"
      ]
    ]
  },
  2: {
    positive: [
      [
        `${classes}/RecordHealthCheckControllerErrorTest.cls`,
        "getCheckDefinitionsCarriesVerifiedAdministratorEntitlement"
      ],
      [
        card,
        "shows exact invalid configuration only when detail entitlement is %s"
      ]
    ],
    negative: [
      [
        `${classes}/RecordHealthCheckControllerErrorTest.cls`,
        "getCheckDefinitionsWrapsConfigErrorsForAura"
      ],
      [card, "redacts technical component details for regular users"]
    ]
  },
  3: {
    positive: [
      [
        `${classes}/RHCMetadataSetValidatorTest.cls`,
        "doesNotWarnWhenUserRunPublicationIsReachable"
      ],
      [
        card,
        "keeps a page-load hidden heading valid without an action row for %s"
      ],
      [
        `${integrationClasses}/RHCCardHeadingTest.cls`,
        "headingModesPreserveIndependentPassAndFailOutcomes"
      ]
    ],
    negative: [
      [
        `${classes}/RHCMetadataSetValidatorTest.cls`,
        "warnsWhenHiddenAutomaticHeadingCannotPublishFromCard"
      ],
      [
        `${classes}/RHCMetadataSetValidatorTest.cls`,
        "rejectsHiddenManualHeadingForEveryButtonStyle"
      ],
      [card, "rejects a hidden Manual heading in a definition response for %s"],
      [
        `${integrationClasses}/RHCCardHeadingTest.cls`,
        "hiddenManualHeadingConfigurationsFailBeforeEvaluation"
      ]
    ]
  },
  4: {
    positive: [
      [
        card,
        "retains administrator detail when the response omits its Check collection"
      ],
      [card, "recovers after a hidden Manual heading is corrected to page-load"]
    ],
    negative: [
      [
        card,
        "shows client-rejected %s definition detail only when entitlement is exactly %p"
      ],
      [
        card,
        "surfaces an error instead of evaluating stale definitions when the refetch fails"
      ]
    ]
  },
  5: {
    positive: [
      [
        `${lib}/apex-test-inventory.test.mjs`,
        "accepts an exact, passing Salesforce result"
      ]
    ],
    negative: [
      [
        `${lib}/apex-test-inventory.test.mjs`,
        "fails when the org runs a test class that source no longer contains"
      ]
    ]
  },
  6: {
    positive: [
      [
        `${lib}/apex-test-inventory.test.mjs`,
        "reconciles TestSetup methods counted only in Salesforce summary"
      ],
      [
        `${lib}/apex-test-inventory.test.mjs`,
        "accepts a clean zero exit and returns the verified result unchanged"
      ]
    ],
    negative: [
      [
        `${lib}/apex-test-inventory.test.mjs`,
        "fails when Salesforce omits an inventoried class"
      ],
      [
        `${lib}/apex-test-inventory.test.mjs`,
        "each failure signal rejects the run on its own"
      ],
      [
        `${lib}/apex-test-inventory.test.mjs`,
        "a declared TestSetup method missing from Salesforce's count fails"
      ],
      [
        `${lib}/apex-test-inventory.test.mjs`,
        "rejects Salesforce CLI transport failures and every nonzero exit"
      ]
    ]
  },
  7: {
    positive: [
      [
        `${lib}/code-analyzer-integrity.test.mjs`,
        "accepts complete reports with clean engine logs"
      ],
      [
        `${lib}/code-analyzer-integrity.test.mjs`,
        "each blocking scan step checks integrity of every JSON report it writes"
      ],
      [
        `${lib}/toolchain-policy.test.mjs`,
        "tracked workflows match the toolchain policy"
      ],
      [
        `${lib}/code-analyzer-suppressions.test.mjs`,
        "accepts the exact tracked security suppression allowlist"
      ]
    ],
    negative: [
      [
        `${lib}/code-analyzer-integrity.test.mjs`,
        "rejects each scanner false-green engine signature on its own"
      ],
      [
        `${lib}/code-analyzer-integrity.test.mjs`,
        "rejects a scan whose engine log directory is absent"
      ],
      [
        `${lib}/toolchain-policy.test.mjs`,
        "a drifted or removed analyzer pin in any scanning workflow is rejected"
      ],
      [
        `${lib}/toolchain-policy.test.mjs`,
        "one stale Salesforce CLI pin beside a current one is rejected"
      ],
      [
        `${lib}/code-analyzer-suppressions.test.mjs`,
        "rejects a widened limit or globally disabled security rule"
      ]
    ]
  },
  8: {
    positive: [
      [
        "tests/url-story-verifier.test.mjs",
        "accepts the exact matrix, structured lines, and PASS-FAIL-PASS transition"
      ],
      [
        "scripts/release/capture_query_verdicts.py",
        'assert indexed["Alpha"]["status"] == "PASS"'
      ]
    ],
    negative: [
      [
        "tests/url-story-verifier.test.mjs",
        "rejects a duplicated candidate result even when the count matches"
      ],
      [
        "tests/url-story-verifier.test.mjs",
        "rejects a missing or extra baseline result"
      ],
      [
        `${lib}/query-verdict-launchers.test.mjs`,
        "verdict capture indexes one smoke row per Check and rejects duplicates"
      ]
    ]
  },
  9: {
    positive: [
      [
        `${lib}/browser-evidence.test.mjs`,
        "redacts retained failure-context Markdown and leaves clean context unchanged"
      ],
      [
        `${lib}/salesforce-first-login.test.mjs`,
        "acknowledges Salesforce maintenance notice in a frame before password setup"
      ],
      [
        `${lib}/salesforce-first-login.test.mjs`,
        "retries a maintenance frame that detaches during redirect"
      ],
      [
        `${lib}/salesforce-browser-errors.test.mjs`,
        "accepts the known Firefox App Builder shell error across numeric Salesforce asset shards"
      ],
      [
        `${lib}/browser-lifecycle.test.mjs`,
        "counts every page-load evaluation in a finished Aura request"
      ]
    ],
    negative: [
      [
        `${lib}/browser-evidence.test.mjs`,
        "browser evidence rejects empty, skipped, flaky, and failed runs"
      ],
      [
        `${lib}/browser-evidence.test.mjs`,
        "every browser runner that retains Playwright output redacts its Markdown"
      ],
      [
        `${lib}/salesforce-first-login.test.mjs`,
        "leaves pages alone when no maintenance notice is visible"
      ],
      [
        `${lib}/salesforce-first-login.test.mjs`,
        "a frame error other than a redirect detach still fails setup"
      ],
      [
        `${lib}/salesforce-browser-errors.test.mjs`,
        "rejects each single departure from the known shell-error shape"
      ],
      [
        `${lib}/browser-lifecycle.test.mjs`,
        "generic Aura traffic and user runs are not refresh evidence"
      ]
    ]
  },
  10: {
    positive: [
      [
        `${lib}/release-gates.test.mjs`,
        "CI runs the single gate declaration, not a second remembered list"
      ],
      [
        `${lib}/version-sync.test.mjs`,
        "accepts a bumped version and a same-version hotfix build"
      ]
    ],
    negative: [
      [
        `${lib}/release-gates.test.mjs`,
        "a name that is only a prefix of real gates is rejected"
      ],
      [
        `${lib}/version-sync.test.mjs`,
        "a development version below a released version is rejected"
      ],
      [
        `${lib}/version-sync.test.mjs`,
        "each unsynchronized version source is rejected on its own"
      ]
    ]
  }
};

function lessonCoverageErrors(lessonsMarkdown, guards, readFile) {
  const errors = [];
  const lessons = [...lessonsMarkdown.matchAll(/^## Lesson (\d+):/gm)].map(
    (match) => match[1]
  );
  for (const lesson of lessons) {
    for (const polarity of ["positive", "negative"]) {
      if (!(guards[lesson]?.[polarity]?.length > 0)) {
        errors.push(`Lesson ${lesson} has no ${polarity} guard.`);
      }
    }
  }
  for (const lesson of Object.keys(guards)) {
    if (!lessons.includes(lesson)) {
      errors.push(`Lesson ${lesson} is mapped but not in the lessons guide.`);
    }
  }
  for (const [lesson, polarities] of Object.entries(guards)) {
    for (const [file, name] of Object.values(polarities).flat()) {
      const source = readFile(file);
      if (source === null) {
        errors.push(`Lesson ${lesson}: ${file} is missing.`);
      } else if (!source.includes(name)) {
        errors.push(`Lesson ${lesson}: ${file} no longer contains "${name}".`);
      }
    }
  }
  return errors;
}

const readRepositoryFile = (file) =>
  fs.existsSync(file) ? fs.readFileSync(file, "utf8") : null;
const lessonsGuide = fs.readFileSync(
  "docs/quality-gates/agent-lessons.md",
  "utf8"
);

test("every agent lesson keeps a positive and a negative guard", () => {
  assert.deepEqual(
    lessonCoverageErrors(lessonsGuide, lessonGuards, readRepositoryFile),
    []
  );
});

test("a lesson without a negative guard, a new lesson, or a removed guard fails", () => {
  const withoutNegative = structuredClone(lessonGuards);
  withoutNegative[5].negative = [];
  assert.deepEqual(
    lessonCoverageErrors(lessonsGuide, withoutNegative, readRepositoryFile),
    ["Lesson 5 has no negative guard."]
  );

  assert.deepEqual(
    lessonCoverageErrors(
      `${lessonsGuide}\n## Lesson 11: An unguarded lesson\n`,
      lessonGuards,
      readRepositoryFile
    ),
    ["Lesson 11 has no positive guard.", "Lesson 11 has no negative guard."]
  );

  const [file, name] = lessonGuards[8].negative[0];
  assert.deepEqual(
    lessonCoverageErrors(lessonsGuide, lessonGuards, (path) =>
      path === file
        ? readRepositoryFile(path).replaceAll(name, "renamed")
        : readRepositoryFile(path)
    ),
    [`Lesson 8: ${file} no longer contains "${name}".`]
  );
});
