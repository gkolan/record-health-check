export function hostedEvidenceContract(candidate = "", stage = "") {
  if (!candidate)
    return {
      jobs: [
        "offline-preflight",
        "require-dev-hub-secret",
        "package-source-tests",
        "locker-browser-tests (namespaced)"
      ],
      artifacts: [
        "code-analyzer-evidence",
        "apex-inventory-namespaced-package",
        "apex-inventory-namespaced-full",
        "browser-evidence-namespaced-lws",
        "browser-evidence-namespaced-locker"
      ]
    };
  if (stage !== "release-pair")
    throw new Error("Subscriber evidence requires the release-pair stage.");
  return {
    jobs: [
      "offline-preflight",
      "require-dev-hub-secret",
      ...["LWS", "Locker"].map((mode) => `subscriber-release-pair (${mode})`)
    ],
    artifacts: ["lws", "locker"].flatMap((mode) => [
      `subscriber-release-pair-browser-${mode}-${candidate}`,
      `subscriber-release-pair-apex-${mode}-${candidate}`,
      `subscriber-release-pair-preservation-${mode}-${candidate}`
    ])
  };
}

export function assertHostedEvidence(run, jobs, artifacts, contract) {
  for (const name of contract.jobs) {
    const matches = jobs.filter((job) => job.name === name);
    if (
      matches.length !== 1 ||
      matches[0].status !== "completed" ||
      matches[0].conclusion !== "success"
    ) {
      throw new Error(
        `Required hosted job did not execute successfully: ${name}`
      );
    }
  }
  for (const name of contract.artifacts) {
    const matches = artifacts.filter(
      (artifact) =>
        artifact.name === name &&
        !artifact.expired &&
        artifact.size_in_bytes > 0 &&
        Date.parse(artifact.expires_at) > Date.now() &&
        Date.parse(artifact.created_at) >= Date.parse(run.run_started_at) &&
        (!artifact.workflow_run?.head_sha ||
          artifact.workflow_run.head_sha === run.head_sha)
    );
    if (matches.length !== 1)
      throw new Error(
        `Required current-attempt artifact is missing, expired, empty, or ambiguous: ${name}`
      );
  }
}
