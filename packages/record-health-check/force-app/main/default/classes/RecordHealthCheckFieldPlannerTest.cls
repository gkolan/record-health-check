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

  // 02/03 Phase 0 — colon-syntax polymorphic references were never planned.
  @IsTest
  static void planColonSyntaxOwnerReferenceOnLeadRow02() {
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'Owner:User.IsActive'
          }
        ),
        Lead.SObjectType
      );

    Assert.isTrue(
      fields.contains('Owner.IsActive'),
      'Owner:User.IsActive must plan the flattened Owner.IsActive SOQL path so FormulaEval can hydrate polymorphic Owner. Planned: ' +
      fields
    );
  }

  @IsTest
  static void planColonSyntaxCreatedByReferenceRow03() {
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'CreatedBy:User.IsActive'
          }
        ),
        Lead.SObjectType
      );

    Assert.isTrue(
      fields.contains('CreatedBy.IsActive'),
      'CreatedBy:User.IsActive must plan CreatedBy.IsActive. Planned: ' + fields
    );
  }

  @IsTest
  static void planColonSyntaxLastModifiedByReferenceRow03() {
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'LastModifiedBy:User.IsActive'
          }
        ),
        Lead.SObjectType
      );

    Assert.isTrue(
      fields.contains('LastModifiedBy.IsActive'),
      'LastModifiedBy:User.IsActive must plan LastModifiedBy.IsActive. Planned: ' +
      fields
    );
  }

  @IsTest
  static void planColonSyntaxWhatReferenceOnTaskRow03() {
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'What:Account.Name <> ""'
          }
        ),
        Task.SObjectType
      );

    Assert.isTrue(
      fields.contains('What.Name'),
      'What:Account.Name must plan What.Name. Planned: ' + fields
    );
  }

  @IsTest
  static void planColonSyntaxWhoReferenceOnTaskRow03() {
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'Who:Contact.Email <> ""'
          }
        ),
        Task.SObjectType
      );

    Assert.isTrue(
      fields.contains('Who.Email'),
      'Who:Contact.Email must plan Who.Email. Planned: ' + fields
    );
  }

  @IsTest
  static void planColonSyntaxCustomFormulaFieldDependencyRow02() {
    RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();
    planner.calculatedFormulaOverrideByField = new Map<String, String>{
      'OwnerIsActive__c' => 'Owner:User.IsActive'
    };

    Set<String> fields = planner.collectRecordFields(
      RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{
          'EvaluationType__c' => 'FORMULA',
          'PassConditionFormula__c' => 'OwnerIsActive__c'
        }
      ),
      Lead.SObjectType
    );

    Assert.isTrue(
      fields.contains('Owner.IsActive'),
      'A calculated field whose own formula uses colon syntax must still expand to Owner.IsActive. Planned: ' +
      fields
    );
  }

  // 03 — invalid Type segments must not silently guess a candidate.
  @IsTest
  static void planColonSyntaxRejectsInvalidTypeSegmentRow03() {
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'Owner:BogusType.IsActive'
          }
        ),
        Lead.SObjectType
      );

    Assert.isFalse(
      fields.contains('Owner.IsActive'),
      'An invalid colon Type segment must not resolve to any path. Planned: ' +
      fields
    );
  }

  // 24 — $ globals must never contribute bogus root-record SOQL paths.
  @IsTest
  static void maskDollarUserGlobalFromFieldPlanRow24() {
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'OwnerId = $User.Id'
          }
        ),
        Account.SObjectType
      );

    Assert.isTrue(
      fields.contains('OwnerId'),
      'The real record field must still plan.'
    );
    Assert.isFalse(
      fields.contains('User.Id'),
      '$User.Id must never contribute a bogus User.Id root-record path. Planned: ' +
      fields
    );
  }

  @IsTest
  static void maskDollarProfileAndSetupGlobalsRow24() {
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'CONTAINS($Profile.Name, "Admin") || CONTAINS($Setup.My_Setting__c.Value__c, "x")'
          }
        ),
        Account.SObjectType
      );

    Assert.isFalse(
      fields.contains('Profile.Name'),
      '$Profile.Name must not contribute a bogus Profile.Name path. Planned: ' +
      fields
    );
    Assert.isFalse(
      fields.contains('Setup.My_Setting__c.Value__c'),
      '$Setup custom-setting globals must not contribute record-rooted paths. Planned: ' +
      fields
    );
  }

  @IsTest
  static void ambiguousPolymorphicPickFailsClosedRow08() {
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'Owner.NoSuchFieldOnAnyOwnerType__c'
          }
        ),
        Lead.SObjectType
      );

    Assert.isFalse(
      fields.contains('Owner.NoSuchFieldOnAnyOwnerType__c'),
      'An ambiguous polymorphic path that matches no candidate must fail closed. Planned: ' +
      fields
    );
  }
}
