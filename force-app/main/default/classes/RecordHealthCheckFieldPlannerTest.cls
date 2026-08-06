/** Focused tests for record field planning and calculated-formula expansion. */
@IsTest
private class RecordHealthCheckFieldPlannerTest {
  @IsTest
  static void collectsMergeFormulaAndRelationshipFields() {
    Record_Health_Check_Rule__mdt rule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'CONTAINS(Website, "example.com") && NOT(ISBLANK(Parent.Name))',
        'FailureMessage__c' => 'Account {!record.BillingCity} needs attention'
      }
    );

    Test.startTest();
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(rule, Account.SObjectType);
    Test.stopTest();

    Assert.isTrue(fields.contains('Id'), 'Every record query must select Id.');
    Assert.isTrue(
      fields.contains('Website'),
      'Formula operands must be selected.'
    );
    Assert.isTrue(
      fields.contains('Parent.Name'),
      'Readable relationship operands must be selected.'
    );
    Assert.isTrue(
      fields.contains('BillingCity'),
      'Display merge fields must be selected.'
    );
    Assert.isFalse(
      fields.contains('example.com'),
      'Formula string literals must never become field names.'
    );
  }

  @IsTest
  static void expandsCalculatedFormulaDependenciesTransitively() {
    RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();
    planner.calculatedFormulaOverrideByField = new Map<String, String>{
      'ExpectedRevenue' => 'Amount * Probability',
      'Amount' => 'UnitPrice * Quantity'
    };

    Test.startTest();
    Set<String> fields = planner.collectRecordFields(
      RecordHealthCheckTestDataFactory.rule(
        new Map<String, Object>{
          'EvaluationType__c' => 'FORMULA',
          'PassConditionFormula__c' => 'ExpectedRevenue > 0'
        }
      ),
      Opportunity.SObjectType
    );
    Test.stopTest();

    Assert.isTrue(
      fields.contains('ExpectedRevenue'),
      'The calculated operand must be selected.'
    );
    Assert.isTrue(
      fields.contains('Amount'),
      'Direct calculated dependencies must be selected.'
    );
    Assert.isTrue(
      fields.contains('Probability'),
      'Sibling dependencies must be selected.'
    );
  }

  @IsTest
  static void calculatedCyclesAndBlankDefinitionsTerminateSafely() {
    RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();
    planner.calculatedFormulaOverrideByField = new Map<String, String>{
      'ExpectedRevenue' => 'Amount',
      'Amount' => 'ExpectedRevenue'
    };

    Test.startTest();
    Set<String> cyclic = planner.collectRecordFields(
      RecordHealthCheckTestDataFactory.rule(
        new Map<String, Object>{
          'EvaluationType__c' => 'FORMULA',
          'PassConditionFormula__c' => 'ExpectedRevenue > 0'
        }
      ),
      Opportunity.SObjectType
    );
    planner.calculatedFormulaOverrideByField = new Map<String, String>{
      'ExpectedRevenue' => ''
    };
    Set<String> blank = planner.collectRecordFields(
      RecordHealthCheckTestDataFactory.rule(
        new Map<String, Object>{
          'EvaluationType__c' => 'FORMULA',
          'PassConditionFormula__c' => 'ExpectedRevenue > 0'
        }
      ),
      Opportunity.SObjectType
    );
    Test.stopTest();

    Assert.isTrue(
      cyclic.contains('ExpectedRevenue'),
      'Cycle detection must preserve the root operand.'
    );
    Assert.isTrue(
      cyclic.contains('Amount'),
      'Cycle detection must preserve discovered dependencies.'
    );
    Assert.isTrue(
      blank.contains('ExpectedRevenue'),
      'A blank calculated definition must stop at its operand.'
    );
  }

  @IsTest
  static void rejectsMissingInaccessibleAndMalformedPaths() {
    Test.startTest();
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.rule(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'Missing__c + Parent.Missing__c + MissingRelationship.Field__c'
          }
        ),
        Account.SObjectType
      );
    Test.stopTest();

    Set<String> expected = new Set<String>{ 'Id' };
    if (
      UserInfo.isMultiCurrencyOrganization() &&
      RecordHealthCheckDescribeCache.fieldMap(Account.SObjectType)
        .containsKey('currencyisocode')
    ) {
      expected.add('CurrencyIsoCode');
    }
    Assert.areEqual(
      expected,
      fields,
      'Invalid paths must not enter dynamic SOQL.'
    );
  }

  @IsTest
  static void collectAddsCurrencyWhenMultiCurrencyIsEnabled() {
    RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();
    planner.multiCurrencyOrganizationOverride = true;

    Test.startTest();
    Set<String> fields = planner.collectRecordFields(
      RecordHealthCheckTestDataFactory.rule(
        new Map<String, Object>{
          'EvaluationType__c' => 'FORMULA',
          'PassConditionFormula__c' => 'AnnualRevenue > 0'
        }
      ),
      Account.SObjectType
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckDescribeCache.fieldMap(Account.SObjectType)
        .containsKey('currencyisocode'),
      fields.contains('CurrencyIsoCode'),
      'CurrencyIsoCode should be selected exactly when the object exposes it.'
    );
  }

  @IsTest
  static void readsPlatformCalculatedFormulaMetadata() {
    Test.startTest();
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.rule(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'ExpectedRevenue > 0'
          }
        ),
        Opportunity.SObjectType
      );
    Test.stopTest();

    Assert.isTrue(
      fields.contains('ExpectedRevenue'),
      'The platform calculated field must remain in the planned query.'
    );
  }

  @IsTest
  static void coversMinimalPlanningAndNonCalculatedFields() {
    RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();
    planner.multiCurrencyOrganizationOverride = true;

    Set<String> fields = planner.collectRecordFields(
      RecordHealthCheckTestDataFactory.rule(new Map<String, Object>()),
      Account.SObjectType
    );
    Assert.isTrue(fields.contains('Id'));
  }
}
