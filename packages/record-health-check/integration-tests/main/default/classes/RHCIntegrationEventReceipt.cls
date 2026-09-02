public with sharing class RHCIntegrationEventReceipt {
  public static List<String> checkQualifiedNames = new List<String>();
  public static List<String> checkSources = new List<String>();
  public static Integer setRunCount = 0;

  public static void receiveCheckResults(
    List<Record_Health_Check_Result__e> events
  ) {
    for (Record_Health_Check_Result__e eventRecord : events) {
      checkQualifiedNames.add(eventRecord.CheckQualifiedApiName__c);
      checkSources.add(eventRecord.Source__c);
    }
  }

  public static void receiveSetRuns(
    List<Record_Health_Check_Set_Run__e> events
  ) {
    setRunCount += events.size();
  }

  public static void reset() {
    checkQualifiedNames.clear();
    checkSources.clear();
    setRunCount = 0;
  }

  public static Set<String> receivedEvaluationTypes() {
    Set<String> uniqueCheckNames = new Set<String>(checkQualifiedNames);
    Map<String, Record_Health_Check__mdt> checksByQualifiedName = new Map<String, Record_Health_Check__mdt>();
    for (Record_Health_Check__mdt configuredCheck : [
      SELECT QualifiedApiName, EvaluationType__c
      FROM Record_Health_Check__mdt
      WHERE QualifiedApiName IN :uniqueCheckNames
      WITH USER_MODE
    ]) {
      checksByQualifiedName.put(
        configuredCheck.QualifiedApiName,
        configuredCheck
      );
    }
    Set<String> evaluationTypes = new Set<String>();
    for (String checkQualifiedName : uniqueCheckNames) {
      Record_Health_Check__mdt configuredCheck = checksByQualifiedName.get(
        checkQualifiedName
      );
      Assert.isNotNull(
        configuredCheck,
        'Every received event identity must resolve to Custom Metadata.'
      );
      evaluationTypes.add(configuredCheck.EvaluationType__c);
    }
    return evaluationTypes;
  }
}
