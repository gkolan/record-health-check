@IsTest
private class RHCPartnerCompatibilityPluginTest {
  @IsTest
  static void globalRhcContractCompilesAndEvaluates() {
    Account accountRecord = new Account(Name = 'Partner Namespace Fixture');
    insert accountRecord;
    RHCPartnerCompatibilityPlugin.constructorCount = 0;
    RHCPartnerCompatibilityPlugin.evaluateCount = 0;
    rhc.RecordHealthCheckScope scope = new rhc.RecordHealthCheckScope(
      'Account',
      new List<Id>{ accountRecord.Id },
      new Map<String, Object>(),
      'Partner_Namespace_Plugin',
      'Partner_Namespace_Compatibility',
      'partner-namespace-contract'
    );

    RHCPartnerCompatibilityPlugin plugin = new RHCPartnerCompatibilityPlugin();
    Map<Id, rhc.RecordHealthCheckOutcome> outcomes = plugin.evaluate(scope);

    System.assertEquals(1, RHCPartnerCompatibilityPlugin.constructorCount);
    System.assertEquals(1, RHCPartnerCompatibilityPlugin.evaluateCount);
    System.assertEquals('PASS', outcomes.get(accountRecord.Id).status);
    System.assertEquals(
      'PARTNER_NAMESPACE_PLUGIN_PASS',
      outcomes.get(accountRecord.Id).reasonCode
    );
  }
}
