public with sharing class RHCSubscriberEventReceipt {
  public static Integer checkResultCount = 0;
  public static Integer setRunCount = 0;
  public static List<String> checkQualifiedNames = new List<String>();
  public static List<String> checkSources = new List<String>();

  public static void receiveCheckResults(
    List<rhc__Record_Health_Check_Result__e> events
  ) {
    checkResultCount += events.size();
    for (rhc__Record_Health_Check_Result__e eventRecord : events) {
      checkQualifiedNames.add(eventRecord.rhc__CheckQualifiedApiName__c);
      checkSources.add(eventRecord.rhc__Source__c);
    }
  }

  public static void receiveSetRuns(
    List<rhc__Record_Health_Check_Set_Run__e> events
  ) {
    setRunCount += events.size();
  }

  public static void reset() {
    checkResultCount = 0;
    setRunCount = 0;
    checkQualifiedNames.clear();
    checkSources.clear();
  }
}
