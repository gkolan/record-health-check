/** Regression-first acceptance tests for subscriber plugin definitions. */
@IsTest
private class RHCSubscriberDefinitionSpecTest {
  @IsTest
  static void defaultSchemaValues() {
    RecordHealthCheckInternalResult result = evaluate('{}', null);

    Assert.areEqual(RecordHealthCheckStatus.PASS, result.status);
    Assert.areEqual(1, RecordHealthCheckDefTestPlugin.constructorCount);
    Assert.areEqual(1, RecordHealthCheckDefTestPlugin.definitionCount);
    Assert.areEqual(1, RecordHealthCheckDefTestPlugin.evaluateCount);
    Assert.areEqual(
      5,
      RecordHealthCheckDefTestPlugin.seenParameters.get('maxPreviewRecords')
    );
    Assert.areEqual(
      'nameId',
      RecordHealthCheckDefTestPlugin.seenParameters.get('displayFormat')
    );
    Assert.areEqual(
      'QuoteInactiveApproverPreviewService',
      RecordHealthCheckDefTestPlugin.seenParameters.get('previewService')
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
    Assert.areEqual(RecordHealthCheckStatus.PASS, accepted.status);
    Assert.areEqual(
      5,
      RecordHealthCheckDefTestPlugin.seenParameters.get('maxPreviewRecords')
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
      required.status
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.INVALID_APEX_PARAMETERS,
      required.reasonCode
    );
    Assert.areEqual(0, RecordHealthCheckDefTestPlugin.evaluateCount);
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
      snapshot.parameter('format').choices
    );
    snapshot.parameter('format').choices.clear();
    Assert.areEqual(2, definition.parameter('format').choices.size());
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
      RecordHealthCheckDefTestPlugin.seenParameters.get('maxPreviewRecords')
    );
    assertRejected('{"maxPreviewRecords":null}');

    RecordHealthCheckInternalResult nullable = evaluate(
      '{"maxPreviewRecords":null}',
      'NULLABLE'
    );
    Assert.areEqual(RecordHealthCheckStatus.PASS, nullable.status);
    Assert.isTrue(
      RecordHealthCheckDefTestPlugin.seenParameters.containsKey(
        'maxPreviewRecords'
      )
    );
    Assert.isNull(
      RecordHealthCheckDefTestPlugin.seenParameters.get('maxPreviewRecords')
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
    Assert.areEqual(1, RecordHealthCheckDefTestPlugin.constructorCount);
    Assert.areEqual(1, RecordHealthCheckDefTestPlugin.definitionCount);
    Assert.areEqual(0, RecordHealthCheckDefTestPlugin.evaluateCount);
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

    Assert.areEqual(5, accepted.size());
    for (RecordHealthCheckInternalResult result : accepted.values()) {
      Assert.areEqual(RecordHealthCheckStatus.PASS, result.status);
    }
    Assert.areEqual(1, RecordHealthCheckDefTestPlugin.definitionCount);
    Assert.areEqual(1, RecordHealthCheckDefTestPlugin.evaluateCount);

    Map<Id, SObject> sixRecords = accountScope(6);
    reset('CAPACITY');
    Map<Id, RecordHealthCheckInternalResult> rejected = evaluateScope(
      sixRecords
    );
    Assert.areEqual(6, rejected.size());
    for (RecordHealthCheckInternalResult result : rejected.values()) {
      Assert.areEqual(
        RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
        result.status
      );
      Assert.areEqual(
        RecordHealthCheckReasonCodes.PLUGIN_SCOPE_LIMIT_EXCEEDED,
        result.reasonCode
      );
      Assert.areEqual(false, result.pluginInvoked);
    }
    Assert.areEqual(1, RecordHealthCheckDefTestPlugin.definitionCount);
    Assert.areEqual(0, RecordHealthCheckDefTestPlugin.evaluateCount);
  }

  @IsTest
  static void isolateOneRecord() {
    Id passingId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      7101
    );
    Id throwingId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      7102
    );
    Id failingId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      7103
    );
    ControlledRecordEvaluator evaluator = new ControlledRecordEvaluator(
      new Map<Id, String>{
        passingId => 'PASS',
        throwingId => 'THROW',
        failingId => 'FAIL'
      }
    );
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();

    for (Id recordId : new List<Id>{ passingId, throwingId, failingId }) {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.tryEvaluate(recordId, evaluator)
      );
    }

    Assert.areEqual(3, outcomes.size());
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      outcomes.get(passingId).status
    );
    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      outcomes.get(throwingId).status
    );
    Assert.areEqual(
      'RECORD_EVALUATION_FAILED',
      outcomes.get(throwingId).reasonCode
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      outcomes.get(failingId).status
    );
    Assert.areEqual(3, evaluator.invocationCount);
  }

  @IsTest
  static void fatalNotSwallowed() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      7201
    );
    ControlledRecordEvaluator evaluator = new ControlledRecordEvaluator(
      new Map<Id, String>{ recordId => 'SIDE_EFFECT' }
    );
    Boolean escaped = false;
    try {
      RecordHealthCheckOutcome.tryEvaluate(recordId, evaluator);
    } catch (RecordHealthCheckPluginDispatch.SideEffectException expected) {
      escaped = true;
    }
    Assert.isTrue(escaped);
    Assert.areEqual(1, evaluator.invocationCount);
    evaluator = new ControlledRecordEvaluator(
      new Map<Id, String>{ recordId => 'FATAL_MARKER' }
    );
    escaped = false;
    try {
      RecordHealthCheckOutcome.tryEvaluate(recordId, evaluator);
    } catch (FatalRecordException expected) {
      escaped = true;
    }
    Assert.isTrue(escaped);
    Assert.areEqual(1, evaluator.invocationCount);
    assertInvalidRecordEvaluator(null, evaluator);
    assertInvalidRecordEvaluator(recordId, null);
  }

  private static void assertRejected(String parametersJson) {
    RecordHealthCheckInternalResult result = evaluate(parametersJson, null);
    Assert.areEqual(RecordHealthCheckStatus.UNABLE_TO_EVALUATE, result.status);
    Assert.areEqual(
      RecordHealthCheckReasonCodes.INVALID_APEX_PARAMETERS,
      result.reasonCode
    );
    Assert.areEqual(0, RecordHealthCheckDefTestPlugin.evaluateCount);
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

  private static void assertInvalidRecordEvaluator(
    Id recordId,
    RecordHealthCheckRecordEvaluator evaluator
  ) {
    Boolean rejected = false;
    try {
      RecordHealthCheckOutcome.tryEvaluate(recordId, evaluator);
    } catch (RecordHealthCheckOutcomeBuilderException expected) {
      rejected = expected.getMessage() == 'INVALID_RECORD_EVALUATOR';
    }
    Assert.isTrue(rejected);
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
    Assert.areEqual(RecordHealthCheckStatus.UNABLE_TO_EVALUATE, result.status);
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_DEFINITION_INVALID,
      result.reasonCode
    );
    Assert.areEqual(1, RecordHealthCheckDefTestPlugin.definitionCount);
    Assert.areEqual(0, RecordHealthCheckDefTestPlugin.evaluateCount);
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

  private class ControlledRecordEvaluator implements RecordHealthCheckRecordEvaluator {
    private Map<Id, String> modes;
    private Integer invocationCount = 0;

    private ControlledRecordEvaluator(Map<Id, String> modes) {
      this.modes = modes;
    }

    public RecordHealthCheckOutcome evaluateRecord(Id recordId) {
      invocationCount++;
      String mode = modes.get(recordId);
      if (mode == 'THROW') {
        throw new DeliberateRecordException('secret record-specific detail');
      }
      if (mode == 'SIDE_EFFECT') {
        RecordHealthCheckPluginDispatch.SideEffectException fatal = new RecordHealthCheckPluginDispatch.SideEffectException(
          'Synthetic fatal side effect.'
        );
        fatal.reasonCode = RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED;
        throw fatal;
      }
      if (mode == 'FATAL_MARKER') {
        throw new FatalRecordException('Synthetic framework-fatal marker.');
      }
      return mode == 'PASS'
        ? RecordHealthCheckOutcome.passEquals(
            'RECORD_OK',
            RecordHealthCheckValue.ofBoolean(true),
            RecordHealthCheckValue.ofBoolean(true)
          )
        : RecordHealthCheckOutcome.failEquals(
            'RECORD_REVIEW',
            RecordHealthCheckValue.ofBoolean(false),
            RecordHealthCheckValue.ofBoolean(true)
          );
    }
  }

  private class DeliberateRecordException extends Exception {
  }

  private class FatalRecordException extends Exception implements RecordHealthCheckFatalFailure {
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
