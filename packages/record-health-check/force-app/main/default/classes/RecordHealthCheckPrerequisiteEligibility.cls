/** Filters a Check scope before any applicability callback is invoked. */
public with sharing class RecordHealthCheckPrerequisiteEligibility {
  /** Eligible records plus visibility/prerequisite results for blocked records. */
  public class Selection {
    public List<Id> recordIds = new List<Id>();
    public Map<Id, SObject> recordsById = new Map<Id, SObject>();
    public Map<Id, RecordHealthCheckInternalResult> blockedByRecordId = new Map<Id, RecordHealthCheckInternalResult>();
  }

  /** Selects visible records whose resolved prerequisite passed. */
  public static Selection selectEligible(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> recordsById,
    Map<String, RecordHealthCheckResultItem> itemsByIdentity,
    Boolean fullCheckSetSelection,
    RecordHealthCheckScopeResultSupport resultSupport
  ) {
    Selection selection = new Selection();
    String resolvedPrerequisite = resultSupport.resolvePrerequisite(
      check,
      itemsByIdentity
    );
    for (Id recordId : recordIds) {
      SObject record = recordsById.get(recordId);
      if (record == null) {
        selection.blockedByRecordId.put(
          recordId,
          resultSupport.unavailableResult(check, 'RECORD_NOT_VISIBLE')
        );
        continue;
      }
      RecordHealthCheckInternalResult prerequisiteBlock = resultSupport.findPrerequisiteBlock(
        check,
        recordId,
        itemsByIdentity,
        fullCheckSetSelection,
        resolvedPrerequisite
      );
      if (prerequisiteBlock != null) {
        selection.blockedByRecordId.put(recordId, prerequisiteBlock);
        continue;
      }
      selection.recordIds.add(recordId);
      selection.recordsById.put(recordId, record);
    }
    return selection;
  }
}
