const ANALYZER_WORKFLOWS = [
  ".github/workflows/ci.yml",
  ".github/workflows/salesforce-validate.yml"
];

function pinErrors(workflow, source, pattern, expected, label, required) {
  const found = [...source.matchAll(pattern)].map((match) => match[1]);
  if (found.length === 0) {
    return required ? [`${workflow} must install ${label}@${expected}.`] : [];
  }
  const stale = [...new Set(found.filter((value) => value !== expected))];
  return stale.length === 0
    ? []
    : [
        `${workflow} must install only ${label}@${expected}; found ${stale.join(", ")}.`
      ];
}

/**
 * Returns toolchain-policy violations for workflow sources keyed by
 * repository-relative path. Every pin must match; one current pin does not
 * excuse a stale one in another job.
 */
export function toolchainWorkflowErrors(policy, workflows) {
  const errors = [];
  for (const [workflow, source] of Object.entries(workflows)) {
    errors.push(
      ...pinErrors(
        workflow,
        source,
        /@salesforce\/cli@([^\s"']+)/g,
        policy.salesforceCli,
        "@salesforce/cli",
        true
      ),
      ...pinErrors(
        workflow,
        source,
        /code-analyzer@([^\s"']+)/g,
        policy.codeAnalyzerPlugin,
        "code-analyzer",
        ANALYZER_WORKFLOWS.includes(workflow)
      )
    );
    const nodeMajors = [...source.matchAll(/node-version:\s*(\S+)/g)].map(
      (match) => match[1]
    );
    const staleNode = [
      ...new Set(
        nodeMajors.filter((major) => major !== String(policy.nodeMajor))
      )
    ];
    if (nodeMajors.length === 0) {
      errors.push(`${workflow} must use Node.js ${policy.nodeMajor}.`);
    } else if (staleNode.length > 0) {
      errors.push(
        `${workflow} must use only Node.js ${policy.nodeMajor}; found ${staleNode.join(", ")}.`
      );
    }
  }
  return errors;
}
