import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const readinessServicePath = new URL(
  "../../packages/record-health-check/force-app/main/default/classes/RecordHealthCheckReadinessService.cls",
  import.meta.url
);
const previewServicePath = new URL(
  "../../packages/record-health-check/force-app/main/default/classes/RecordHealthCheckPreviewService.cls",
  import.meta.url
);
const previewControllerTestPath = new URL(
  "../../packages/record-health-check/force-app/main/default/classes/RecordHealthCheckPreviewControllerTest.cls",
  import.meta.url
);
const previewServiceTestPath = new URL(
  "../../packages/record-health-check/force-app/main/default/classes/RecordHealthCheckPreviewServiceTest.cls",
  import.meta.url
);

test("readiness receipt tests model the same user-mode access as administrators", async () => {
  const [
    readinessService,
    previewService,
    previewControllerTest,
    previewServiceTest
  ] = await Promise.all([
    readFile(readinessServicePath, "utf8"),
    readFile(previewServicePath, "utf8"),
    readFile(previewControllerTestPath, "utf8"),
    readFile(previewServiceTestPath, "utf8")
  ]);

  assert.match(
    previewService,
    /global static RecordHealthCheckPreviewResponse preview\([\s\S]*?\{\s*requireAuthorization\(\);/,
    "Detached preview must authorize the administrator before receipt persistence or reads."
  );
  assert.match(
    previewService,
    /global static Integer deleteExpiredReadinessReceipts\(Boolean confirmed\) \{\s*requireAuthorization\(\);\s*return RecordHealthCheckReadinessService\.deleteExpired\(confirmed\);/,
    "Receipt cleanup must authorize the administrator before service-owned deletion."
  );

  const userModeQueries = readinessService.match(/WITH USER_MODE/g) ?? [];
  assert.equal(
    userModeQueries.length,
    2,
    "Both receipt queries must enforce the authorized administrator's field access."
  );
  assert.match(
    readinessService,
    /Database\.delete\(\s*expired,\s*AccessLevel\.USER_MODE\s*\)/,
    "Cleanup must enforce the authorized administrator's delete access."
  );

  for (const testSource of [previewControllerTest, previewServiceTest]) {
    assert.match(
      testSource,
      /@TestSetup\s+static void assignAdministratorAccess\(\) \{\s*RecordHealthCheckTestDataFactory\.assignPermissionSet\(\s*RecordHealthCheckTestDataFactory\.currentUser\(\),\s*'Record_Health_Check_Admin'\s*\);\s*\}/,
      "Package tests that exercise USER_MODE receipts must assign the administrator permission set."
    );
  }
});
