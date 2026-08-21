#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <scratch-org-alias>" >&2
  exit 2
fi

target_org="$1"
evidence_dir="reports/polymorphic-owner-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$evidence_dir"

cleanup() {
  SF_DISABLE_LOG_FILE=true sf apex run \
    --file packages/record-health-check/integration-tests/scripts/polymorphic-owner-cleanup.apex \
    --target-org "$target_org" \
    --json >"$evidence_dir/cleanup.json" || true
}
trap cleanup EXIT

npm run check:toolchain

SF_DISABLE_LOG_FILE=true sf project deploy start \
  --target-org "$target_org" \
  --source-dir packages/record-health-check/force-app/main/default/classes/RecordHealthCheckFormulaFieldScanner.cls \
  --source-dir packages/record-health-check/force-app/main/default/classes/RecordHealthCheckFieldPlanner.cls \
  --source-dir packages/record-health-check/force-app/main/default/classes/RecordHealthCheckInternalResult.cls \
  --source-dir packages/record-health-check/force-app/main/default/classes/RecordHealthCheckResultDisplay.cls \
  --source-dir packages/record-health-check/force-app/main/default/classes/RecordHealthCheckScopeResultSupport.cls \
  --source-dir packages/record-health-check/integration-tests/main/default/objects/Lead/fields/RHC_Owner_Is_Active__c.field-meta.xml \
  --source-dir packages/record-health-check/integration-tests/main/default/permissionsets/RHC_Polymorphic_Formula_Test.permissionset-meta.xml \
  --wait 30 \
  --json >"$evidence_dir/deploy.json"

if ! SF_DISABLE_LOG_FILE=true sf org assign permset \
  --name RHC_Polymorphic_Formula_Test \
  --target-org "$target_org" \
  --json >"$evidence_dir/permission-assignment.json"; then
  if ! rg -q 'Duplicate PermissionSetAssignment' "$evidence_dir/permission-assignment.json"; then
    exit 1
  fi
fi

SF_DISABLE_LOG_FILE=true sf apex run \
  --file packages/record-health-check/integration-tests/scripts/polymorphic-owner-setup.apex \
  --target-org "$target_org" \
  --json >"$evidence_dir/setup.json"

SF_DISABLE_LOG_FILE=true sf apex run \
  --file packages/record-health-check/integration-tests/scripts/polymorphic-owner-evaluate.apex \
  --target-org "$target_org" \
  --json >"$evidence_dir/evaluate.json"

echo "Polymorphic Owner runtime gate passed. Evidence: $evidence_dir"
