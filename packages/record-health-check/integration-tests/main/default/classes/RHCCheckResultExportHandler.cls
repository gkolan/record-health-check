/** Persists scratch-org exports for published Check Result events. */
public with sharing class RHCCheckResultExportHandler {
  public static void afterInsert(
    List<Record_Health_Check_Result__e> eventRecords
  ) {
    List<RHC_Event_Export__c> exports = new List<RHC_Event_Export__c>();
    for (Record_Health_Check_Result__e eventRecord : eventRecords) {
      Map<String, Object> payload = new Map<String, Object>{
        'contractVersion' => eventRecord.ContractVersion__c,
        'eventId' => eventRecord.EventId__c,
        'runId' => eventRecord.RunId__c,
        'checkSet' => eventRecord.CheckSetQualifiedApiName__c,
        'check' => eventRecord.CheckQualifiedApiName__c,
        'status' => eventRecord.Status__c,
        'reasonCode' => eventRecord.ReasonCode__c,
        'source' => eventRecord.Source__c
      };
      exports.add(
        new RHC_Event_Export__c(
          EventId__c = eventRecord.EventId__c,
          Payload__c = JSON.serialize(payload)
        )
      );
    }
    Database.insert(exports, AccessLevel.USER_MODE);
  }
}
