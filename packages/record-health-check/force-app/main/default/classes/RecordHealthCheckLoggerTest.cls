/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckLoggerTest {
  private class FixedSettingsProvider extends RecordHealthCheckSettingsProvider {
    private Boolean enabled;
    FixedSettingsProvider(Boolean enabled) {
      this.enabled = enabled;
    }
    public override Boolean isErrorEventPublicationEnabled(
      String checkSetDeveloperName
    ) {
      return enabled;
    }
  }

  private class PublishedCheckSettingsProvider extends RecordHealthCheckSettingsProvider {
    protected override List<Record_Health_Check__mdt> queryPublishedChecks(
      String checkSetQualifiedApiName
    ) {
      return new List<Record_Health_Check__mdt>{
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{ 'QualifiedApiName' => 'Published_Check' }
        )
      };
    }
  }

  // The logger writes to the Apex debug log (something we cannot read back in
  // a test context), so these tests exercise every branch for coverage and assert
  // that no path throws. The rendered output is verified by reading debug logs in
  // the org; here we guarantee the logging API is exception-safe for all inputs.

  @IsTest
  static void instanceLevelsBufferOnlyError() {
    RecordHealthCheckLogger.settingsProvider = new FixedSettingsProvider(true);
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-123',
      'Example_Account_Relationship_Risk',
      UserInfo.getUserId()
    );

    Test.startTest();
    logger.debug(
      'Some_Check',
      'START',
      new Map<String, Object>{ 'type' => 'FORMULA', 'showDiagnostics' => true }
    );
    logger.info(
      'Some_Check',
      'RESULT',
      new Map<String, Object>{ 'status' => 'FAIL' }
    );
    logger.warn('Some_Check', 'METADATA_INVALID', null);
    logger.error(
      'Some_Check',
      'UNHANDLED_EXCEPTION',
      null,
      new System.NullPointerException()
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      RecordHealthCheckLogger.pendingEventCount(),
      'Only the ERROR call must produce a durable log event.'
    );
  }

  @IsTest
  static void staticErrorBuffersOneEvent() {
    RecordHealthCheckLogger.settingsProvider = new FixedSettingsProvider(true);
    Test.startTest();
    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.ERROR,
      'run-456',
      'Example_Account_Relationship_Risk',
      UserInfo.getUserId(),
      null,
      'CONFIG_UNEXPECTED',
      null,
      new System.NullPointerException()
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      RecordHealthCheckLogger.pendingEventCount(),
      'The static ERROR entry point must buffer one durable event.'
    );
  }

  @IsTest
  static void blankContextInfoDoesNotBuffer() {
    // Defensive paths: missing correlation id and no record context must not throw.
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      null,
      null,
      null
    );

    Test.startTest();
    logger.info(null, 'NO_CONTEXT', new Map<String, Object>());
    Test.stopTest();

    Assert.areEqual(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'An INFO entry with blank context must not create a durable error event.'
    );
  }

  // ─── Platform-event ERROR destination (Record_Health_Check_Log__e) ───────────

  @IsTest
  static void errorBuffersEventWithReproContext() {
    Id recordId = UserInfo.getUserId();
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-err-1',
      'Example_Account_Relationship_Risk',
      recordId
    );

    logger.error(
      'Owner_Is_Active',
      'UNHANDLED_EXCEPTION',
      null,
      new System.NullPointerException()
    );

    List<Record_Health_Check_Log__e> pending = RecordHealthCheckLogger.pendingEventsForTest();
    Assert.areEqual(1, pending.size(), 'One ERROR event should buffer.');
    Record_Health_Check_Log__e evt = pending[0];
    Assert.areEqual('ERROR', evt.Level__c, 'Level is ERROR.');
    Assert.areEqual('run-err-1', evt.RunId__c, 'RunId correlates the run.');
    Assert.areEqual(
      String.valueOf(recordId),
      evt.RecordId__c,
      'RecordId identifies where the error happened.'
    );
    Assert.areEqual(
      'Example_Account_Relationship_Risk',
      evt.CheckSetDeveloperName__c,
      'Check Set context is the canonical contract name.'
    );
    Assert.areEqual(
      'Owner_Is_Active',
      evt.CheckDeveloperName__c,
      'Check context is the canonical contract name.'
    );
    Assert.areEqual('UNHANDLED_EXCEPTION', evt.Code__c, 'Code is the event.');
    Assert.isTrue(
      evt.ExceptionType__c.contains('NullPointer'),
      'Exception type is captured for reproduction.'
    );
    Assert.areNotEqual(null, evt.StackTrace__c, 'Stack trace is captured.');
    Assert.areEqual('1.0', evt.ContractVersion__c, 'Versioned contract.');
    Assert.areNotEqual(null, evt.EventId__c, 'Event has a dedupe id.');
    Assert.areEqual(
      UserInfo.getUserId(),
      evt.UserId__c,
      'Running user is attributed authoritatively.'
    );

    Test.startTest();
    RecordHealthCheckLogger.flush();
    Test.stopTest();

    Assert.areEqual(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'flush() clears the buffer.'
    );
  }

  @IsTest
  static void nonErrorLevelsDoNotBuffer() {
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-noise',
      'Account_Compliance_Audit',
      UserInfo.getUserId()
    );

    logger.debug('C', 'START', null);
    logger.info('C', 'RESULT', new Map<String, Object>{ 'status' => 'FAIL' });
    logger.warn('C', 'METADATA_INVALID', null);

    Assert.areEqual(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'Only ERROR buffers a durable event; WARN/INFO/DEBUG do not.'
    );
  }

  @IsTest
  static void messageFallsBackToFieldsWhenNoException() {
    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.ERROR,
      'run-nofields',
      'Example_Account_Relationship_Risk',
      UserInfo.getUserId(),
      'Owner_Is_Active',
      'CHECK_ERROR',
      new Map<String, Object>{ 'reasonCode' => 'APEX_EVALUATOR_ERROR' },
      null
    );

    List<Record_Health_Check_Log__e> pending = RecordHealthCheckLogger.pendingEventsForTest();
    Assert.areEqual(1, pending.size(), 'Static ERROR path buffers.');
    Assert.areEqual(
      null,
      pending[0].ExceptionType__c,
      'No exception type when ex is null.'
    );
    Assert.isTrue(
      pending[0].Message__c.contains('reasonCode=APEX_EVALUATOR_ERROR'),
      'Message falls back to a compact field summary.'
    );
    Map<String, Object> details = (Map<String, Object>) JSON.deserializeUntyped(
      pending[0].DetailsJson__c
    );
    Assert.areEqual(
      'APEX_EVALUATOR_ERROR',
      details.get('reasonCode'),
      'Structured fields must remain independently queryable.'
    );
  }

  @IsTest
  static void checkSetOptOutSuppressesBuffering() {
    RecordHealthCheckLogger.settingsProvider = new FixedSettingsProvider(false);
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-off',
      'Example_Account_Relationship_Risk',
      UserInfo.getUserId()
    );

    logger.error(
      'C',
      'UNHANDLED_EXCEPTION',
      null,
      new System.NullPointerException()
    );

    Assert.areEqual(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'The Check Set opt-out suppresses the durable event (System.debug still fires).'
    );
  }

  @IsTest
  static void missingCheckSetDefaultsToPublishing() {
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-missing-config',
      'Check_Set_That_Does_Not_Exist',
      UserInfo.getUserId()
    );

    logger.error(
      null,
      'CONFIG_NOT_FOUND',
      null,
      new System.NullPointerException()
    );

    Assert.areEqual(
      1,
      RecordHealthCheckLogger.pendingEventCount(),
      'A missing Check Set must preserve default-on error publication.'
    );
  }

  @IsTest
  static void configuredCheckSetPublishesWhenDefaultOn() {
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-configured',
      'Example_Account_Relationship_Risk',
      UserInfo.getUserId()
    );

    logger.error(
      null,
      'CONFIGURED_SET_ERROR',
      null,
      new System.NullPointerException()
    );

    Assert.areEqual(
      1,
      RecordHealthCheckLogger.pendingEventCount(),
      'A configured Check Set with the default-on field must publish.'
    );
  }

  @IsTest
  static void subscriberContextPreventsFeedbackLoop() {
    RecordHealthCheckLogger.enterSubscriberContext();
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-sub',
      'Example_Account_Relationship_Risk',
      UserInfo.getUserId()
    );

    logger.error(
      'C',
      'UNHANDLED_EXCEPTION',
      null,
      new System.NullPointerException()
    );

    Assert.areEqual(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'A subscriber logging an error must not republish onto the same bus.'
    );
  }

  @IsTest
  static void flushIsSafeWhenBufferEmpty() {
    Test.startTest();
    RecordHealthCheckLogger.flush();
    Test.stopTest();

    Assert.areEqual(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'flush() on an empty buffer is a no-op and does not throw.'
    );
  }

  @IsTest
  static void blankCheckSetAndEmptyFieldsUseSafeErrorDefaults() {
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-defaults',
      ' ',
      UserInfo.getUserId()
    );

    Test.startTest();
    logger.error('Check_A', 'EMPTY_CONTEXT', new Map<String, Object>(), null);
    Test.stopTest();

    List<Record_Health_Check_Log__e> pending = RecordHealthCheckLogger.pendingEventsForTest();
    Assert.areEqual(
      1,
      pending.size(),
      'A missing Check Set must retain default-on ERROR publication.'
    );
    Assert.isNull(
      pending[0].Message__c,
      'Empty fields without an exception must not invent a message.'
    );
  }

  @IsTest
  static void settingsProviderReturnsConfiguredPublicationChecks() {
    String checkSetName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Profile_Readiness'
    );

    Test.startTest();
    RecordHealthCheckLogger.pendingEventsForTest();
    Set<String> published = new PublishedCheckSettingsProvider()
      .publishedCheckNames(checkSetName);
    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.DEBUG,
      'debug-run',
      checkSetName,
      UserInfo.getUserId(),
      null,
      'DEBUG_BRANCH',
      null,
      null
    );
    Test.stopTest();

    Assert.areEqual(
      new Set<String>{ 'Published_Check' },
      published,
      'The settings provider must return every Check selected for publication.'
    );
  }
}
