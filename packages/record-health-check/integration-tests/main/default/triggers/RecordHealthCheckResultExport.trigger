/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Scratch-org-only export consumer used to validate the published event schema. */
trigger RecordHealthCheckResultExport on Record_Health_Check_Result__e(
  after insert
) {
  RHCCheckResultExportHandler.afterInsert(Trigger.New);
}
