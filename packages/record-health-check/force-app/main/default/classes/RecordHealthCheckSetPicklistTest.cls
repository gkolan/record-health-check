/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckSetPicklistTest {
  @IsTest
  static void scopesRowsToPageObject() {
    VisualEditor.DesignTimePageContext ctx = new VisualEditor.DesignTimePageContext();
    ctx.entityName = 'Account';
    RecordHealthCheckSetPicklist picklist = new RecordHealthCheckSetPicklist(
      ctx
    );

    VisualEditor.DynamicPickListRows rows = picklist.getValues();
    Assert.areNotEqual(null, rows);

    Integer activeAccountSets = [
      SELECT COUNT()
      FROM Record_Health_Check_Set__mdt
      WHERE IsActive__c = TRUE AND ObjectApiName__c = 'Account'
    ];
    Assert.areEqual(
      activeAccountSets,
      rows.size(),
      'One row per active Check Set scoped to the page object'
    );
    VisualEditor.DataRow defaultValue = picklist.getDefaultValue();
    if (activeAccountSets == 1) {
      Assert.areNotEqual(
        null,
        defaultValue,
        'The sole active Check Set should be selected automatically'
      );
      Record_Health_Check_Set__mdt expectedSet = [
        SELECT MasterLabel, QualifiedApiName
        FROM Record_Health_Check_Set__mdt
        WHERE IsActive__c = TRUE AND ObjectApiName__c = 'Account'
        LIMIT 1
      ];
      Assert.areEqual(
        expectedSet.MasterLabel,
        defaultValue.getLabel(),
        'App Builder should display the Check Set Master Label'
      );
      Assert.areEqual(
        expectedSet.QualifiedApiName,
        defaultValue.getValue(),
        'App Builder should store the namespace-safe Qualified API Name'
      );
    } else {
      Assert.areEqual(
        null,
        defaultValue,
        'With zero or several matches there is no auto-default'
      );
    }
  }

  @IsTest
  static void emptyForUnknownObjectAndNullContextIsSafe() {
    VisualEditor.DesignTimePageContext ctx = new VisualEditor.DesignTimePageContext();
    ctx.entityName = 'ZZ_No_Such_Object__x';
    RecordHealthCheckSetPicklist unknown = new RecordHealthCheckSetPicklist(
      ctx
    );
    Assert.areEqual(
      0,
      unknown.getValues().size(),
      'An object with no Check Sets yields an empty dropdown'
    );
    Assert.areEqual(
      null,
      unknown.getDefaultValue(),
      'No match → no auto-default'
    );

    // A null context (e.g. a page template with no bound entity) must not throw
    // and falls back to every active Check Set.
    Integer allActive = [
      SELECT COUNT()
      FROM Record_Health_Check_Set__mdt
      WHERE IsActive__c = TRUE
    ];
    Assert.areEqual(
      allActive,
      new RecordHealthCheckSetPicklist(null).getValues().size(),
      'Null page context shows all active Check Sets'
    );
  }
}
