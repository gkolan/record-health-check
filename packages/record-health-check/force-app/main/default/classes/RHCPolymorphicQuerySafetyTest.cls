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
}
