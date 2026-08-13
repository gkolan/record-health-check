/**
 * Verifies that formula planning never emits unsupported flat polymorphic SOQL.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCPolymorphicQuerySafetyTest {
  @IsTest
  static void rejectTypeSpecificWhatFieldThatCannotUseFlatSoql() {
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'What:Account.Industry <> ""'
          }
        ),
        Task.SObjectType
      );

    Assert.isFalse(
      fields.contains('What.Industry'),
      'A type-specific polymorphic field must not enter flat SOQL without TYPEOF.'
    );
  }

  @IsTest
  static void rejectColonReferenceWithUnknownRelationship() {
    Test.startTest();
    List<RecordHealthCheckFormulaFieldScanner.FieldReference> references = RecordHealthCheckFormulaFieldScanner.scan(
      'MissingRelationship:Account.Name <> ""',
      Task.SObjectType
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      references.size(),
      'Colon syntax rooted at an unknown relationship must not produce a field reference.'
    );
  }

  @IsTest
  static void collectOmitsCurrencyWhenMultiCurrencyIsDisabled() {
    RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();
    planner.multiCurrencyOrganizationOverride = false;

    Test.startTest();
    Set<String> fields = planner.collectRecordFields(
      RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{
          'EvaluationType__c' => 'FORMULA',
          'PassConditionFormula__c' => 'AnnualRevenue > 0'
        }
      ),
      Account.SObjectType
    );
    Test.stopTest();

    Assert.isFalse(
      fields.contains('CurrencyIsoCode'),
      'CurrencyIsoCode must be omitted when multi-currency planning is disabled.'
    );
  }

  @IsTest
  static void rejectColonlessTypeSpecificWhatFieldThatCannotUseFlatSoql() {
    Test.startTest();
    Set<String> fields = collectFormulaFields(
      'What.Industry <> ""',
      Task.SObjectType
    );
    Test.stopTest();

    Assert.isFalse(
      fields.contains('What.Industry'),
      'A colonless type-specific What field must not enter flat SOQL without TYPEOF.'
    );
  }

  @IsTest
  static void rejectColonlessTypeSpecificOwnerFieldThatCannotUseFlatSoql() {
    Test.startTest();
    Set<String> fields = collectFormulaFields(
      'Owner.Department <> ""',
      Lead.SObjectType
    );
    Test.stopTest();

    Assert.isFalse(
      fields.contains('Owner.Department'),
      'A colonless User-only Owner field must not enter flat SOQL without TYPEOF.'
    );
  }

  @IsTest
  static void rejectColonlessTypeSpecificWhoFieldThatCannotUseFlatSoql() {
    Test.startTest();
    Set<String> fields = collectFormulaFields(
      'Who.LeadSource <> ""',
      Task.SObjectType
    );
    Test.stopTest();

    Assert.isFalse(
      fields.contains('Who.LeadSource'),
      'A colonless Lead-only Who field must not enter flat SOQL without TYPEOF.'
    );
  }

  @IsTest
  static void rejectNameRelationshipUnsupportedByEveryWhatCandidate() {
    Test.startTest();
    Set<String> fields = collectFormulaFields(
      'What.Profile.Name <> ""',
      Task.SObjectType
    );
    Test.stopTest();

    Assert.isFalse(
      fields.contains('What.Profile.Name'),
      'A Name relationship unsupported by every concrete What candidate must fail closed.'
    );
  }

  @IsTest
  static void retainColonlessNameEntityFieldForFlatSoql() {
    Test.startTest();
    Set<String> fields = collectFormulaFields(
      'What.Type <> ""',
      Task.SObjectType
    );
    Test.stopTest();

    Assert.isTrue(
      fields.contains('What.Type'),
      'A colonless field exposed by the Name entity must remain selectable.'
    );
  }

  @IsTest
  static void retainColonlessNameEntityProfileRelationshipForFlatSoql() {
    Test.startTest();
    Set<String> fields = collectFormulaFields(
      'Owner.Profile.Name <> ""',
      Lead.SObjectType
    );
    Test.stopTest();

    Assert.isTrue(
      fields.contains('Owner.Profile.Name'),
      'A Profile relationship exposed by the Name entity must remain selectable.'
    );
  }

  @IsTest
  static void retainColonlessNameEntityUserRoleRelationshipForFlatSoql() {
    Test.startTest();
    Set<String> fields = collectFormulaFields(
      'Owner.UserRole.Name <> ""',
      Lead.SObjectType
    );
    Test.stopTest();

    Assert.isTrue(
      fields.contains('Owner.UserRole.Name'),
      'A UserRole relationship exposed by the Name entity must remain selectable.'
    );
  }

  @IsTest
  static void retainExplicitTypeForAmbiguousNameEntityField() {
    List<RecordHealthCheckFormulaFieldScanner.FieldReference> references = RecordHealthCheckFormulaFieldScanner.scan(
      'What:Account.Type <> ""',
      Task.SObjectType
    );

    Assert.areEqual(
      1,
      references.size(),
      'The supported Name field must plan.'
    );
    Assert.areEqual(
      'What.Type',
      references[0].path,
      'The SOQL path must flatten.'
    );
    Assert.areEqual(
      Account.SObjectType,
      references[0].relationshipType,
      'The author-selected type must survive normalization for describe and formula expansion.'
    );
  }

  private static Set<String> collectFormulaFields(
    String formula,
    Schema.SObjectType objectType
  ) {
    return new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => formula
          }
        ),
        objectType
      );
  }
}
