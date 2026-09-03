function job(workflow, name) {
  const marker = `  ${name}:\n`;
  const start = workflow.indexOf(marker);
  if (start < 0) throw new Error(`Missing quota-control job: ${name}`);
  const remainder = workflow.slice(start + marker.length);
  const next = remainder.search(/^  [a-z][a-z0-9-]*:/m);
  return next < 0 ? remainder : remainder.slice(0, next);
}

function requireText(text, expected) {
  if (!text.includes(expected))
    throw new Error(`Missing quota protection: ${expected}`);
}

export function assertReleaseQuotaPolicy(source, subscriber, workflows) {
  for (const workflow of [source, subscriber]) {
    const triggers = workflow.slice(
      workflow.indexOf("on:"),
      workflow.indexOf("permissions:")
    );
    requireText(triggers, "workflow_dispatch:");
    if (
      [...triggers.matchAll(/^  ([a-z_]+):/gm)].some(
        ([, event]) => event !== "workflow_dispatch"
      )
    ) {
      throw new Error("Org-consuming release workflows must be manual-only.");
    }
    const offline = job(workflow, "offline-preflight");
    requireText(offline, "npm run release:preflight");
    requireText(offline, "npx playwright install --with-deps chromium firefox");
    if (
      /sf org create|sf package version create|npm run package:create/.test(
        offline
      )
    ) {
      throw new Error(
        "No-org preflight must not consume Salesforce creation quota."
      );
    }
    requireText(
      job(workflow, "require-dev-hub-secret"),
      "needs: offline-preflight"
    );
    requireText(workflow, "group: salesforce-devhub-release");
    requireText(workflow, "cancel-in-progress: false");
  }
  requireText(job(source, "offline-preflight"), "sf code-analyzer run");
  requireText(
    job(source, "package-source-tests"),
    "needs: require-dev-hub-secret"
  );
  requireText(
    job(source, "portable-source-tests"),
    "needs: [require-dev-hub-secret, package-source-tests]"
  );
  requireText(
    job(source, "locker-browser-tests"),
    "needs: [require-dev-hub-secret, portable-source-tests]"
  );
  requireText(
    job(subscriber, "offline-preflight"),
    "npm run check:hosted-validation"
  );
  for (const [workflow, names] of [
    [source, ["locker-browser-tests"]],
    [subscriber, ["subscriber-clean-install", "subscriber-upgrade"]]
  ]) {
    for (const name of names) {
      const section = job(workflow, name);
      requireText(section, "max-parallel: 1");
      requireText(section, "fail-fast: true");
    }
  }
  for (const workflow of workflows) {
    if (
      /sf package version (create|promote)|npm run package:(create|promote)/.test(
        workflow
      )
    ) {
      throw new Error(
        "Package creation and promotion belong to the release owner, not GitHub workflows."
      );
    }
    if (
      /actions\/upload-artifact@v[1-5]\b/.test(workflow) ||
      workflow.includes("ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION")
    ) {
      throw new Error(
        "Do not restore deprecated artifact actions or opt into insecure Node runtimes."
      );
    }
  }
}
