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
}
