import assert from "node:assert/strict";

function key(recordName, checkDeveloperName) {
  return `${recordName}\u0000${checkDeveloperName}`;
}

function countStatuses(results) {
  const counts = { pass: 0, fail: 0, skip: 0, unable: 0, systemError: 0 };
  for (const result of results) {
    if (result.status === "PASS") counts.pass += 1;
    else if (result.status === "FAIL") counts.fail += 1;
    else if (result.status === "SKIPPED") counts.skip += 1;
    else if (result.status === "UNABLE_TO_EVALUATE") counts.unable += 1;
    else counts.systemError += 1;
  }
  return counts;
}

function assertDisplayCase(displayCase, actual) {
  assert.ok(
    actual,
    `missing display evidence for ${displayCase.record}/${displayCase.check}`
  );
  if (Object.hasOwn(displayCase, "foundText")) {
    assert.equal(actual.display?.foundDisplayValue, displayCase.foundText);
  }
  if (displayCase.structured === false) {
    const foundNodes = actual.display?.displayContent?.found ?? [];
    assert.equal(
      foundNodes.some((node) => node.kind === "link"),
      false,
      `${displayCase.check} must not acquire automatic links`
    );
    assert.equal(
      foundNodes
        .map((node) => (node.kind === "break" ? "\n" : (node.text ?? "")))
        .join(""),
      displayCase.foundText,
      `${displayCase.check} must preserve its original newline-separated text`
    );
  }
  const sections = actual.display?.displayContent;
  if (displayCase.guideKind) {
    const nodes = Object.values(sections ?? {}).flatMap((value) =>
      Array.isArray(value) ? value : []
    );
    const guide = nodes.find(
      (node) =>
        node.kind === displayCase.guideKind &&
        (displayCase.guideKind === "link"
          ? node.text === "Approval guide"
          : node.text?.includes("Approval guide"))
    );
    assert.ok(
      guide,
      `${displayCase.record} must retain the Approval guide label`
    );
    assert.equal(guide.kind, displayCase.guideKind);
    if (displayCase.guideKind === "link") {
      assert.match(guide.href, /^https:\/\//);
    } else {
      assert.equal(guide.href ?? null, null);
      assert.ok(
        nodes.some((node) => node.kind === "link"),
        `${displayCase.record} must preserve unrelated valid links`
      );
    }
  }
  if (displayCase.groupedLinks) {
    const nodes = sections?.found ?? [];
    const links = nodes.filter((node) => node.kind === "link");
    const breaks = nodes.filter((node) => node.kind === "break");
    assert.equal(
      links.length,
      9,
      "grouped display must contain exactly nine links"
    );
    assert.equal(
      breaks.length,
      2,
      "grouped display must contain exactly two breaks"
    );
    const lines = [[]];
    for (const node of nodes) {
      if (node.kind === "break") lines.push([]);
      else lines.at(-1).push(node);
    }
    assert.deepEqual(
      lines.map((line) => line.filter((node) => node.kind === "link").length),
      [2, 3, 4],
      "Step lines must contain one Step link plus one, two, and three User links"
    );
    assert.deepEqual(
      lines.map((line) => line[0]?.text),
      ["Step 1", "Step 2", "Step 3"],
      "Each painted line must begin with its linked Step label"
    );
  }
}

export function assertUrlStoryEvidence(matrix, evidence) {
  assert.equal(evidence.checkSetDeveloperName, matrix.checkSet);
  const expectedCount = matrix.records.length * matrix.checks.length;
  assert.equal(
    evidence.baseline.length,
    expectedCount,
    `baseline result count must be exactly ${expectedCount}`
  );

  const actualByKey = new Map();
  for (const result of evidence.baseline) {
    const resultKey = key(result.recordName, result.checkDeveloperName);
    assert.equal(
      actualByKey.has(resultKey),
      false,
      `duplicate baseline result ${resultKey}`
    );
    actualByKey.set(resultKey, result);
  }

  for (const record of matrix.records) {
    const recordResults = [];
    for (const check of matrix.checks) {
      const result = actualByKey.get(key(record.name, check));
      assert.ok(result, `missing baseline result for ${record.name}/${check}`);
      assert.equal(
        result.status,
        record.status,
        `${record.name}/${check} status`
      );
      assert.equal(
        result.reasonCode ?? null,
        record.reasons?.[check] ?? null,
        `${record.name}/${check} reason`
      );
      recordResults.push(result);
    }
    assert.deepEqual(
      countStatuses(recordResults),
      record.summary,
      `${record.name} summary`
    );
  }

  const displayByKey = new Map(
    evidence.displays.map((item) => [
      key(item.evaluation.recordName, item.evaluation.checkDeveloperName),
      item
    ])
  );
  for (const displayCase of matrix.displayCases ?? []) {
    assertDisplayCase(
      displayCase,
      displayByKey.get(key(displayCase.record, displayCase.check))
    );
  }

  assert.equal(
    evidence.transition.length,
    3,
    "transition phases must contain three runs"
  );
  assert.deepEqual(
    evidence.transition.map((phase) => phase.phase),
    ["before", "changed", "restored"],
    "transition phases must run in order"
  );
  assert.deepEqual(
    evidence.transition.map((phase) => [...new Set(phase.statuses)]),
    matrix.transition.statuses.map((status) => [status]),
    `${matrix.transition.record} must move PASS to FAIL and back to PASS`
  );
  for (const phase of evidence.transition) {
    assert.equal(
      phase.statuses.length,
      matrix.checks.length,
      `${phase.phase} transition run must return every Check`
    );
  }
}
