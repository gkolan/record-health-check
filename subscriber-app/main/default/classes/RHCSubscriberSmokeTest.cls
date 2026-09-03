/**
 * External subscriber smoke tests for an installed Record Health Check package.
 * These classes are subscriber-owned and must not call internal package test utilities.
 */
@IsTest
private class RHCSubscriberSmokeTest {
  @TestSetup
  static void assignRunnerAccess() {
    RHCSubscriberTestDataFactory.assignPackagedPermissionSet(
      UserInfo.getUserId(),
      'Record_Health_Check_User'
    );
  }

  @IsTest
  static void installedPackageIsPresent() {
    System.assertEquals(
      true,
      RHCSubscriberTestDataFactory.isPackageInstalled(),
      'Record Health Check must be installed as the rhc package.'
    );
  }

  @IsTest
  static void installedMetadataValidationActionExecutes() {
    rhc.RecordHealthCheckValidateMetadataAction.Result output = rhc.RecordHealthCheckValidateMetadataAction.validateConfiguration()[0];

    Assert.isNotNull(
      output.reportJson,
      'The installed metadata-validation invocable must return a structured report.'
    );
    Assert.areEqual(
      0,
      output.errorCount,
      'The packaged and subscriber release fixtures must pass metadata validation: ' +
      output.reportJson
    );
    Assert.isTrue(
      output.isValid,
      'The installed metadata-validation invocable must report the release fixture as valid.'
    );
  }

  @IsTest
  static void demoCheckSetEvaluatesThroughPublicApi() {
    System.assertEquals(
      true,
      RHCSubscriberTestDataFactory.isPackageInstalled(),
      'Package install is required before smoke evaluation.'
    );

    String checkSetName = RHCSubscriberTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );
    Account accountRecord = RHCSubscriberTestDataFactory.createAccount(
      'Subscriber Smoke Account'
    );

    rhc.RecordHealthCheckRequest request = rhc.RecordHealthCheckRequest.forCheckSet(
      checkSetName,
      accountRecord.Id
    );
    rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
      request
    );

    System.assertNotEquals(null, response, 'Evaluate must return a response.');
    System.assert(
      !response.results.isEmpty(),
      'The Demo Check Set must return at least one Check result.'
    );
    System.assert(
      response.summary.passed +
      response.summary.failed +
      response.summary.skipped +
      response.summary.unable + response.summary.systemError > 0,
      'The run summary must reflect terminal outcomes.'
    );
  }

  @IsTest
  static void packagedCheckSetContainsEveryEvaluationType() {
    Set<String> evaluationTypes = new Set<String>();
    for (rhc__Record_Health_Check__mdt configuredCheck : [
      SELECT rhc__EvaluationType__c
      FROM rhc__Record_Health_Check__mdt
      WHERE
        rhc__Record_Health_Check_Set__r.DeveloperName = 'Example_Account_Check_Builder_Guide'
    ]) {
      evaluationTypes.add(configuredCheck.rhc__EvaluationType__c);
    }

    Assert.areEqual(
      new Set<String>{ 'APEX', 'COMPARE_TWO_QUERIES', 'FORMULA', 'QUERY' },
      evaluationTypes,
      'The installed release-matrix Check Set must contain all supported evaluation types.'
    );
  }

  @IsTest
  static void subscriberOnLoadSetContainsEveryEvaluationType() {
    Set<String> evaluationTypes = new Set<String>();
    for (rhc__Record_Health_Check__mdt configuredCheck : [
      SELECT rhc__EvaluationType__c
      FROM rhc__Record_Health_Check__mdt
      WHERE rhc__Record_Health_Check_Set__r.DeveloperName = 'Subscriber_On_Load'
    ]) {
      evaluationTypes.add(configuredCheck.rhc__EvaluationType__c);
    }

    Assert.areEqual(
      new Set<String>{ 'APEX', 'COMPARE_TWO_QUERIES', 'FORMULA', 'QUERY' },
      evaluationTypes,
      'The subscriber-owned on-load Check Set must retain every evaluator type across install and upgrade.'
    );
  }

  @IsTest
  static void installedAgentActionExecutesReleaseMatrixSet() {
    Account accountRecord = RHCSubscriberTestDataFactory.createAccount(
      'Subscriber Agent Action Matrix'
    );
    rhc.RecordHealthCheckRunSetAgentAction.Request input = new rhc.RecordHealthCheckRunSetAgentAction.Request();
    input.recordId = accountRecord.Id;
    input.qualifiedApiName = RHCSubscriberTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );
    input.correlationId = 'subscriber-agent-matrix';

    Test.startTest();
    rhc.RecordHealthCheckRunSetAgentAction.Response output = rhc.RecordHealthCheckRunSetAgentAction.runSet(
      new List<rhc.RecordHealthCheckRunSetAgentAction.Request>{ input }
    )[0];
    Test.stopTest();

    Assert.isTrue(
      output.success,
      'The installed native Agent action must succeed.'
    );
    Assert.areEqual(
      25,
      output.passed +
        output.failed +
        output.skipped +
        output.unable +
        output.systemError,
      'The installed native Agent action must account for every Check in the four-evaluator release set.'
    );
  }

  @IsTest
  static void installedPlatformEventsCoverReleaseMatrixSet() {
    Account accountRecord = RHCSubscriberTestDataFactory.createAccount(
      'Subscriber Platform Event Matrix'
    );
    RHCSubscriberEventReceipt.reset();

    Test.startTest();
    rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
      rhc.RecordHealthCheckRequest.forCheckSet(
          RHCSubscriberTestDataFactory.qualifiedCheckSetName(
            'Example_Account_Check_Builder_Guide'
          ),
          accountRecord.Id
        )
        .withEventPublication(rhc.RecordHealthCheckEventPublication.ALL)
    );
    Test.getEventBus().deliver();
    Test.stopTest();

    Assert.areEqual(
      25,
      response.results.size(),
      'The installed Apex request must execute every Check before publication.'
    );
    Assert.areEqual(
      25,
      RHCSubscriberEventReceipt.checkResultCount,
      'ALL publication must deliver one installed Check Result event for every release-matrix Check.'
    );
    Assert.areEqual(
      1,
      RHCSubscriberEventReceipt.setRunCount,
      'ALL publication must deliver one installed Check Set Run event.'
    );
    assertEventIdentitiesCoverEveryEvaluationType(
      RHCSubscriberEventReceipt.checkQualifiedNames,
      RHCSubscriberEventReceipt.checkSources,
      'APEX_API'
    );
  }

  @IsTest
  static void restrictedSubscriberIsDeniedAtEveryServerEntryPoint() {
    User restrictedUser = RHCSubscriberTestDataFactory.createStandardUserWithoutRunAccess();
    Id inaccessibleRecordId = Id.valueOf('001000000000001AAA');
    String checkSetName = RHCSubscriberTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );

    System.runAs(restrictedUser) {
      try {
        rhc.RecordHealthCheck.evaluate(
          rhc.RecordHealthCheckRequest.forCheckSet(
            checkSetName,
            inaccessibleRecordId
          )
        );
        Assert.fail('The installed Apex API must deny an unentitled user.');
      } catch (Exception error) {
        Assert.isTrue(
          error.getMessage().contains('NOT_AUTHORIZED'),
          'The installed Apex API must return the stable authorization category.'
        );
      }

      rhc.RecordHealthCheckRunSetFlowAction.Request flowInput = new rhc.RecordHealthCheckRunSetFlowAction.Request();
      flowInput.checkSetQualifiedApiName = checkSetName;
      flowInput.recordId = inaccessibleRecordId;
      flowInput.eventPublication = 'NONE';
      rhc.RecordHealthCheckRunSetFlowAction.Response flowOutput = rhc.RecordHealthCheckRunSetFlowAction.runSet(
        new List<rhc.RecordHealthCheckRunSetFlowAction.Request>{ flowInput }
      )[0];
      Assert.isFalse(
        flowOutput.isSuccess,
        'The installed Flow action must deny an unentitled user.'
      );
      Assert.areEqual(
        'AUTHORIZATION',
        flowOutput.errorType,
        'The installed Flow action must return the stable authorization category.'
      );

      rhc.RecordHealthCheckRunSetAgentAction.Request agentInput = new rhc.RecordHealthCheckRunSetAgentAction.Request();
      agentInput.recordId = inaccessibleRecordId;
      agentInput.qualifiedApiName = checkSetName;
      rhc.RecordHealthCheckRunSetAgentAction.Response agentOutput = rhc.RecordHealthCheckRunSetAgentAction.runSet(
        new List<rhc.RecordHealthCheckRunSetAgentAction.Request>{ agentInput }
      )[0];
      Assert.isFalse(
        agentOutput.success,
        'The installed Agentforce action must deny an unentitled user.'
      );
      Assert.areEqual(
        'AUTHORIZATION',
        agentOutput.errorType,
        'The installed Agentforce action must return the stable authorization category.'
      );

      RestRequest restRequest = new RestRequest();
      restRequest.requestUri = '/services/apexrest/rhc/record-health-check/contract-1/evaluations';
      restRequest.httpMethod = 'POST';
      restRequest.addHeader('Content-Type', 'application/json');
      restRequest.requestBody = Blob.valueOf('{}');
      RestContext.request = restRequest;
      RestContext.response = new RestResponse();
      rhc.RecordHealthCheckAgentRestResource.doPost();
      Assert.areEqual(
        403,
        RestContext.response.statusCode,
        'The installed REST/MCP boundary must deny an unentitled user.'
      );
      Assert.isTrue(
        RestContext.response.responseBody.toString()
          .contains('"errorType":"AUTHORIZATION"'),
        'The installed REST/MCP boundary must return only the safe authorization envelope.'
      );

      assertAsyncSubmissionDenied(
        checkSetName,
        inaccessibleRecordId,
        'QUEUEABLE'
      );
      assertAsyncSubmissionDenied(checkSetName, inaccessibleRecordId, 'BATCH');
      assertAsyncSubmissionDenied(
        checkSetName,
        inaccessibleRecordId,
        'SCHEDULED'
      );
    }
  }

  private static void assertAsyncSubmissionDenied(
    String checkSetName,
    Id recordId,
    String adapter
  ) {
    try {
      if (adapter == 'QUEUEABLE') {
        rhc.RecordHealthCheckQueueable.enqueue(
          checkSetName,
          new List<Id>{ recordId },
          rhc.RecordHealthCheckEventPublication.NONE
        );
      } else if (adapter == 'BATCH') {
        rhc.RecordHealthCheckBatch.run(
          checkSetName,
          new List<Id>{ recordId },
          rhc.RecordHealthCheckEventPublication.NONE
        );
      } else {
        new rhc.RecordHealthCheckScheduled(
          checkSetName,
          new List<Id>{ recordId },
          rhc.RecordHealthCheckEventPublication.NONE
        );
      }
      Assert.fail(
        'The installed ' + adapter + ' adapter must deny an unentitled user.'
      );
    } catch (Exception error) {
      Assert.isTrue(
        error.getMessage().contains('NOT_AUTHORIZED'),
        'The installed ' +
          adapter +
          ' adapter must return the stable authorization category.'
      );
    }
  }

  @IsTest
  static void installedQueueableExecutesReleaseMatrixSet() {
    Account accountRecord = RHCSubscriberTestDataFactory.createAccount(
      'Subscriber Queueable Matrix'
    );
    RHCSubscriberEventReceipt.reset();

    Test.startTest();
    Id jobId = rhc.RecordHealthCheckQueueable.enqueue(
      RHCSubscriberTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Check_Builder_Guide'
      ),
      new List<Id>{ accountRecord.Id },
      rhc.RecordHealthCheckEventPublication.ALL
    );
    Test.stopTest();
    Test.getEventBus().deliver();

    AsyncApexJob job = [
      SELECT Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE Id = :jobId
    ];
    Assert.areEqual(
      'Completed',
      job.Status,
      'The installed Queueable must complete.'
    );
    Assert.areEqual(
      0,
      job.NumberOfErrors,
      'The installed Queueable must have no errors.'
    );
    assertAllTypeAsyncEvents('Queueable');
  }

  @IsTest
  static void installedBatchExecutesReleaseMatrixSet() {
    Account accountRecord = RHCSubscriberTestDataFactory.createAccount(
      'Subscriber Batch Matrix'
    );
    RHCSubscriberEventReceipt.reset();

    Test.startTest();
    Id jobId = rhc.RecordHealthCheckBatch.run(
      RHCSubscriberTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Check_Builder_Guide'
      ),
      new List<Id>{ accountRecord.Id },
      rhc.RecordHealthCheckEventPublication.ALL
    );
    Test.stopTest();
    Test.getEventBus().deliver();

    AsyncApexJob job = [
      SELECT Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE Id = :jobId
    ];
    Assert.areEqual(
      'Completed',
      job.Status,
      'The installed Batch must complete.'
    );
    Assert.areEqual(
      0,
      job.NumberOfErrors,
      'The installed Batch must have no errors.'
    );
    assertAllTypeAsyncEvents('Batch');
  }

  @IsTest
  static void installedScheduledAdapterExecutesReleaseMatrixSet() {
    Account accountRecord = RHCSubscriberTestDataFactory.createAccount(
      'Subscriber Scheduled Matrix'
    );
    RHCSubscriberEventReceipt.reset();

    Test.startTest();
    new rhc.RecordHealthCheckScheduled(
        RHCSubscriberTestDataFactory.qualifiedCheckSetName(
          'Example_Account_Check_Builder_Guide'
        ),
        new List<Id>{ accountRecord.Id },
        rhc.RecordHealthCheckEventPublication.ALL
      )
      .execute(null);
    Test.stopTest();
    Test.getEventBus().deliver();

    List<AsyncApexJob> batchJobs = [
      SELECT Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE JobType = 'BatchApex'
    ];
    Assert.areEqual(
      1,
      batchJobs.size(),
      'Scheduled execution must submit one Batch.'
    );
    Assert.areEqual(
      'Completed',
      batchJobs[0].Status,
      'The scheduled Batch must complete.'
    );
    Assert.areEqual(
      0,
      batchJobs[0].NumberOfErrors,
      'The scheduled Batch must have no errors.'
    );
    assertAllTypeAsyncEvents('Scheduled');
  }

  private static void assertAllTypeAsyncEvents(String adapter) {
    Assert.areEqual(
      25,
      RHCSubscriberEventReceipt.checkResultCount,
      'The installed ' +
        adapter +
        ' adapter must publish one terminal result for every Check in the four-evaluator release set.'
    );
    Assert.areEqual(
      2,
      RHCSubscriberEventReceipt.setRunCount,
      'The installed ' +
        adapter +
        ' adapter must publish one record result envelope and one asynchronous terminal envelope.'
    );
    assertEventIdentitiesCoverEveryEvaluationType(
      RHCSubscriberEventReceipt.checkQualifiedNames,
      RHCSubscriberEventReceipt.checkSources,
      adapter.toUpperCase()
    );
  }

  private static void assertEventIdentitiesCoverEveryEvaluationType(
    List<String> checkQualifiedNames,
    List<String> sources,
    String expectedSource
  ) {
    Set<String> uniqueCheckNames = new Set<String>(checkQualifiedNames);
    Assert.areEqual(
      checkQualifiedNames.size(),
      uniqueCheckNames.size(),
      'Each asynchronous result event must identify one distinct Check for the record.'
    );
    Map<String, rhc__Record_Health_Check__mdt> checksByQualifiedName = new Map<String, rhc__Record_Health_Check__mdt>();
    for (rhc__Record_Health_Check__mdt configuredCheck : [
      SELECT QualifiedApiName, rhc__EvaluationType__c
      FROM rhc__Record_Health_Check__mdt
      WHERE QualifiedApiName IN :uniqueCheckNames
    ]) {
      checksByQualifiedName.put(
        configuredCheck.QualifiedApiName,
        configuredCheck
      );
    }
    Set<String> evaluationTypes = new Set<String>();
    for (String checkQualifiedName : uniqueCheckNames) {
      rhc__Record_Health_Check__mdt configuredCheck = checksByQualifiedName.get(
        checkQualifiedName
      );
      Assert.isNotNull(
        configuredCheck,
        'Every asynchronous event Check identity must resolve to installed Custom Metadata.'
      );
      evaluationTypes.add(configuredCheck.rhc__EvaluationType__c);
    }
    Assert.areEqual(
      new Set<String>{ 'APEX', 'COMPARE_TWO_QUERIES', 'FORMULA', 'QUERY' },
      evaluationTypes,
      'The asynchronous adapter must publish results produced by every evaluator type.'
    );
    Assert.areEqual(
      new Set<String>{ expectedSource },
      new Set<String>(sources),
      'Every asynchronous result must retain the adapter execution origin.'
    );
  }

  @IsTest
  static void unmanagedSubscriberPluginResolvesAcrossNamespaceBoundary() {
    String checkSetName = RHCSubscriberTestDataFactory.qualifiedCheckSetName(
      'Subscriber_Smoke_Extension'
    );
    Account accountRecord = RHCSubscriberTestDataFactory.createAccount(
      'Subscriber Plugin Smoke Account'
    );

    rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
      rhc.RecordHealthCheckRequest.forCheckSet(checkSetName, accountRecord.Id)
    );

    System.assertEquals(1, response.results.size());
    System.assertEquals(
      'PASS',
      response.results[0].evaluation.status,
      'Unexpected subscriber plugin outcome: ' +
      response.results[0].evaluation.reasonCode
    );
    System.assertEquals(
      'SUBSCRIBER_PLUGIN_PASS',
      response.results[0].evaluation.reasonCode
    );
  }

  @IsTest
  static void subscriberOwnedConfigurationCoexistsWithPackagedSets() {
    List<rhc__Record_Health_Check_Set__mdt> checkSets = [
      SELECT DeveloperName, QualifiedApiName
      FROM rhc__Record_Health_Check_Set__mdt
      WHERE
        DeveloperName IN (
          'Example_Account_Check_Builder_Guide',
          'Example_Account_Relationship_Risk',
          'Subscriber_Smoke_Extension'
        )
    ];
    Map<String, rhc__Record_Health_Check_Set__mdt> checkSetsByName = new Map<String, rhc__Record_Health_Check_Set__mdt>();
    for (rhc__Record_Health_Check_Set__mdt checkSet : checkSets) {
      checkSetsByName.put(checkSet.DeveloperName, checkSet);
    }

    System.assert(
      checkSetsByName.containsKey('Example_Account_Check_Builder_Guide'),
      'The packaged Account Check Builder Guide must remain available after subscriber metadata deploy.'
    );
    System.assert(
      checkSetsByName.containsKey('Example_Account_Relationship_Risk'),
      'The original Account Relationship & Risk Check Set must remain available after subscriber metadata deploy.'
    );
    System.assert(
      checkSetsByName.containsKey('Subscriber_Smoke_Extension'),
      'Subscriber-owned Check Sets must deploy alongside packaged configuration.'
    );
    System.assert(
      String.isNotBlank(
        checkSetsByName.get('Subscriber_Smoke_Extension').QualifiedApiName
      ),
      'Subscriber-owned Check Sets must resolve qualified API names.'
    );
  }

  @IsTest
  static void packagedMetadataUsesQualifiedApiNames() {
    List<rhc__Record_Health_Check_Set__mdt> demoSets = [
      SELECT DeveloperName, QualifiedApiName
      FROM rhc__Record_Health_Check_Set__mdt
      WHERE DeveloperName LIKE 'Example_%'
      LIMIT 1
    ];
    System.assert(
      !demoSets.isEmpty(),
      'Packaged Demo Check Sets must be queryable after install.'
    );
    System.assert(
      String.isNotBlank(demoSets[0].QualifiedApiName),
      'QualifiedApiName must be populated for packaged Demo Check Sets.'
    );
  }
}
