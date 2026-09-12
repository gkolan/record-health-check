export const AGENTFORCE_TEST_RUNNER = "testing-center";

/**
 * Validates the required structure of the legacy Agentforce DX YAML test spec.
 * This deliberately checks the repository-owned contract without pretending to
 * replace Salesforce's org-aware `sf agent test create --preview` validation.
 */
export function validateLegacyAgentTestSpec(source) {
  const failures = [];
  for (const field of ["name", "subjectType", "subjectName", "testCases"]) {
    if (!new RegExp(`^${field}:`, "m").test(source)) {
      failures.push(`top-level ${field} is required`);
    }
  }
  if (!/^subjectType:\s*AGENT\s*$/m.test(source)) {
    failures.push("subjectType must be AGENT");
  }

  const starts = [...source.matchAll(/^ {2}- utterance:/gm)].map(
    (match) => match.index
  );
  if (starts.length === 0) failures.push("at least one test case is required");
  for (let index = 0; index < starts.length; index += 1) {
    const block = source.slice(starts[index], starts[index + 1]);
    const missing = [];
    if (!/^ {4}expectedTopic:\s*\S+/m.test(block)) {
      missing.push("expectedTopic");
    }
    const actions = block.match(/^ {4}expectedActions:\s*(.*)$/m);
    if (
      !actions ||
      (!actions[1].trim().startsWith("[") && !/^ {6}-\s+\S+/m.test(block))
    ) {
      missing.push("expectedActions");
    }
    if (!/^ {4}expectedOutcome:\s*\S+/m.test(block)) {
      missing.push("expectedOutcome");
    }
    if (missing.length > 0) {
      failures.push(`case ${index + 1} is missing ${missing.join(", ")}`);
    }
  }
  if (failures.length > 0) {
    throw new Error(
      `Invalid Agentforce ${AGENTFORCE_TEST_RUNNER} spec:\n${failures.join("\n")}`
    );
  }
  return { caseCount: starts.length, runner: AGENTFORCE_TEST_RUNNER };
}
