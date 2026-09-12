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
test("authorized readiness receipt operations use bounded service-owned access", async () => {
  const [readinessService, previewService] = await Promise.all([
    readFile(readinessServicePath, "utf8"),
    readFile(previewServicePath, "utf8")
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

  const systemModeQueries = readinessService.match(/WITH SYSTEM_MODE/g) ?? [];
  assert.equal(
    systemModeQueries.length,
    2,
    "Exactly two bounded receipt queries may read service-owned evidence after authorization."
  );
  assert.match(
    readinessService,
    /Database\.delete\(\s*expired,\s*AccessLevel\.SYSTEM_MODE\s*\)/,
    "Exactly one bounded cleanup may delete service-owned receipts after authorization."
  );
  assert.equal(
    (readinessService.match(/AccessLevel\.SYSTEM_MODE/g) ?? []).length,
    1,
    "Receipt cleanup must contain exactly one explicit system-mode DML operation."
  );
});
