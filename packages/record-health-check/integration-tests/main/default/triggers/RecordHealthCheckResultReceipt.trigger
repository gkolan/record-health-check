/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Scratch-org-only consumer used to verify publish-after-commit behavior. */
trigger RecordHealthCheckResultReceipt on Record_Health_Check_Result__e(
  after insert
) {
  RHCCheckResultReceiptHandler.afterInsert(Trigger.New);
}
