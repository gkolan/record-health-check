/** Focused package-only coverage for branches that need no subscriber business data. */
@IsTest
private class RHCOrgSafeCoverageTest {
  private class MissingOutcomeCheck implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      return new Map<Id, RecordHealthCheckOutcome>();
    }
  }

  @IsTest
  static void authorDisplayTextUsesInMemoryValues() {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Acme' }
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DisplayFoundText__c' => '{!record.Name}: {!rhcResult.foundValue}',
        'DisplayExpectedText__c' => '{!rhcResult.expectedValue} across {!rhcResult.totalRecordCount}'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.actualValue = 'Found';
    result.expectedValue = 'Expected';
    result.expectedValueLabel = 'Expected value';

    RecordHealthCheckTemplateService.applyFoundExpectedText(
      check,
      record,
      result,
      1,
      2
    );

    Assert.areEqual('Acme: Found', result.actualValue);
    Assert.areEqual('Expected across 2', result.expectedValue);
    Assert.areEqual(null, result.expectedValueLabel);
    RecordHealthCheckTemplateService.applyFoundExpectedText(
      null,
      record,
      result
    );
    RecordHealthCheckTemplateService.applyFoundExpectedText(
      check,
      record,
      null
    );
    RecordHealthCheckTemplateService.applyFoundExpectedText(
      RecordHealthCheckTestDataFactory.check(new Map<String, Object>()),
      record,
      result
    );
  }

  @IsTest
  static void schemaAndBindDefensiveBranchesNeedNoRows() {
    RecordHealthCheckQuerySchemaValidator.validateSupportedSubset('SELECT');
    RecordHealthCheckQuerySchemaValidator.validateConfiguredField(
      'SELECT',
      'Id'
    );
    RecordHealthCheckQuerySchemaValidator.validateConfiguredField(
      'SELECT Id FROM Missing_Object__c',
      'Id'
    );
    try {
      RecordHealthCheckQuerySchemaValidator.validateSupportedSubset(
        'SELECT Id FROM UserLogin'
      );
    } catch (RecordHealthCheckEvaluatorException expected) {
      Assert.isNotNull(expected.reasonCode);
    }

    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'OwnerId' => UserInfo.getUserId() }
    );
    Assert.areEqual(
      UserInfo.getUserId(),
      RecordHealthCheckSoqlBindValueResolver.coerceFallbackValue(
        record,
        'OwnerId',
        String.valueOf(UserInfo.getUserId())
      )
    );
    Assert.isFalse(
      RecordHealthCheckSoqlBindValueResolver.isMultiSelectPicklist(record, '')
    );
    Assert.areEqual(
      Schema.DisplayType.STRING,
      RecordHealthCheckSoqlBindValueResolver.terminalFieldType(record, '')
    );
  }

  @IsTest
  static void asynchronousSideEffectsRemainFatalWithoutBusinessDml() {
    RecordHealthCheckPluginDispatch.SideEffectException syntheticDml = RecordHealthCheckPluginDispatch.detect(
      -1,
      -1,
      Limits.getCallouts(),
      Limits.getQueueableJobs(),
      Limits.getFutureCalls(),
      Limits.getEmailInvocations()
    );
    Assert.areEqual('DML', syntheticDml.effect);
    try {
      RecordHealthCheckPluginDispatch.preserveFatalSideEffect(syntheticDml);
      Assert.fail('Fatal side effects must be rethrown.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException preserved) {
      Assert.areEqual('DML', preserved.effect);
    }
    RecordHealthCheckPluginDispatch.preserveFatalSideEffect(
      new IllegalArgumentException('recoverable')
    );

    try {
      RecordHealthCheckPluginDispatch.instantiate(
        Type.forName(RHCTestConstructorQueueableCheck.class.getName())
      );
      Assert.fail('Constructor side effects must be rejected.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException error) {
      Assert.areEqual('QUEUEABLE', error.effect);
    }

    Record_Health_Check__mdt constructorCheck = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ApexClass__c' => 'RHCTestConstructorQueueableCheck'
      }
    );
    try {
      RecordHealthCheckApexPluginResolver.resolve(constructorCheck);
      Assert.fail('Resolver must preserve a constructor side effect.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException error) {
      Assert.areEqual('QUEUEABLE', error.effect);
    }
    try {
      RecordHealthCheckConfigValidator.isValidApexPlugin(
        'RHCTestConstructorQueueableCheck'
      );
      Assert.fail('Validation must preserve a constructor side effect.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException error) {
      Assert.areEqual('QUEUEABLE', error.effect);
    }

    Account account = RecordHealthCheckTestDataFactory.accountFixture(
      'Queueable evaluation'
    );
    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      'Account',
      new List<Id>{ account.Id },
      null,
      'Queueable_Check',
      'Queueable_Set',
      'run-safe'
    );
    try {
      RecordHealthCheckPluginDispatch.run(
        new RHCTestEvaluationQueueableCheck(),
        scope
      );
      Assert.fail('Evaluation side effects must be rejected.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException error) {
      Assert.areEqual('QUEUEABLE', error.effect);
      Assert.isTrue(error.reversible);
    }
  }

  @IsTest
  static void configCacheNullIdentityIsSafe() {
    Assert.areEqual(
      null,
      RecordHealthCheckConfigValidator.takeValidatedPlugin(null)
    );
    RecordHealthCheckConfigValidator.discardValidatedPlugin(null);
  }

  @IsTest
  static void comparisonConvenienceOverloadUsesAlreadyFetchedRows() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'SourceQueryField__c' => 'Name',
        'ComparisonQueryField__c' => 'Name',
        'ComparisonOperator__c' => 'EQUALS'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Acme' }
    );
    RecordHealthCheckCompareQuerySupport.setComparisonValues(
      check,
      record,
      result,
      new List<SObject>{ record },
      new List<SObject>{ record },
      'ONE_RESULT'
    );
    Assert.isNotNull(result.actualValueSource);
    Assert.isNotNull(result.expectedValueSource);
  }

  @IsTest
  static void fatalIncidentRecordingHandlesAnEmptyScope() {
    RecordHealthCheckDiagnosticContext context = new RecordHealthCheckDiagnosticContext();
    context.phase = 'PLUGIN_EXECUTE';
    context.reasonCode = RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED;
    RecordHealthCheckDiagnosticIncident incident = RecordHealthCheckIncidentRecorder.recordFatalFailure(
      null,
      context,
      new IllegalArgumentException('Synthetic fatal boundary.')
    );
    Assert.areEqual(0, context.affectedRecordCount);
    Assert.areEqual('ONE_RECORD', context.scopeImpact);
    Assert.isNotNull(incident.diagnosticId);
  }

  @IsTest
  static void runtimeQueryErrorsReceiveStableClassification() {
    try {
      RecordHealthCheckQueryEvaluatorSupport.runQuery(
        'SELECT Id FROM Account WHERE Id = :rhcMissingBind',
        10
      );
      Assert.fail('An unresolved runtime bind must fail.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.isNotNull(error.reasonCode);
    }
  }

  @IsTest
  static void bulkShapeHelperAndRelationshipTokenNeedNoPersistedRows() {
    Assert.isFalse(RecordHealthCheckBulkQuerySupport.isSupportedShape(null));
    Assert.isTrue(
      RecordHealthCheckBulkQuerySupport.isSupportedShape(
        'SELECT Id FROM Account WHERE Id = {!record.Id}'
      )
    );
    Assert.isFalse(
      RecordHealthCheckBulkQuerySupport.isSupportedShape(
        'SELECT Id FROM Account WHERE Id = {!record.Id} AND Name = {!record.Name}'
      )
    );
    Account parent = RecordHealthCheckTestDataFactory.accountFixture('Parent');
    Account child = RecordHealthCheckTestDataFactory.accountFixture('Child');
    child.putSObject('Parent', parent);
    RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM Account WHERE Id = {!record.Parent.Id}',
      new Map<Id, SObject>{ child.Id => child },
      10
    );
    Assert.areEqual(0, result.rowsByRecordId.get(child.Id).size());
  }

  @IsTest
  static void existingLeastPrivilegeSetupUserCoversAccessDenials() {
    List<User> candidates = [
      SELECT Id
      FROM User
      WHERE
        Id != :UserInfo.getUserId()
        AND IsActive = TRUE
        AND UserType = 'Standard'
      LIMIT 1
    ];
    if (candidates.isEmpty()) {
      return;
    }
    System.runAs(candidates[0]) {
      try {
        RecordHealthCheckQuerySchemaValidator.validateSupportedSubset(
          'SELECT Id FROM Account'
        );
      } catch (RecordHealthCheckEvaluatorException error) {
        Assert.areEqual(
          RecordHealthCheckReasonCodes.RECORD_NOT_ACCESSIBLE,
          error.reasonCode
        );
      }
      RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();
      planner.resolutionReasonCode(Account.SObjectType, 'AnnualRevenue');
      RecordHealthCheckFieldPlanner.FieldPlan plan = planner.planRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'AnnualRevenue > 0 || Owner.Name = ""'
          }
        ),
        Account.SObjectType
      );
      Assert.areNotEqual(null, plan);
    }
  }

  @IsTest
  static void calculatedPlannerCoversRelationshipFallbackAndPlatformFormula() {
    RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();
    planner.calculatedFormulaOverrideByField = new Map<String, String>{
      'AnnualRevenue' => 'BillingCity',
      'BillingCity' => 'Name'
    };
    Set<String> relationshipFields = planner.collectRecordFields(
      RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{
          'EvaluationType__c' => 'FORMULA',
          'PassConditionFormula__c' => 'Parent.AnnualRevenue > 0'
        }
      ),
      Account.SObjectType
    );
    Assert.isFalse(relationshipFields.isEmpty());

    RecordHealthCheckFieldPlanner fallbackPlanner = new RecordHealthCheckFieldPlanner();
    fallbackPlanner.calculatedFormulaOverrideByField = new Map<String, String>{
      'Name' => 'BillingCity'
    };
    Assert.isFalse(
      fallbackPlanner
        .collectRecordFields(
          RecordHealthCheckTestDataFactory.check(
            new Map<String, Object>{
              'EvaluationType__c' => 'FORMULA',
              'PassConditionFormula__c' => 'Parent.Name = "Acme"'
            }
          ),
          Account.SObjectType
        )
        .isEmpty()
    );

    planner.multiCurrencyOrganizationOverride = true;
    RecordHealthCheckFieldPlanner.FieldPlan currencyPlan = planner.planRecordFields(
      RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{
          'EvaluationType__c' => 'FORMULA',
          'PassConditionFormula__c' => 'BillingCity = "Chicago"'
        }
      ),
      Account.SObjectType
    );
    Assert.areNotEqual(null, currencyPlan);

    Set<String> platformFormulaFields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'Name = "Acme"'
          }
        ),
        Contact.SObjectType
      );
    Assert.isFalse(platformFormulaFields.isEmpty());
  }

  @IsTest
  static void apexEvaluatorPreservesConstructorSideEffectsAndDefaultMessage() {
    Account account = RecordHealthCheckTestDataFactory.accountFixture(
      'Apex evaluator boundaries'
    );
    Map<Id, SObject> loaded = new Map<Id, SObject>{ account.Id => account };
    Record_Health_Check__mdt constructorCheck = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'APEX',
        'ApexClass__c' => 'RHCTestConstructorQueueableCheck'
      }
    );
    try {
      new RecordHealthCheckApexEvaluator()
        .evaluateScope(
          constructorCheck,
          new List<Id>{ account.Id },
          loaded,
          'Account',
          'Safe_Set',
          'constructor-side-effect'
        );
      Assert.fail('Constructor side effects must remain fatal.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException error) {
      Assert.areEqual('QUEUEABLE', error.effect);
    }

    Record_Health_Check__mdt missingCheck = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Missing_Outcome',
        'QualifiedApiName' => 'Missing_Outcome',
        'EvaluationType__c' => 'APEX',
        'ApexClass__c' => 'AccountHasRecentActivityCheck',
        'UnableToEvaluateMessage__c' => null
      }
    );
    RecordHealthCheckConfigValidator.cachePluginForTest(
      missingCheck.ApexClass__c,
      new MissingOutcomeCheck()
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluateScope(
        missingCheck,
        new List<Id>{ account.Id },
        loaded,
        'Account',
        'Safe_Set',
        'missing-default-message'
      )
      .get(account.Id);
    Assert.areEqual(
      'A system error prevented this check from completing. An authorized administrator can open the diagnosis.',
      result.message
    );
  }
}
