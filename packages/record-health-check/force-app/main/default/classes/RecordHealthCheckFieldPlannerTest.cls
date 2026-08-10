/** Focused tests for record field planning and calculated-formula expansion. */
@IsTest
private class RecordHealthCheckFieldPlannerTest {
  @IsTest
  static void collectsMergeFormulaAndRelationshipFields() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'CONTAINS(Website, "example.com") && NOT(ISBLANK(Parent.Name))',
        'FailureMessage__c' => 'Account {!record.BillingCity} needs attention'
      }
    );

    Test.startTest();
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(check, Account.SObjectType);
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
      RecordHealthCheckTestDataFactory.check(
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
      RecordHealthCheckTestDataFactory.check(
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
      RecordHealthCheckTestDataFactory.check(
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
        RecordHealthCheckTestDataFactory.check(
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
      RecordHealthCheckTestDataFactory.check(
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
        RecordHealthCheckTestDataFactory.check(
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
      RecordHealthCheckTestDataFactory.check(new Map<String, Object>()),
      Account.SObjectType
    );
    Assert.isTrue(fields.contains('Id'));
  }

  @IsTest
  static void collectsApplicabilityFormulaOperands() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ApplicabilityMode__c' => 'WHEN_FORMULA_TRUE',
        'ApplicabilityFormula__c' => 'AnnualRevenue > 0'
      }
    );

    Test.startTest();
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(check, Account.SObjectType);
    Test.stopTest();

    Assert.isTrue(
      fields.contains('AnnualRevenue'),
      'Applicability formula operands must be loaded before evaluation.'
    );
  }

  @IsTest
  static void collectsQueryEvaluatorRecordFormulaOperands() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'QUERY',
        'FindInListFormula__c' => 'BillingCity',
        'ExpectedRecordFormula__c' => 'AnnualRevenue'
      }
    );

    Test.startTest();
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(check, Account.SObjectType);
    Test.stopTest();

    Assert.isTrue(
      fields.contains('BillingCity'),
      'The list-membership record formula operand must be loaded.'
    );
    Assert.isTrue(
      fields.contains('AnnualRevenue'),
      'The expected record-formula operand must be loaded.'
    );
  }

  @IsTest
  static void separatesFieldsDeniedByRunningUserFls() {
    User minimumAccessUser = RecordHealthCheckPersonaTestDataFactory.createMinimumAccessUser(
      'flsplan'
    );
    RecordHealthCheckFieldPlanner.FieldPlan plan;

    Test.startTest();
    System.runAs(minimumAccessUser) {
      plan = new RecordHealthCheckFieldPlanner()
        .planRecordFields(
          RecordHealthCheckTestDataFactory.check(
            new Map<String, Object>{
              'EvaluationType__c' => 'FORMULA',
              'PassConditionFormula__c' => 'AnnualRevenue > 0'
            }
          ),
          Account.SObjectType
        );
    }
    Test.stopTest();

    Assert.isFalse(
      plan.selectedFields.contains('AnnualRevenue'),
      'A field denied by FLS must not enter the user-mode record query.'
    );
    Assert.isTrue(
      plan.inaccessibleFields.contains('AnnualRevenue'),
      'The denied field must be retained in the inaccessible-field plan for an aligned result.'
    );
  }
}
