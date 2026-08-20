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
  static void demoCheckSetEvaluatesThroughPublicApi() {
    System.assertEquals(
      true,
      RHCSubscriberTestDataFactory.isPackageInstalled(),
      'Package install is required before smoke evaluation.'
    );

    String checkSetName = RHCSubscriberTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Profile_Readiness'
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
    System.assertEquals('PASS', response.results[0].evaluation.status);
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
          'Example_Account_Profile_Readiness',
          'Subscriber_Smoke_Extension'
        )
    ];
    Map<String, rhc__Record_Health_Check_Set__mdt> checkSetsByName = new Map<String, rhc__Record_Health_Check_Set__mdt>();
    for (rhc__Record_Health_Check_Set__mdt checkSet : checkSets) {
      checkSetsByName.put(checkSet.DeveloperName, checkSet);
    }

    System.assert(
      checkSetsByName.containsKey('Example_Account_Profile_Readiness'),
      'Packaged Demo Check Sets must remain available after subscriber metadata deploy.'
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
