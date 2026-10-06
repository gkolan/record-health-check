import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { paths } from "./paths.mjs";
import {
  planReleasePairReset,
  writeReleasePairResetDeploy
} from "./release-pair-reset.mjs";

// Each expectation below is a Salesforce rejection observed on 2026-10-06 when
// the former reset deployed the CLI-generated destroy manifest.

test("never deletes a standard object; resets its record-page override instead", () => {
  const plan = planReleasePairReset(paths.subscriberApp);
  const destroyed = [
    ...Object.values(plan.pre),
    ...Object.values(plan.post)
  ].flat();
  assert.ok(!destroyed.includes("Account"));
  assert.ok(!("CustomObject" in plan.post));
  assert.deepEqual(plan.overrideResets, [
    {
      object: "Account",
      actions: [{ actionName: "View", formFactor: "Large" }]
    }
  ]);
  assert.ok(
    plan.post.FlexiPage.includes("RHCSubscriberReleaseMatrixRecordPage")
  );
});

test("deletes Checks before the Check Sets they reference", () => {
  const plan = planReleasePairReset(paths.subscriberApp);
  assert.ok(
    plan.pre.CustomMetadata.includes(
      "rhc__Record_Health_Check.Subscriber_On_Load_Apex"
    )
  );
  assert.ok(
    plan.pre.CustomMetadata.every((name) =>
      name.startsWith("rhc__Record_Health_Check.")
    )
  );
  assert.ok(
    plan.post.CustomMetadata.includes(
      "rhc__Record_Health_Check_Set.Subscriber_On_Load"
    )
  );
  assert.ok(
    plan.post.CustomMetadata.every((name) =>
      name.startsWith("rhc__Record_Health_Check_Set.")
    )
  );
});

test("deactivates Flows instead of deleting them through the metadata deploy", () => {
  const plan = planReleasePairReset(paths.subscriberApp);
  assert.deepEqual(plan.flows, ["RHC_Subscriber_Release_Matrix"]);
  assert.ok(!("Flow" in plan.post));
});

test("writes a deploy that passes the destructive manifests and an override reset", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "rhc-reset-test-"));
  try {
    writeReleasePairResetDeploy(
      planReleasePairReset(paths.subscriberApp),
      directory
    );
    const pkg = fs.readFileSync(path.join(directory, "package.xml"), "utf8");
    assert.match(pkg, /<members>Account<\/members><name>CustomObject<\/name>/);
    assert.match(
      pkg,
      /<members>RHC_Subscriber_Release_Matrix<\/members><name>FlowDefinition<\/name>/
    );
    assert.match(
      fs.readFileSync(
        path.join(directory, "objects", "Account.object"),
        "utf8"
      ),
      /<actionName>View<\/actionName><formFactor>Large<\/formFactor><type>Default<\/type>/
    );
    assert.match(
      fs.readFileSync(
        path.join(
          directory,
          "flowDefinitions",
          "RHC_Subscriber_Release_Matrix.flowDefinition"
        ),
        "utf8"
      ),
      /<activeVersionNumber>0<\/activeVersionNumber>/
    );
    const post = fs.readFileSync(
      path.join(directory, "destructiveChangesPost.xml"),
      "utf8"
    );
    assert.match(post, /<name>ApexClass<\/name>/);
    assert.doesNotMatch(post, /<name>CustomObject<\/name>|<name>Flow<\/name>/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test("refuses subscriber metadata it does not know how to remove", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "rhc-reset-unknown-"));
  try {
    fs.mkdirSync(path.join(root, "main", "default", "permissionsets"), {
      recursive: true
    });
    assert.throws(() => planReleasePairReset(root), /permissionsets/);
    fs.rmSync(path.join(root, "main", "default", "permissionsets"), {
      recursive: true
    });
    fs.mkdirSync(path.join(root, "main", "default", "objects", "Widget__c"), {
      recursive: true
    });
    assert.throws(() => planReleasePairReset(root), /Widget__c/);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
