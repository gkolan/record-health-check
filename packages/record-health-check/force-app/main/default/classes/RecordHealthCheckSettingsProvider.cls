/** Resolves administrator-controlled logging and lifecycle publication settings. */
public virtual with sharing class RecordHealthCheckSettingsProvider {
  /** Returns whether ERROR log events are enabled for a Check Set. */
  public virtual Boolean isErrorEventPublicationEnabled(
    String checkSetDeveloperName
  ) {
    if (String.isBlank(checkSetDeveloperName)) {
      return false;
    }
    Record_Health_Check_Set__mdt checkSet = Record_Health_Check_Set__mdt.getInstance(
      checkSetDeveloperName
    );
    return checkSet != null && checkSet.PublishErrorLogEvent__c == true;
  }

  /** Returns whether an interactive Check Set run event is enabled. */
  public virtual Boolean isRunPublicationEnabled(
    String checkSetQualifiedApiName
  ) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: This reads core-owned Custom Metadata publication settings, not business records.
    List<Record_Health_Check_Set__mdt> settings = [
      SELECT PublishUserRunEvent__c
      FROM Record_Health_Check_Set__mdt
      WHERE QualifiedApiName = :checkSetQualifiedApiName
      LIMIT 1
    ];
    return !settings.isEmpty() && settings[0].PublishUserRunEvent__c == true;
  }

  /** Returns Checks enabled for interactive result-event publication. */
  public virtual Set<String> publishedCheckNames(
    String checkSetQualifiedApiName
  ) {
    Set<String> enabledChecks = new Set<String>();
    // code-analyzer-suppress-next-line ApexCRUDViolation: This reads core-owned Custom Metadata publication settings, not business records.
    for (
      Record_Health_Check__mdt check : queryPublishedChecks(
        checkSetQualifiedApiName
      )
    ) {
      enabledChecks.add(check.QualifiedApiName);
    }
    return enabledChecks;
  }

  /** Query method kept overridable so metadata-backed publication filtering stays independently testable. */
  protected virtual List<Record_Health_Check__mdt> queryPublishedChecks(
    String checkSetQualifiedApiName
  ) {
    return [
      SELECT QualifiedApiName
      FROM Record_Health_Check__mdt
      WHERE
        Record_Health_Check_Set__r.QualifiedApiName = :checkSetQualifiedApiName
        AND PublishUserResultEvent__c = TRUE
    ];
  }
}
