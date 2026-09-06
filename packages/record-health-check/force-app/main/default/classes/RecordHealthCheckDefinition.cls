/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public class RecordHealthCheckDefinition {
  @AuraEnabled
  public String qualifiedApiName;
  @AuraEnabled
  public String developerName;
  @AuraEnabled
  public String label;
  @AuraEnabled
  public String description;
  @AuraEnabled
  public String category;
  @AuraEnabled
  public String categoryLabel;
  @AuraEnabled
  public Decimal priority;
  @AuraEnabled
  public String dependsOnCheckDeveloperName; // null when no dependency
  @AuraEnabled
  public String dependsOnCheckQualifiedApiName; // namespace-safe dependency identity
  @AuraEnabled
  public String comparisonDisplayMode; // AUTOMATIC, FOUND_ONLY, EXPECTED_ONLY, HIDDEN — presentation only; blank metadata resolves to AUTOMATIC

  /**
   * Builds one browser-facing Check definition from its Custom Metadata record.
   *
   * @param check Check metadata included in this run.
   * @param allChecks Every active Check on the Check Set, for dependency identity.
   * @param categoryLabel Translated Category label, or null.
   * @param prerequisite Normalized prerequisite Check developer name, or null.
   * @return One definition item for the Lightning card.
   */
  public static RecordHealthCheckDefinition fromMetadata(
    Record_Health_Check__mdt check,
    List<Record_Health_Check__mdt> allChecks,
    String categoryLabel,
    String prerequisite
  ) {
    RecordHealthCheckDefinition def = new RecordHealthCheckDefinition();
    def.qualifiedApiName = check.QualifiedApiName;
    def.developerName = check.DeveloperName;
    def.label = check.CheckTitle__c;
    def.description = check.CheckDescription__c;
    def.category = check.Category__c;
    def.categoryLabel = categoryLabel;
    def.priority = check.EvaluationOrder__c;
    def.dependsOnCheckDeveloperName = prerequisite;
    def.dependsOnCheckQualifiedApiName = RHCDefinitionDependencyIdentity.resolve(
      check,
      allChecks
    );
    // Presentation only; blank resolves to AUTOMATIC (see the policy class).
    def.comparisonDisplayMode = RecordHealthCheckComparisonVisibility.normalize(
      check.ComparisonDisplayMode__c
    );
    return def;
  }
}
