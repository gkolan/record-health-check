/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCFieldPlannerNamespaceTest {
  @IsTest
  static void resolvesNamespaceNeutralCustomFieldNames() {
    RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();

    Test.startTest();
    String reasonCode = planner.resolutionReasonCode(
      Record_Health_Check__mdt.SObjectType,
      'CheckTitle__c'
    );
    Schema.DisplayType displayType = planner.resolvedDisplayType(
      Record_Health_Check__mdt.SObjectType,
      'CheckTitle__c'
    );
    Test.stopTest();

    Assert.isNull(reasonCode);
    Assert.areEqual(Schema.DisplayType.String, displayType);
  }
}
