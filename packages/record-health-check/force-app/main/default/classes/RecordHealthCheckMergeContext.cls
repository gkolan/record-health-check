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
  // Transient query rows for {!rhcQuery...} resolution. Held only while a
  // template is being finished and never copied into any result the framework
  // returns, publishes, logs, or sends to the browser.
  public transient List<SObject> sourceRows;
  public transient List<SObject> comparisonRows;
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
  /** Attaches the rows the Check's own queries returned, for row tokens. */
  public RecordHealthCheckMergeContext withQueryRows(
    List<SObject> source,
    List<SObject> comparison
  ) {
    sourceRows = source;
    comparisonRows = comparison;
    return this;
  }

  public RecordHealthCheckMergeContext withRun(
    RecordHealthCheckRunContext value
  ) {
    run = value;
    return this;
  }
}
