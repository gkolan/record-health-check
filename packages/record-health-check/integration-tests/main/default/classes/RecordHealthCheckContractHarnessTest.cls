/** Proves the shipped bulk plugin passes the reusable contract test. */
@IsTest
global with sharing class RecordHealthCheckContractHarnessTest extends RecordHealthCheckContractTest {
  global override RecordHealthCheckPlugin newCheck() {
    return new AccountHasRecentActivityCheck();
  }

  global override RecordHealthCheckContractTestData testData() {
    return new HarnessData();
  }

  @IsTest
  static void shippedPluginPassesBulkContract() {
    new RecordHealthCheckContractHarnessTest().verifyContract();
  }

  @IsTest
  static void perRecordQueryPluginFailsAtSecondMeasuredScope() {
    List<Integer> queryDeltas = new List<Integer>();
    HarnessData data = new HarnessData();
    for (Integer size : new List<Integer>{ 1, 10 }) {
      RecordHealthCheckScope scope = data.createScope(size);
      Integer beforeQueries = Limits.getQueries();
      RecordHealthCheckPluginDispatch.run(new PerRecordQueryCheck(), scope);
      queryDeltas.add(Limits.getQueries() - beforeQueries);
    }
    Assert.areEqual(new List<Integer>{ 1, 10 }, queryDeltas);
    Assert.isFalse(
      RecordHealthCheckContractTest.hasStableQueryGrowth(queryDeltas),
      'The harness must reject a plugin whose query use follows record count.'
    );
  }

  @IsTest
  static void harnessHelpersRejectMissingMeasurementsAndFixtures() {
    Assert.isFalse(
      RecordHealthCheckContractTest.hasStableQueryGrowth(null),
      'A missing query-growth sample must not pass the contract.'
    );
    Assert.isFalse(
      RecordHealthCheckContractTest.hasStableQueryGrowth(new List<Integer>()),
      'An empty query-growth sample must not pass the contract.'
    );
    Assert.isFalse(
      RecordHealthCheckContractTest.hasPermissionEvidence(null, null),
      'A missing Check and permission fixture cannot provide access evidence.'
    );
  }

  @IsTest
  static void controlledFixtureDistinguishesSystemAndUserModeBehavior() {
    User leastPrivilege = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      'rhcmin'
    );
    Account restricted = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Permission Evidence',
        'AnnualRevenue' => 987654
      }
    );
    System.runAs(RecordHealthCheckTestDataFactory.user(
      new Map<String, Object>{ 'Id' => UserInfo.getUserId() }
    )) {
      RHCIntegrationTestDataFactory.createAccount(restricted);
    }
    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      'Account',
      new List<Id>{ restricted.Id },
      new Map<String, Object>(),
      'Permission_Check',
      'Permission_Set',
      'permission-evidence'
    );
    RecordHealthCheckContractTestData.PermissionFixture fixture = new RecordHealthCheckContractTestData.PermissionFixture();
    fixture.leastPrivilegeUser = leastPrivilege;
    fixture.scope = scope;
    fixture.assertedRecordId = restricted.Id;

    Assert.isFalse(
      RecordHealthCheckContractTest.hasPermissionEvidence(
        new SystemModePermissionCheck(),
        fixture
      ),
      'System-mode access must fail the controlled permission evidence.'
    );
    Assert.isTrue(
      RecordHealthCheckContractTest.hasPermissionEvidence(
        new UserModePermissionCheck(),
        fixture
      ),
      'User-mode access must return an unable result without values.'
    );
  }

  @IsTest
  static void permissionEvidenceRejectsAPluginThatThrows() {
    RecordHealthCheckContractTestData.PermissionFixture fixture = new RecordHealthCheckContractTestData.PermissionFixture();
    fixture.leastPrivilegeUser = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      'rhcthr'
    );
    fixture.scope = new HarnessData().createScope(1);
    fixture.assertedRecordId = fixture.scope.recordIds[0];

    Assert.isFalse(
      RecordHealthCheckContractTest.hasPermissionEvidence(
        new ThrowingPermissionCheck(),
        fixture
      ),
      'A plugin exception cannot count as least-privilege evidence.'
    );
  }

  global class HarnessData extends RecordHealthCheckContractTestData {
    global override RecordHealthCheckScope createScope(Integer size) {
      List<Account> accounts = new List<Account>();
      for (Integer index = 0; index < size; index++) {
        accounts.add(
          RecordHealthCheckTestDataFactory.account(
            new Map<String, Object>{ 'Name' => 'Harness ' + size + '-' + index }
          )
        );
      }
      RHCIntegrationTestDataFactory.createAccounts(accounts);
      List<Id> recordIds = new List<Id>();
      for (Account account : accounts) {
        recordIds.add(account.Id);
      }
      return new RecordHealthCheckScope(
        'Account',
        recordIds,
        new Map<String, Object>{ 'daysBack' => 90 },
        'Harness_Check',
        'Harness_Set',
        'harness-' + size
      );
    }
  }

  global class PerRecordQueryCheck implements RecordHealthCheckPlugin {
    global Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        // code-analyzer-suppress-next-line OperationWithLimitsInLoop: This deliberately non-bulk test plugin proves that the contract harness detects record-count-dependent query growth.
        Integer contacts = [
          SELECT COUNT()
          FROM Contact
          WHERE AccountId = :recordId
          WITH USER_MODE
        ];
        outcomes.put(
          recordId,
          contacts == 0
            ? RecordHealthCheckOutcome.pass('NO_CONTACTS')
            : RecordHealthCheckOutcome.fail('HAS_CONTACTS')
        );
      }
      return outcomes;
    }
  }

  global class ThrowingPermissionCheck implements RecordHealthCheckPlugin {
    global Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      throw new RecordHealthCheckEvaluatorException(
        'EXPECTED_TEST_FAILURE',
        'Contract harness exception path.'
      );
    }
  }

  global without sharing class SystemModePermissionCheck implements RecordHealthCheckPlugin {
    global Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      Map<Id, Account> accounts = new Map<Id, Account>(
        [
          SELECT AnnualRevenue
          FROM Account
          WHERE Id IN :scope.recordIds
        ]
      );
      return permissionOutcomes(scope, accounts, false);
    }
  }

  global with sharing class UserModePermissionCheck implements RecordHealthCheckPlugin {
    global Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      try {
        Map<String, Object> binds = new Map<String, Object>{
          'recordIds' => new Set<Id>(scope.recordIds)
        };
        Map<Id, Account> accounts = new Map<Id, Account>();
        for (
          SObject row : Database.queryWithBinds(
            'SELECT AnnualRevenue FROM Account WHERE Id IN :recordIds',
            binds,
            AccessLevel.USER_MODE
          )
        ) {
          Account account = (Account) row;
          accounts.put(account.Id, account);
        }
        return permissionOutcomes(scope, accounts, true);
      } catch (System.QueryException expected) {
        return permissionOutcomes(scope, new Map<Id, Account>(), true);
      }
    }
  }

  private static Map<Id, RecordHealthCheckOutcome> permissionOutcomes(
    RecordHealthCheckScope scope,
    Map<Id, Account> accounts,
    Boolean userMode
  ) {
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      if (!accounts.containsKey(recordId)) {
        outcomes.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate('RECORD_NOT_ACCESSIBLE')
        );
      } else {
        outcomes.put(
          recordId,
          RecordHealthCheckOutcome.fail(
              userMode ? 'USER_MODE_LEAK' : 'SYSTEM_MODE_LEAK'
            )
            .withFound(
              RecordHealthCheckValue.ofNumber(
                accounts.get(recordId).AnnualRevenue
              )
            )
        );
      }
    }
    return outcomes;
  }
}
