export const acceptanceScenarios = [
  "cpq-quote-lifecycle",
  "existing-page-and-access-preservation",
  "four-type-business-outcomes",
  "existing-automation",
  "configuration-recovery"
];

export function assertReleaseAcceptance(evidence, candidate, commit) {
  if (
    evidence?.subscriberPackageVersionId !== candidate ||
    evidence?.gitCommit !== commit ||
    typeof evidence.verifiedBy !== "string" ||
    !evidence.verifiedBy.trim() ||
    !Number.isFinite(Date.parse(evidence.verifiedAt)) ||
    Date.parse(evidence.verifiedAt) > Date.now() ||
    Date.now() - Date.parse(evidence.verifiedAt) > 90 * 24 * 60 * 60 * 1000
  ) {
    throw new Error(
      "Release acceptance must identify the exact candidate, commit, reviewer, and recent verification date."
    );
  }
  for (const scenario of acceptanceScenarios) {
    const result = evidence.scenarios?.[scenario];
    if (
      result?.status !== "pass" ||
      typeof result.evidence !== "string" ||
      !result.evidence.trim()
    ) {
      throw new Error(
        `Representative-sandbox acceptance is incomplete: ${scenario}`
      );
    }
  }
}
