/** Regression-first acceptance tests for subscriber plugin definitions. */
@IsTest
private class RHCSubscriberDefinitionSpecTest {
  @IsTest
  static void defaultSchemaValues() {
    RecordHealthCheckInternalResult result = evaluate('{}', null);

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      result.status,
      'An empty parameter object must evaluate successfully with schema defaults.'
    );
    Assert.areEqual(
      1,
      RecordHealthCheckDefTestPlugin.constructorCount,
      'Default resolution must instantiate the plugin only once.'
    );
    Assert.areEqual(
      1,
      RecordHealthCheckDefTestPlugin.definitionCount,
      'Default resolution must obtain the definition only once.'
    );
    Assert.areEqual(
      1,
      RecordHealthCheckDefTestPlugin.evaluateCount,
      'Validated defaults must reach exactly one evaluation invocation.'
    );
    Assert.areEqual(
      5,
      RecordHealthCheckDefTestPlugin.seenParameters.get('maxPreviewRecords'),
      'The omitted preview limit must receive its declared integer default.'
    );
    Assert.areEqual(
      'nameId',
      RecordHealthCheckDefTestPlugin.seenParameters.get('displayFormat'),
      'The omitted display format must receive its declared choice default.'
    );
    Assert.areEqual(
      'QuoteInactiveApproverPreviewService',
      RecordHealthCheckDefTestPlugin.seenParameters.get('previewService'),
      'The omitted service name must receive its declared string default.'
    );
  }

  @IsTest
  static void typeAndDuplicateKeys() {
    assertRejected('{"maxPreviewRecords":"5"}');
    assertRejected('{"maxPreviewRecords":5.1}');
    assertRejected('{"maxPreviewRecords":0}');
    assertRejected('{"maxPreviewRecords":51}');
    assertRejected('{"maxPreviewRecords":true}');
    assertRejected('{"displayFormat":"unknown"}');
    assertRejected('{"includeInactive":"false"}');
    assertRejected('{"previewService":{}}');
    assertRejected('{"previewService":[]}');
    assertRejected('{"unknown":true}');
    assertRejected('{"displayFormat":"nameId","displayFormat":"nameRule"}');

    RecordHealthCheckInternalResult accepted = evaluate(
      '{"maxPreviewRecords":5.0}',
      null
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      accepted.status,
      'An integral JSON decimal must satisfy the integer parameter contract.'
    );
    Assert.areEqual(
      5,
      RecordHealthCheckDefTestPlugin.seenParameters.get('maxPreviewRecords'),
      'An accepted integral decimal must normalize to the declared integer value.'
    );
  }

  @IsTest
  static void definitionFailuresDoNotFallBack() {
    assertDefinitionRejected('NULL_DEFINITION');
    assertDefinitionRejected('THROW_DEFINITION');
    assertDefinitionRejected('QUERY_DEFINITION');
    assertDefinitionRejected('INVALID_DEFINITION');

    RecordHealthCheckInternalResult required = evaluate('{}', 'REQUIRED');
    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      required.status,
      'An absent required parameter must prevent evaluation.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.INVALID_APEX_PARAMETERS,
      required.reasonCode,
      'Missing required parameters must expose the stable parameter-validation reason.'
    );
    Assert.areEqual(
      0,
      RecordHealthCheckDefTestPlugin.evaluateCount,
      'Required-parameter rejection must happen before plugin evaluation.'
    );
  }

  @IsTest
  static void definitionCopiesMutableInputs() {
    List<String> choices = new List<String>{ 'one', 'two' };
    RecordHealthCheckPluginDefinition definition = new RecordHealthCheckPluginDefinition()
      .choiceParameter('format', 'one', choices);
    choices.clear();
    RecordHealthCheckPluginDefinition snapshot = definition.snapshot();
    Assert.areEqual(
      new List<String>{ 'one', 'two' },
      snapshot.parameter('format').choices,
      'Mutating the original choice list must not change the definition snapshot.'
    );
    snapshot.parameter('format').choices.clear();
    Assert.areEqual(
      2,
      definition.parameter('format').choices.size(),
      'Mutating a snapshot must not change the original definition choices.'
    );
  }

  @IsTest
  static void malformedBuilderContractsAreRejected() {
    assertMalformed(new DefinitionAttempt('DUPLICATE'));
    assertMalformed(new DefinitionAttempt('BAD_KEY'));
    assertMalformed(new DefinitionAttempt('BAD_BOUNDS'));
    assertMalformed(new DefinitionAttempt('BAD_CHOICE'));
    assertMalformed(new DefinitionAttempt('BAD_STRING'));
    assertMalformed(new DefinitionAttempt('MISSING_MODIFIER'));
    assertMalformed(new DefinitionAttempt('BAD_CAPACITY'));
  }

  @IsTest
  static void nullVersusAbsent() {
    evaluate('{}', null);
    Assert.areEqual(
      5,
      RecordHealthCheckDefTestPlugin.seenParameters.get('maxPreviewRecords'),
      'An absent parameter must receive its default rather than behave as explicit null.'
    );
    assertRejected('{"maxPreviewRecords":null}');

    RecordHealthCheckInternalResult nullable = evaluate(
      '{"maxPreviewRecords":null}',
      'NULLABLE'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      nullable.status,
      'Explicit null must be accepted for a nullable parameter.'
    );
    Assert.isTrue(
      RecordHealthCheckDefTestPlugin.seenParameters.containsKey(
        'maxPreviewRecords'
      ),
      'A nullable explicit null must retain the parameter key.'
    );
    Assert.isNull(
      RecordHealthCheckDefTestPlugin.seenParameters.get('maxPreviewRecords'),
      'A nullable explicit null must not be replaced by the default.'
    );
  }

  @IsTest
  static void providerOnceFenced() {
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      'SP-P-Definition-Fence'
    );
    reset('DML_DEFINITION');
    RecordHealthCheckDefTestPlugin.mutationAccountId = record.Id;
    Boolean fatalEscaped = false;

    Test.startTest();
    try {
      new RecordHealthCheckApexEvaluator()
        .evaluate(check('{}'), record.Id, record);
    } catch (RecordHealthCheckPluginDispatch.SideEffectException expected) {
      fatalEscaped = true;
    }
    Test.stopTest();

    Assert.isTrue(fatalEscaped, 'Definition DML must fail the outer fence.');
    Assert.areEqual(
      1,
      RecordHealthCheckDefTestPlugin.constructorCount,
      'A definition side effect must not cause a second plugin construction.'
    );
    Assert.areEqual(
      1,
      RecordHealthCheckDefTestPlugin.definitionCount,
      'The fenced definition provider must be called exactly once.'
    );
    Assert.areEqual(
      0,
      RecordHealthCheckDefTestPlugin.evaluateCount,
      'Definition DML must stop before evaluation is invoked.'
    );
  }

  @IsTest
  static void capacityFiveAndSix() {
    Map<Id, SObject> fiveRecords = accountScope(5);
    reset('CAPACITY');

    Test.startTest();
    Map<Id, RecordHealthCheckInternalResult> accepted = evaluateScope(
      fiveRecords
    );
    Test.stopTest();

    Assert.areEqual(
      5,
      accepted.size(),
      'A scope at the declared capacity must produce one result per record.'
    );
    for (RecordHealthCheckInternalResult result : accepted.values()) {
      Assert.areEqual(
        RecordHealthCheckStatus.PASS,
        result.status,
        'Every record within the declared capacity must remain evaluable.'
      );
    }
    Assert.areEqual(
      1,
      RecordHealthCheckDefTestPlugin.definitionCount,
      'The accepted scope must obtain its definition once for the whole scope.'
    );
    Assert.areEqual(
      1,
      RecordHealthCheckDefTestPlugin.evaluateCount,
      'The accepted scope must evaluate once in bulk.'
    );

    Map<Id, SObject> sixRecords = accountScope(6);
    reset('CAPACITY');
    Map<Id, RecordHealthCheckInternalResult> rejected = evaluateScope(
      sixRecords
    );
    Assert.areEqual(
      6,
      rejected.size(),
      'An oversized scope must still produce a rejection result for every record.'
    );
    for (RecordHealthCheckInternalResult result : rejected.values()) {
      Assert.areEqual(
        RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
        result.status,
        'Every record over the declared capacity must be unable to evaluate.'
      );
      Assert.areEqual(
        RecordHealthCheckReasonCodes.PLUGIN_SCOPE_LIMIT_EXCEEDED,
        result.reasonCode,
        'Capacity rejection must use the stable plugin scope-limit reason.'
      );
      Assert.areEqual(
        false,
        result.pluginInvoked,
        'Capacity rejection must not claim the plugin evaluated the record.'
      );
    }
    Assert.areEqual(
      1,
      RecordHealthCheckDefTestPlugin.definitionCount,
      'The oversized scope must inspect its capacity definition only once.'
    );
    Assert.areEqual(
      0,
      RecordHealthCheckDefTestPlugin.evaluateCount,
      'The oversized scope must never invoke plugin evaluation.'
    );
  }

  private static void assertRejected(String parametersJson) {
    RecordHealthCheckInternalResult result = evaluate(parametersJson, null);
    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      result.status,
      'Invalid parameter input must prevent a successful evaluation.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.INVALID_APEX_PARAMETERS,
      result.reasonCode,
      'Rejected parameter input must expose the stable parameter-validation reason.'
    );
    Assert.areEqual(
      0,
      RecordHealthCheckDefTestPlugin.evaluateCount,
      'Rejected parameters must never reach plugin evaluation.'
    );
  }

  private static Map<Id, RecordHealthCheckInternalResult> evaluateScope(
    Map<Id, SObject> records
  ) {
    return new RecordHealthCheckApexEvaluator()
      .evaluateScope(
        check('{}'),
        new List<Id>(records.keySet()),
        records,
        'Account',
        null,
        null
      );
  }

  private static Map<Id, SObject> accountScope(Integer size) {
    List<Account> accounts = new List<Account>();
    for (Integer index = 0; index < size; index++) {
      accounts.add(
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'SP-P-Capacity-' + index }
        )
      );
    }
    RecordHealthCheckTestDataFactory.accountsFixture(accounts);
    Map<Id, SObject> result = new Map<Id, SObject>();
    for (Account accountRecord : accounts) {
      result.put(accountRecord.Id, accountRecord);
    }
    return result;
  }

  private static void assertDefinitionRejected(String mode) {
    RecordHealthCheckInternalResult result = evaluate('{}', mode);
    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      result.status,
      'A broken definition provider must not fall back to legacy evaluation.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_DEFINITION_INVALID,
      result.reasonCode,
      'A broken definition provider must expose the stable definition-invalid reason.'
    );
    Assert.areEqual(
      1,
      RecordHealthCheckDefTestPlugin.definitionCount,
      'A broken definition provider must be attempted only once.'
    );
    Assert.areEqual(
      0,
      RecordHealthCheckDefTestPlugin.evaluateCount,
      'A broken definition provider must prevent plugin evaluation.'
    );
  }

  private static void assertMalformed(DefinitionAttempt attempt) {
    Boolean rejected = false;
    try {
      attempt.run();
    } catch (RecordHealthCheckPluginDefinition.DefinitionException expected) {
      rejected = true;
    }
    Assert.isTrue(rejected, 'Expected malformed definition: ' + attempt.mode);
  }

  private class DefinitionAttempt {
    private String mode;

    private DefinitionAttempt(String mode) {
      this.mode = mode;
    }

    private void run() {
      RecordHealthCheckPluginDefinition definition = new RecordHealthCheckPluginDefinition();
      if (mode == 'DUPLICATE') {
        definition.booleanParameter('key', false).booleanParameter('key', true);
      } else if (mode == 'BAD_KEY') {
        definition.booleanParameter('1bad', false);
      } else if (mode == 'BAD_BOUNDS') {
        definition.integerParameter('key', 5, 10, 1);
      } else if (mode == 'BAD_CHOICE') {
        definition.choiceParameter('key', 'missing', new List<String>{ 'one' });
      } else if (mode == 'BAD_STRING') {
        definition.stringParameter('key', null, 0);
      } else if (mode == 'MISSING_MODIFIER') {
        definition.required('missing', true);
      } else if (mode == 'BAD_CAPACITY') {
        definition.capacity(null, false, 'EXTREME');
      }
    }
  }

  private static RecordHealthCheckInternalResult evaluate(
    String parametersJson,
    String mode
  ) {
    reset(mode);
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      'SP-P-' + String.valueOf(mode) + '-' + parametersJson.length()
    );
    return new RecordHealthCheckApexEvaluator()
      .evaluate(check(parametersJson), record.Id, record);
  }

  private static void reset(String mode) {
    RecordHealthCheckDefTestPlugin.constructorCount = 0;
    RecordHealthCheckDefTestPlugin.definitionCount = 0;
    RecordHealthCheckDefTestPlugin.evaluateCount = 0;
    RecordHealthCheckDefTestPlugin.mode = mode;
    RecordHealthCheckDefTestPlugin.mutationAccountId = null;
    RecordHealthCheckDefTestPlugin.seenParameters = null;
  }

  private static Record_Health_Check__mdt check(String parametersJson) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'RHC_SP_Definition_Items',
        'QualifiedApiName' => 'RHC_SP_Definition_Items',
        'CheckTitle__c' => 'Definition parameters',
        'EvaluationType__c' => 'APEX',
        'ApexClass__c' => 'RecordHealthCheckDefTestPlugin',
        'ApexParametersJson__c' => parametersJson,
        'UnableToEvaluateMessage__c' => 'Definition could not be evaluated.'
      }
    );
  }
}
