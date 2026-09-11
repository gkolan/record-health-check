/** Integration-only acceptance overlay for subscriber diagnostic provenance. */
@IsTest
private with sharing class RHCSubscriberDiagnosticIntegrationTest {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @IsTest
  static void unresolvedFieldFixtureStopsBeforePluginEvaluation() {
    Account fixture = RHCIntegrationTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'SP-D-Bad-Field',
          'Industry' => 'Manufacturing'
        }
      )
    );

    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
          RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
            'RHC_SP_Diagnostics_Invalid'
          ),
          new List<Id>{ fixture.Id }
        )
        .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
    );
    Test.stopTest();

    Assert.areEqual(2, response.results.size(), 'SP-03 and SP-04 fixtures.');
    for (RecordHealthCheckResultItem item : response.results) {
      Assert.areEqual(
        RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
        item.evaluation.status,
        'Every malformed field fixture must stop evaluation safely.'
      );
      Assert.areEqual(
        RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED,
        item.evaluation.reasonCode,
        'Each fixture must retain its field-planning reason.'
      );
    }
    Assert.areEqual(
      2,
      response.summary.unable,
      'The isolated fixtures contribute two UNABLE results.'
    );
    Assert.areEqual(
      0,
      response.summary.systemError,
      'A planning failure is not an unhandled plugin exception.'
    );
  }

  @IsTest
  static void authorizedV2RequestProjectsObservedPlanningTrace() {
    User viewer = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      'sp14trce'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      viewer,
      'Record_Health_Check_Diagnostics_Viewer'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      viewer,
      'RHC_SP_Formula_Access'
    );
    Account fixture = RHCIntegrationTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'SP-D-Contract-Trace',
          'Industry' => 'Manufacturing',
          'OwnerId' => viewer.Id
        }
      )
    );

    System.runAs(viewer) {
      Test.startTest();
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(
            RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
              'RHC_SP_Diagnostics_Invalid'
            ),
            new List<Id>{ fixture.Id }
          )
          .withDiagnosticContractVersion('2.0')
      );
      RecordHealthCheckDiagnosticResponse diagnostics = response.diagnostics();
      Test.stopTest();

      Assert.isNotNull(
        diagnostics,
        'An explicitly assigned diagnostics viewer receives contract 2.0.'
      );
      Assert.areEqual(2, diagnostics.diagnostics.size());
      for (
        RecordHealthCheckDiagnosticEnvelope envelope : diagnostics.diagnostics
      ) {
        Assert.areEqual(false, envelope.pluginInvoked);
        Assert.areEqual('FRAMEWORK', envelope.reasonOrigin);
        Assert.areEqual('FIELD_PLAN_FAILED', envelope.terminalFailure);
        Assert.areEqual('CHECK_RESOLVED', envelope.trace[0].stage);
        Assert.areEqual('PLUGIN_RESOLVED', envelope.trace[1].stage);
        Assert.areEqual('PLUGIN_CONSTRUCTED', envelope.trace[2].stage);
        Assert.areEqual('CONFIG_VALIDATED', envelope.trace[3].stage);
        Assert.areEqual('FIELD_PLAN_FAILED', envelope.trace[4].stage);
        Assert.areEqual(
          5,
          envelope.trace.size(),
          'No operation after the failed field plan may appear in the trace.'
        );
      }
    }
  }

  @IsTest
  static void definitionCompletesBeforeLoadForInapplicableRecord() {
    RHCSPPPlugin.definitionCount = 0;
    RHCSPPPlugin.evaluateCount = 0;
    User viewer = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      'sp14ordr'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      viewer,
      'Record_Health_Check_Diagnostics_Viewer'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      viewer,
      'RHC_SP_Formula_Access'
    );
    Account fixture = RHCIntegrationTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'SP-D-Definition-Order',
          'Industry' => 'Banking',
          'Website' => 'https://example.test',
          'OwnerId' => viewer.Id
        }
      )
    );

    System.runAs(viewer) {
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(
            RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
              'RHC_SP_Diagnostics'
            ),
            new List<Id>{ fixture.Id }
          )
          .withDiagnosticContractVersion('2.0')
      );
      RecordHealthCheckDiagnosticEnvelope envelope = response
        .diagnostics()
        .diagnostics[0];
      List<String> stages = new List<String>();
      for (RecordHealthCheckDiagnosticTraceEntry entry : envelope.trace) {
        stages.add(entry.stage);
      }

      Assert.areEqual(1, RHCSPPPlugin.definitionCount);
      Assert.areEqual(0, RHCSPPPlugin.evaluateCount);
      Assert.areEqual(
        RecordHealthCheckStatus.SKIPPED,
        response.results[0].evaluation.status
      );
      Assert.isTrue(
        stages.indexOf('PLUGIN_DEFINED') < stages.indexOf('RECORDS_LOADED')
      );
      Assert.isTrue(stages.contains('APPLICABILITY_FALSE'));
      Assert.isFalse(stages.contains('PLUGIN_EXECUTED'));
      Assert.areEqual(false, envelope.pluginInvoked);
    }
  }
}
