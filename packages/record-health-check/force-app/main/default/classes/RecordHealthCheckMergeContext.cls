/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Typed sources available to namespaced merge-token resolution. */
public class RecordHealthCheckMergeContext {
  public SObject record;
  public Record_Health_Check__mdt check;
  public SObject checkSet;
  public RecordHealthCheckInternalResult result;
  public RecordHealthCheckRunContext run;
  public Integer failedRecordCount;
  public Integer totalRecordCount;
  public Boolean resultFinalized = false;

  public RecordHealthCheckMergeContext withRecord(SObject value) {
    record = value;
    return this;
  }
  public RecordHealthCheckMergeContext withCheck(
    Record_Health_Check__mdt value
  ) {
    check = value;
    if (value != null) {
      checkSet = value.getSObject('Record_Health_Check_Set__r');
    }
    return this;
  }
  public RecordHealthCheckMergeContext withResult(
    RecordHealthCheckInternalResult value,
    Boolean finalized
  ) {
    result = value;
    resultFinalized = finalized == true;
    return this;
  }
  public RecordHealthCheckMergeContext withRun(
    RecordHealthCheckRunContext value
  ) {
    run = value;
    return this;
  }
}
