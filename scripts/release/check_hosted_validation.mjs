#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { parseArgs } from "node:util";
import { paths } from "../lib/paths.mjs";

export function selectSuccessfulRun(runs, { commit, candidate = "" }) {
  return runs.find((run) => {
    if (run.head_sha !== commit || run.status !== "completed") return false;
    if (run.conclusion !== "success") return false;
    if (run.event !== "workflow_dispatch") return false;
    if (
      candidate &&
      String(run.display_title ?? "") !== `Subscriber validation · ${candidate}`
    ) {
      return false;
    }
    return true;
  });
}

function git(...args) {
  return execFileSync("git", args, {
    cwd: paths.repoRoot,
    encoding: "utf8"
  }).trim();
}

function repositorySlug() {
  const remote = git("remote", "get-url", "origin");
  const match = remote.match(/github\.com[/:]([^/]+)\/([^/.]+)(?:\.git)?$/);
  if (!match) {
    throw new Error(
      `Unable to resolve GitHub repository from origin: ${remote}`
    );
  }
  return `${match[1]}/${match[2]}`;
}

const { values } = parseArgs({
  options: {
    workflow: { type: "string", default: "salesforce-validate.yml" },
    commit: { type: "string" },
    candidate: { type: "string", default: "" },
    "self-test": { type: "boolean", default: false }
  }
});

if (values["self-test"]) {
  const selected = selectSuccessfulRun(
    [
      {
        id: 1,
        head_sha: "abc",
        status: "completed",
        conclusion: "failure",
        display_title: "Subscriber validation · 04tFAIL"
      },
      {
        id: 2,
        head_sha: "abc",
        status: "completed",
        conclusion: "success",
        event: "workflow_dispatch",
        display_title: "Subscriber validation · 04tPASS"
      }
    ],
    { commit: "abc", candidate: "04tPASS" }
  );
  if (selected?.id !== 2) {
    throw new Error("Hosted validation run selection self-test failed.");
  }
  if (
    selectSuccessfulRun(
      [
        {
          id: 3,
          head_sha: "other",
          status: "completed",
          conclusion: "success",
          event: "workflow_dispatch",
          display_title: "Subscriber validation · 04tPASS"
        }
      ],
      { commit: "abc", candidate: "04tPASS" }
    )
  ) {
    throw new Error("Hosted validation must reject a different commit.");
  }
  if (
    selectSuccessfulRun(
      [
        {
          id: 4,
          head_sha: "abc",
          status: "completed",
          conclusion: "success",
          event: "workflow_dispatch",
          display_title: "Subscriber validation · 04tPASS-extra"
        }
      ],
      { commit: "abc", candidate: "04tPASS" }
    )
  ) {
    throw new Error(
      "Hosted validation must require the exact candidate dispatch title."
    );
  }
  if (
    selectSuccessfulRun(
      [
        {
          id: 5,
          head_sha: "abc",
          status: "completed",
          conclusion: "success",
          event: "pull_request",
          display_title: "Subscriber validation · 04tPASS"
        }
      ],
      { commit: "abc", candidate: "04tPASS" }
    )
  ) {
    throw new Error(
      "Hosted validation must reject credential-skipped pull request runs."
    );
  }
  console.log("Hosted Salesforce validation selector self-test passed.");
  process.exit(0);
}

const commit = values.commit ?? git("rev-parse", "HEAD");
if (!/^[0-9a-f]{40}$/i.test(commit)) {
  throw new Error("--commit must be a full 40-character Git commit SHA.");
}
if (
  values.candidate &&
  !/^04t[0-9A-Za-z]{12}(?:[0-9A-Za-z]{3})?$/.test(values.candidate)
) {
  throw new Error("--candidate must be a 15- or 18-character 04t ID.");
}

const slug = repositorySlug();
const endpoint = new URL(
  `https://api.github.com/repos/${slug}/actions/workflows/${encodeURIComponent(values.workflow)}/runs`
);
endpoint.searchParams.set("head_sha", commit);
endpoint.searchParams.set("status", "completed");
endpoint.searchParams.set("per_page", "100");

const headers = {
  Accept: "application/vnd.github+json",
  "User-Agent": "record-health-check-release-gate",
  "X-GitHub-Api-Version": "2022-11-28"
};
const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;
if (token) headers.Authorization = `Bearer ${token}`;

const response = await fetch(endpoint, { headers });
if (!response.ok) {
  throw new Error(
    `Unable to verify hosted validation (${response.status} ${response.statusText}).`
  );
}
const payload = await response.json();
const selected = selectSuccessfulRun(payload.workflow_runs ?? [], {
  commit,
  candidate: values.candidate
});
if (!selected) {
  const binding = values.candidate ? ` and candidate ${values.candidate}` : "";
  throw new Error(
    `No successful completed ${values.workflow} run exists for commit ${commit}${binding}.`
  );
}

console.log(
  `Hosted Salesforce validation passed: ${values.workflow} run ${selected.id} for ${commit}.`
);
