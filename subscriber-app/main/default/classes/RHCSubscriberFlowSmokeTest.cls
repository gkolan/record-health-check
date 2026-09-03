/**
 * Starts the subscriber-owned release-matrix Flow against an installed package.
 * The deterministic Flow wrapper is hand-authored from the pinned invocable
 * Apex contract and validated by deployment plus this real interview test.
 */
@IsTest
private class RHCSubscriberFlowSmokeTest {
  private static final String FLOW_API_NAME = 'RHC_Subscriber_Release_Matrix';

  @TestSetup
  static void assignRunnerAccess() {
    RHCSubscriberTestDataFactory.assignPackagedPermissionSet(
      UserInfo.getUserId(),
      'Record_Health_Check_User'
    );
  }

  @IsTest
  static void subscriberFlowExecutesCheckAndAllFourEvaluatorTypes() {
    Account accountRecord = RHCSubscriberTestDataFactory.createAccount(
      'Subscriber Flow Release Matrix'
    );
    rhc__Record_Health_Check__mdt configuredCheck = [
      SELECT QualifiedApiName
      FROM rhc__Record_Health_Check__mdt
      WHERE rhc__Record_Health_Check_Set__r.DeveloperName = 'Subscriber_On_Load'
      ORDER BY rhc__EvaluationOrder__c, DeveloperName
      LIMIT 1
    ];

    Map<String, Object> inputs = new Map<String, Object>{
      'recordId' => accountRecord.Id,
      'checkQualifiedApiName' => configuredCheck.QualifiedApiName,
      'checkSetQualifiedApiName' => RHCSubscriberTestDataFactory.qualifiedCheckSetName(
        'Subscriber_On_Load'
      ),
      'eventPublication' => 'NONE'
    };
    Flow.Interview interview = Flow.Interview.createInterview(
      FLOW_API_NAME,
      inputs
    );

    Test.startTest();
    interview.start();
    Test.stopTest();

    Assert.areEqual(
      true,
      interview.getVariableValue('checkIsSuccess'),
      'A real subscriber Flow interview must execute one installed Check successfully.'
    );
    assertTerminalStatus(
      (String) interview.getVariableValue('checkStatus'),
      'Check'
    );
    Assert.areEqual(
      null,
      interview.getVariableValue('checkErrorType'),
      'A completed Check evaluation must not return a system error category.'
    );
    Assert.isNotNull(
      interview.getVariableValue('checkResultJson'),
      'The Flow Check action must expose its structured result payload.'
    );

    Assert.areEqual(
      true,
      interview.getVariableValue('setIsSuccess'),
      'A real subscriber Flow interview must execute the installed Check Set successfully.'
    );
    assertTerminalStatus(
      (String) interview.getVariableValue('setStatus'),
      'Check Set'
    );
    Assert.areEqual(
      null,
      interview.getVariableValue('setErrorType'),
      'A completed Check Set evaluation must not return a system error category.'
    );
    Assert.isNotNull(
      interview.getVariableValue('setResultJson'),
      'The Flow Check Set action must expose its structured result payload.'
    );
    Assert.areEqual(
      4,
      terminalCount(interview),
      'The subscriber Flow must account for the Formula, Query, Compare, and Apex checks.'
    );
  }

  private static Integer terminalCount(Flow.Interview interview) {
    return integerOutput(interview, 'setPassedCount') +
      integerOutput(interview, 'setFailedCount') +
      integerOutput(interview, 'setSkippedCount') +
      integerOutput(interview, 'setUnableCount') +
      integerOutput(interview, 'setSystemErrorCount');
  }

  private static Integer integerOutput(
    Flow.Interview interview,
    String variableName
  ) {
    Object value = interview.getVariableValue(variableName);
    Assert.isNotNull(
      value,
      'The Flow must expose output variable ' + variableName + '.'
    );
    return ((Decimal) value).intValue();
  }

  private static void assertTerminalStatus(String status, String operation) {
    Assert.isTrue(
      new Set<String>{
          'PASS',
          'FAIL',
          'SKIPPED',
          'UNABLE_TO_EVALUATE',
          'ERROR'
        }
        .contains(status),
      operation +
        ' must expose a recognized terminal status; received ' +
        status +
        '.'
    );
  }
}
