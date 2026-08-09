/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public class RecordHealthCheckDefinitionResponse {
  @AuraEnabled
  public String checkSetQualifiedApiName;
  @AuraEnabled
  public String displayTitle;
  @AuraEnabled
  public String displayDescription;
  @AuraEnabled
  public String triggerMode; // Automatic, Manual — mapped from CardRunMode__c
  @AuraEnabled
  public String runButtonDisplay; // LABEL_AND_ICON, LABEL_ONLY, ICON_ONLY, HIDE
  @AuraEnabled
  public String runButtonLabel; // blank is normalized by the LWC to Run
  @AuraEnabled
  public String rerunButtonLabel; // blank is normalized by the LWC to Rerun
  @AuraEnabled
  public String runButtonIcon; // blank keeps the built-in CSS play glyph
  @AuraEnabled
  public String revealMode; // AllAtOnce, OneAtATime — mapped from CardRevealMode__c
  @AuraEnabled
  public String successDisplayMode; // Show, Hide — mapped from PassedChecksDisplay__c
  @AuraEnabled
  public String skippedDisplayMode; // Show, Hide — mapped from SkippedChecksDisplay__c
  @AuraEnabled
  public String comparisonDisplay; // OnDemand, FailuresOnly, AllRows — mapped from FoundExpectedDisplay__c
  @AuraEnabled
  public Boolean stopOnFirstError;
  @AuraEnabled
  public Integer totalAvailableCheckCount; // active checks before framework cap truncation
  @AuraEnabled
  public Integer frameworkMaxChecks;
  @AuraEnabled
  public Boolean checksOmittedByLimit; // true when active checks were omitted
  @AuraEnabled
  public Integer inactiveCheckCount; // inactive Checks on the Check Set (not run)
  @AuraEnabled
  public List<String> inactiveCheckLabels; // names behind inactiveCheckCount — diagnostics only
  @AuraEnabled
  public Boolean showDiagnostics; // mirrors ShowDiagnostics__c — tells LWC to show adminDetailMessage
  @AuraEnabled
  public List<RecordHealthCheckDefinition> checks;
}
