/** Exercises supported framework boundaries as explicitly entitled restricted users. */
@IsTest
private with sharing class RecordHealthCheckRestrictedPersonaTest {
  private static final String SET_NAME = 'RHC_Persona_Access';
  private static final String ACCESSIBLE_CHECK = 'RHC_Persona_Accessible';

  @IsTest
  static void shouldContainFieldDenialWhenSiblingCheckIsAccessible() {
    if (assertNamespacedFixtureOrReturn()) {
      return;
    }
    PersonaFixture fixture = createFixture('rhcpfls', true, false);

    System.runAs(fixture.userRecord) {
      Test.startTest();
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(
            qualifiedSetName(),
            fixture.visibleRecord.Id
          )
          .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
      );
      Test.stopTest();

      Assert.areEqual(
        2,
        response.results.size(),
        'Both Checks must return aligned results.'
      );
      Assert.areEqual(
        RecordHealthCheckStatus.PASS,
        response.results[0].evaluation.status,
        'The accessible sibling Check must continue.'
      );
      Assert.areEqual(
        RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
        response.results[1].evaluation.status,
        'The restricted Check must degrade without aborting the Set.'
      );
      Assert.areEqual(
        RecordHealthCheckReasonCodes.CANNOT_EVALUATE,
        response.results[1].evaluation.reasonCode,
        'Public output must retain the existing sanitized access reason.'
      );
      Assert.isNull(
        response.results[1].display.adminDetail,
        'The User persona must not receive diagnostics.'
      );
      Assert.isFalse(
        JSON.serialize(response).contains('RESTRICTED_SENTINEL'),
        'Restricted field content must never enter the response.'
      );
    }
  }

  @IsTest
  static void shouldReturnRecordNotVisibleWhenSharingOmitsRecord() {
    if (assertNamespacedFixtureOrReturn()) {
      return;
    }
    PersonaFixture fixture = createFixture('rhcphid', true, false);

    System.runAs(fixture.userRecord) {
      Test.startTest();
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(
          qualifiedSetName(),
          new List<Id>{ fixture.visibleRecord.Id, fixture.hiddenRecord.Id }
        )
      );
      RecordHealthCheckResponse reverseResponse = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(
          qualifiedSetName(),
          new List<Id>{ fixture.hiddenRecord.Id, fixture.visibleRecord.Id }
        )
      );
      RecordHealthCheckResultItem controllerItem = RecordHealthCheckController.evaluateCheck(
        qualifiedSetName(),
        qualifiedCheckName(),
        fixture.hiddenRecord.Id,
        'persona-hidden-controller',
        RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
      );
      Test.stopTest();

      Assert.areEqual(
        4,
        response.results.size(),
        'Two records and two Checks must yield four aligned results.'
      );
      Assert.areEqual(
        fixture.hiddenRecord.Id,
        response.results[2].evaluation.recordId,
        'Input order must be preserved for the hidden record.'
      );
      Assert.areEqual(
        'RECORD_NOT_VISIBLE',
        response.results[2].evaluation.reasonCode,
        'Actual sharing omission must produce the stable visibility outcome.'
      );
      Assert.areEqual(
        'RECORD_NOT_VISIBLE',
        response.results[3].evaluation.reasonCode,
        'Every selected Check must receive the visibility outcome.'
      );
      Assert.areEqual(
        fixture.hiddenRecord.Id,
        reverseResponse.results[0].evaluation.recordId,
        'Reverse mixed scope must preserve caller order.'
      );
      Assert.areEqual(
        'RECORD_NOT_VISIBLE',
        reverseResponse.results[0].evaluation.reasonCode,
        'Reverse mixed scope must contain hidden-record access.'
      );
      Assert.areEqual(
        'RECORD_NOT_VISIBLE',
        reverseResponse.results[1].evaluation.reasonCode,
        'Every Check in the reverse mixed scope must be complete.'
      );
      Assert.areEqual(
        'RECORD_NOT_VISIBLE',
        controllerItem.evaluation.reasonCode,
        'Controller and public facade must agree for a hidden record.'
      );
      Assert.isFalse(
        JSON.serialize(response).contains('HIDDEN_SENTINEL'),
        'Hidden record content must not enter the response.'
      );
    }
  }

  @IsTest
  static void shouldDriveControllerAndFlowWhenUserPermissionAssigned() {
    if (assertNamespacedFixtureOrReturn()) {
      return;
    }
    PersonaFixture fixture = createFixture('rhcpbnd', true, false);

    System.runAs(fixture.userRecord) {
      String qualifiedSet = qualifiedSetName();
      String qualifiedCheck = qualifiedCheckName();
      RecordHealthCheckRunCheckFlowAction.Request checkInput = new RecordHealthCheckRunCheckFlowAction.Request();
      checkInput.checkQualifiedApiName = qualifiedCheck;
      checkInput.recordId = fixture.visibleRecord.Id;
      checkInput.eventPublication = 'NONE';
      RecordHealthCheckRunSetFlowAction.Request setInput = new RecordHealthCheckRunSetFlowAction.Request();
      setInput.checkSetQualifiedApiName = qualifiedSet;
      setInput.recordId = fixture.visibleRecord.Id;
      setInput.eventPublication = 'NONE';

      Test.startTest();
      RecordHealthCheckSetAvailability availability = RecordHealthCheckController.getCheckSetAvailabilityForRecord(
        fixture.visibleRecord.Id
      );
      RecordHealthCheckDefinitionResponse definitions = RecordHealthCheckController.getCheckDefinitions(
        qualifiedSet,
        fixture.visibleRecord.Id,
        'persona-definitions'
      );
      RecordHealthCheckResultItem item = RecordHealthCheckController.evaluateCheck(
        qualifiedSet,
        qualifiedCheck,
        fixture.visibleRecord.Id,
        'persona-controller',
        RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
      );
      List<RecordHealthCheckRunCheckFlowAction.Response> checkOutputs = RecordHealthCheckRunCheckFlowAction.runCheck(
        new List<RecordHealthCheckRunCheckFlowAction.Request>{ checkInput }
      );
      List<RecordHealthCheckRunSetFlowAction.Response> setOutputs = RecordHealthCheckRunSetFlowAction.runSet(
        new List<RecordHealthCheckRunSetFlowAction.Request>{ setInput }
      );
      Test.stopTest();

      Assert.isTrue(
        availability.hasActive,
        'The entitled user must see the active Set.'
      );
      Assert.areEqual(
        2,
        definitions.checks.size(),
        'Both definitions must load.'
      );
      Assert.areEqual(
        RecordHealthCheckStatus.PASS,
        item.evaluation.status,
        'Controller evaluation must succeed.'
      );
      Assert.isTrue(
        checkOutputs[0].isSuccess,
        'Check Flow action must succeed.'
      );
      Assert.isTrue(setOutputs[0].isSuccess, 'Set Flow action must succeed.');
    }
  }

  @IsTest
  static void shouldDenyEveryBoundaryWhenRunPermissionMissing() {
    PersonaFixture fixture = createFixture('rhcpno', false, false);

    System.runAs(fixture.userRecord) {
      RecordHealthCheckAccess.setRunPermissionForTest(false);
      Test.startTest();
      try {
        try {
          RecordHealthCheck.evaluate(
            RecordHealthCheckRequest.forCheckSet(
              qualifiedSetName(),
              fixture.visibleRecord.Id
            )
          );
          Assert.fail('The public facade must deny an unentitled user.');
        } catch (RecordHealthCheckAccess.AuthorizationException expected) {
          Assert.isTrue(
            expected.getMessage().contains('NOT_AUTHORIZED'),
            'The facade must use the stable authorization code.'
          );
        }
        try {
          RecordHealthCheckController.getCheckSetAvailabilityForRecord(
            fixture.visibleRecord.Id
          );
          Assert.fail('The controller must deny an unentitled user.');
        } catch (AuraHandledException expected) {
          Assert.isTrue(
            expected.getMessage().contains('NOT_AUTHORIZED'),
            'Aura denial must use the stable code.'
          );
        }
        RecordHealthCheckRunSetFlowAction.Request input = new RecordHealthCheckRunSetFlowAction.Request();
        input.checkSetQualifiedApiName = qualifiedSetName();
        input.recordId = fixture.visibleRecord.Id;
        input.eventPublication = 'NONE';
        List<RecordHealthCheckRunSetFlowAction.Response> outputs = RecordHealthCheckRunSetFlowAction.runSet(
          new List<RecordHealthCheckRunSetFlowAction.Request>{ input }
        );
        try {
          RecordHealthCheckQueueable.enqueue(
            qualifiedSetName(),
            new List<Id>{ fixture.visibleRecord.Id },
            RecordHealthCheckEventPublication.NONE
          );
          Assert.fail('Queueable submission must be denied before enqueue.');
        } catch (RecordHealthCheckAccess.AuthorizationException expected) {
          Assert.isTrue(
            expected.getMessage().contains('NOT_AUTHORIZED'),
            'Queueable denial must use the stable code.'
          );
        }
        Test.stopTest();

        Assert.isFalse(
          outputs[0].isSuccess,
          'Flow must return an aligned denial.'
        );
        Assert.areEqual(
          'AUTHORIZATION',
          outputs[0].errorType,
          'Flow must classify authorization separately.'
        );
      } finally {
        RecordHealthCheckAccess.setRunPermissionForTest(null);
      }
    }
  }

  @IsTest
  static void shouldExposeDiagnosticReasonOnlyWhenAdminPermissionAssigned() {
    if (assertNamespacedFixtureOrReturn()) {
      return;
    }
    PersonaFixture fixture = createFixture('rhcpadm', false, true);

    System.runAs(fixture.userRecord) {
      Test.startTest();
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(
            qualifiedSetName(),
            fixture.visibleRecord.Id
          )
          .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
      );
      Test.stopTest();

      RecordHealthCheckAdminDetail detail = response.results[1]
        .display.adminDetail;
      Assert.isNotNull(
        detail,
        'The Admin persona may receive opted-in diagnostics.'
      );
      Assert.areEqual(
        RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE,
        detail.reasonCode,
        'Diagnostics may identify FLS denial without exposing the field value.'
      );
      Assert.isFalse(
        JSON.serialize(response).contains('RESTRICTED_SENTINEL'),
        'Diagnostics must not contain the restricted value.'
      );
    }
  }

  @IsTest
  static void shouldKeepMcpPersonaOutsideLifecycleEventChannels() {
    User integrationUser = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      'rhcmcp'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      integrationUser,
      'Record_Health_Check_MCP_Integration'
    );

    System.runAs(integrationUser) {
      Test.startTest();
      Boolean canRun = RecordHealthCheckAccess.canRunChecks();
      Boolean canPublishSetRuns = Schema.SObjectType.Record_Health_Check_Set_Run__e.isCreateable();
      Boolean canSubscribeSetRuns = Schema.SObjectType.Record_Health_Check_Set_Run__e.isAccessible();
      Boolean canPublishResults = Schema.SObjectType.Record_Health_Check_Result__e.isCreateable();
      Boolean canSubscribeResults = Schema.SObjectType.Record_Health_Check_Result__e.isAccessible();
      Test.stopTest();

      Assert.isTrue(
        canRun,
        'The dedicated MCP persona must retain the packaged run entitlement.'
      );
      Assert.isFalse(
        canPublishSetRuns,
        'The MCP persona must not publish Set Run lifecycle events directly.'
      );
      Assert.isFalse(
        canSubscribeSetRuns,
        'The MCP persona must not subscribe to Set Run lifecycle events.'
      );
      Assert.isFalse(
        canPublishResults,
        'The MCP persona must not publish Result lifecycle events directly.'
      );
      Assert.isFalse(
        canSubscribeResults,
        'The MCP persona must not subscribe to Result lifecycle events.'
      );
    }
  }

  /** @return True after proving this namespaced-only fixture is intentionally absent. */
  private static Boolean assertNamespacedFixtureOrReturn() {
    if (Schema.getGlobalDescribe().containsKey('rhc__RHC_Persona_Record__c')) {
      return false;
    }
    Assert.isNull(
      Schema.getGlobalDescribe().get('rhc__RHC_Persona_Record__c'),
      'The namespaced restricted-persona fixture must remain absent in portable source orgs.'
    );
    return true;
  }

  private static PersonaFixture createFixture(
    String alias,
    Boolean assignUserPermission,
    Boolean assignAdminPermission
  ) {
    PersonaFixture fixture = new PersonaFixture();
    fixture.userRecord = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      alias
    );
    if (assignUserPermission) {
      RecordHealthCheckTestDataFactory.assignPermissionSet(
        fixture.userRecord,
        'Record_Health_Check_User'
      );
    }
    if (assignAdminPermission) {
      RecordHealthCheckTestDataFactory.assignPermissionSet(
        fixture.userRecord,
        'Record_Health_Check_Admin'
      );
    }
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      fixture.userRecord,
      'Record_Health_Check_Persona_Record_Access'
    );
    fixture.visibleRecord = RHCIntegrationTestDataFactory.personaRecord(
      'VISIBLE_SENTINEL',
      'RESTRICTED_SENTINEL'
    );
    fixture.hiddenRecord = RHCIntegrationTestDataFactory.personaRecord(
      'HIDDEN_SENTINEL',
      'HIDDEN_RESTRICTED_SENTINEL'
    );
    RHCIntegrationTestDataFactory.sharePersonaRecord(
      fixture.visibleRecord.Id,
      fixture.userRecord.Id
    );
    return fixture;
  }

  private static String qualifiedSetName() {
    return RecordHealthCheckTestDataFactory.qualifiedCheckSetName(SET_NAME);
  }

  private static String qualifiedCheckName() {
    return RecordHealthCheckTestDataFactory.qualifiedCheckName(
      ACCESSIBLE_CHECK
    );
  }

  private class PersonaFixture {
    private User userRecord;
    private RHC_Persona_Record__c visibleRecord;
    private RHC_Persona_Record__c hiddenRecord;
  }
}
