/** Persists scratch-org receipts for published Check Result events. */
public with sharing class RHCCheckResultReceiptHandler {
  public static void afterInsert(
    List<Record_Health_Check_Result__e> eventRecords
  ) {
    List<Task> receipts = new List<Task>();
    for (Record_Health_Check_Result__e eventRecord : eventRecords) {
      receipts.add(
        new Task(
          Subject = 'RHC Check Result Receipt',
          Description = eventRecord.EventId__c,
          Status = 'Not Started',
          Priority = 'Normal'
        )
      );
    }
    Database.insert(receipts, AccessLevel.USER_MODE);
  }
}
