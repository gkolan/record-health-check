/** Integration-only acceptance overlay for subscriber diagnostic provenance. */
@IsTest
private with sharing class RHCSubscriberDiagnosticIntegrationTest {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @IsTest
  static void diagnosticFixturePreservesBusinessPassAndFail() {
    List<Account> fixtures = new List<Account>{
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'SP-D-Healthy',
          'Industry' => 'Manufacturing',
          'Website' => 'https://example.test'
        }
      ),
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'SP-D-Unhealthy',
          'Industry' => 'Manufacturing',
          'Website' => 'http://example.test'
        }
      )
    };
    RHCIntegrationTestDataFactory.createAccounts(fixtures);

    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
          RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
            'RHC_SP_Diagnostics'
          ),
          new List<Id>{ fixtures[0].Id, fixtures[1].Id }
        )
        .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
    );
    Test.stopTest();

    Map<Id, String> expectedStatusByRecordId = new Map<Id, String>{
      fixtures[0].Id => RecordHealthCheckStatus.PASS,
      fixtures[1].Id => RecordHealthCheckStatus.FAIL
    };
    Assert.areEqual(
      2,
      response.results.size(),
      'The diagnostics fixture must return one result per input Account.'
    );
    for (RecordHealthCheckResultItem item : response.results) {
      Assert.areEqual(
        expectedStatusByRecordId.remove(item.evaluation.recordId),
        item.evaluation.status,
        'Diagnostics must not replace the underlying business verdict.'
      );
    }
    Assert.areEqual(
      0,
      expectedStatusByRecordId.size(),
      'Both independently specified Account outcomes must be returned.'
    );
    Assert.areEqual(1, response.summary.passed, 'Expected one PASS result.');
    Assert.areEqual(1, response.summary.failed, 'Expected one FAIL result.');
    Assert.areEqual(0, response.summary.skipped, 'No record should skip.');
    Assert.areEqual(0, response.summary.unable, 'No record should be unable.');
    Assert.areEqual(
      0,
      response.summary.systemError,
      'No record should produce a system error.'
    );
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
      Assert.areEqual(
        2,
        diagnostics.diagnostics.size(),
        'Both malformed-field fixtures must receive diagnostic envelopes.'
      );
      for (
        RecordHealthCheckDiagnosticEnvelope envelope : diagnostics.diagnostics
      ) {
        Assert.areEqual(
          false,
          envelope.pluginInvoked,
          'Field planning must fail before plugin evaluation.'
        );
        Assert.areEqual(
          'FRAMEWORK',
          envelope.reasonOrigin,
          'Field-planning failure must have framework provenance.'
        );
        Assert.areEqual(
          'FIELD_PLAN_FAILED',
          envelope.terminalFailure,
          'The diagnostic must terminate at field-plan failure.'
        );
        Assert.areEqual(
          'CHECK_RESOLVED',
          envelope.trace[0].stage,
          'Check resolution must be the first observed stage.'
        );
        Assert.areEqual(
          'PLUGIN_RESOLVED',
          envelope.trace[1].stage,
          'Plugin resolution must follow Check resolution.'
        );
        Assert.areEqual(
          'PLUGIN_CONSTRUCTED',
          envelope.trace[2].stage,
          'Plugin construction must follow plugin resolution.'
        );
        Assert.areEqual(
          'CONFIG_VALIDATED',
          envelope.trace[3].stage,
          'Configuration validation must precede field planning.'
        );
        Assert.areEqual(
          'FIELD_PLAN_FAILED',
          envelope.trace[4].stage,
          'Field-plan failure must be the final observed stage.'
        );
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

      Assert.areEqual(
        1,
        RHCSPPPlugin.definitionCount,
        'The inapplicable Check must define its plugin exactly once.'
      );
      Assert.areEqual(
        0,
        RHCSPPPlugin.evaluateCount,
        'The inapplicable Check must not evaluate its plugin.'
      );
      Assert.areEqual(
        RecordHealthCheckStatus.SKIPPED,
        response.results[0].evaluation.status,
        'An inapplicable record must retain SKIPPED.'
      );
      Assert.isTrue(
        stages.indexOf('PLUGIN_DEFINED') < stages.indexOf('RECORDS_LOADED'),
        'Plugin definition must precede record loading.'
      );
      Assert.isTrue(
        stages.contains('APPLICABILITY_FALSE'),
        'The trace must record failed applicability.'
      );
      Assert.isFalse(
        stages.contains('PLUGIN_EXECUTED'),
        'The trace must not invent plugin execution.'
      );
      Assert.areEqual(
        false,
        envelope.pluginInvoked,
        'An inapplicable Check must not claim plugin invocation.'
      );
    }
  }
}
