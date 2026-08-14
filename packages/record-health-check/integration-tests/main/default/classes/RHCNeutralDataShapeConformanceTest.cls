/**
 * Product-neutral conformance evidence for Salesforce data shapes used by core evaluators.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCNeutralDataShapeConformanceTest {
  @TestSetup
  static void createShapes() {
    RHC_Conformance_Record__c parent = new RHC_Conformance_Record__c(
      Name = 'Parent',
      Quantity__c = 12.3456,
      Amount__c = 25.50,
      Snapshot_Value__c = 8.1250,
      Current_Value__c = 8.1250,
      Segment__c = 'A',
      Snapshot_As_Of__c = System.now().addHours(-1),
      Source_Changed_At__c = System.now().addHours(-2)
    );
    insert parent;
    insert new List<RHC_Conformance_Record__c>{
      new RHC_Conformance_Record__c(
        Name = 'Negative Child',
        Parent__c = parent.Id,
        Quantity__c = -3.1415,
        Amount__c = -9.25,
        Snapshot_Value__c = 4.5000,
        Current_Value__c = 7.7500,
        Snapshot_As_Of__c = System.now().addDays(-2),
        Source_Changed_At__c = System.now().addDays(-1)
      ),
      new RHC_Conformance_Record__c(
        Name = 'Null Shape',
        Parent__c = parent.Id,
        Quantity__c = 0,
        Amount__c = 0,
        Snapshot_Value__c = null,
        Current_Value__c = null,
        Segment__c = null
      )
    };
  }

  @IsTest
  static void signedScaleSurvivesFormulaQueryComparisonAndDisplay() {
    RHC_Conformance_Record__c row = recordNamed('Negative Child');

    Record_Health_Check__mdt formula = baseCheck(
      'Neutral_Negative_Formula',
      'FORMULA'
    );
    formula.PassConditionFormula__c = 'Quantity__c = -3.1415';
    RecordHealthCheckInternalResult formulaResult = new RecordHealthCheckFormulaEvaluator()
      .evaluate(formula, row.Id, row);
    Assert.areEqual('PASS', formulaResult.status);

    Record_Health_Check__mdt query = queryCheck('Neutral_Negative_Query');
    query.SourceQuery__c = 'SELECT Quantity__c FROM RHC_Conformance_Record__c WHERE Id = {!record.Id}';
    query.SourceQueryField__c = 'Quantity__c';
    query.ExpectedFixedValue__c = '-3.1415';
    RecordHealthCheckInternalResult queryResult = new RecordHealthCheckSoqlEvaluator()
      .evaluate(query, row.Id, row);
    Assert.areEqual('PASS', queryResult.status);
    Assert.areEqual('-3.1415', String.valueOf(queryResult.actualValue));
  }

  @IsTest
  static void hierarchyAndSnapshotsRemainExplicitDataNotCoreSemantics() {
    RHC_Conformance_Record__c child = recordNamed('Negative Child');

    Record_Health_Check__mdt hierarchy = queryCheck('Neutral_Parent_Path');
    hierarchy.SourceQuery__c = 'SELECT Parent__r.Quantity__c FROM RHC_Conformance_Record__c WHERE Id = {!record.Id}';
    hierarchy.SourceQueryField__c = 'Parent__r.Quantity__c';
    hierarchy.ExpectedFixedValue__c = '12.3456';
    Assert.areEqual(
      'PASS',
      new RecordHealthCheckSoqlEvaluator()
        .evaluate(hierarchy, child.Id, child)
        .status
    );

    Record_Health_Check__mdt snapshot = dualCheck('Neutral_Snapshot_Compare');
    snapshot.SourceQuery__c = 'SELECT Snapshot_Value__c FROM RHC_Conformance_Record__c WHERE Id = {!record.Id}';
    snapshot.SourceQueryField__c = 'Snapshot_Value__c';
    snapshot.ComparisonQuery__c = 'SELECT Current_Value__c FROM RHC_Conformance_Record__c WHERE Id = {!record.Id}';
    snapshot.ComparisonQueryField__c = 'Current_Value__c';
    Assert.areEqual(
      'FAIL',
      new RecordHealthCheckCompareQueriesEvaluator()
        .evaluate(snapshot, child.Id, child)
        .status,
      'Core compares configured values but must not claim the copied value is fresh.'
    );
  }

  @IsTest
  static void nullPolicyAndMixedBulkResultsStayIsolatedByRoot() {
    List<RHC_Conformance_Record__c> rows = [
      SELECT Id, Name, Quantity__c, Segment__c
      FROM RHC_Conformance_Record__c
      ORDER BY Name
    ];
    List<Id> ids = new List<Id>();
    Map<Id, SObject> recordsById = new Map<Id, SObject>();
    for (RHC_Conformance_Record__c row : rows) {
      ids.add(row.Id);
      recordsById.put(row.Id, row);
    }

    Record_Health_Check__mdt query = queryCheck('Neutral_Bulk_Isolation');
    query.SourceQuery__c = 'SELECT Quantity__c FROM RHC_Conformance_Record__c WHERE Id = {!record.Id}';
    query.SourceQueryField__c = 'Quantity__c';
    query.ComparisonOperator__c = 'GREATER_THAN_OR_EQUAL';
    query.ExpectedFixedValue__c = '0';
    Map<Id, RecordHealthCheckInternalResult> outcomes = new RecordHealthCheckSoqlEvaluator()
      .evaluateScope(query, ids, recordsById);

    Assert.areEqual(ids.size(), outcomes.size());
    for (RHC_Conformance_Record__c row : rows) {
      Assert.areEqual(
        row.Quantity__c < 0 ? 'FAIL' : 'PASS',
        outcomes.get(row.Id).status,
        'Each root must retain its own signed value and result.'
      );
    }

    RHC_Conformance_Record__c nullRow = recordNamed('Null Shape');
    Record_Health_Check__mdt nullQuery = queryCheck('Neutral_Legitimate_Null');
    nullQuery.SourceQuery__c = 'SELECT Segment__c FROM RHC_Conformance_Record__c WHERE Id = {!record.Id}';
    nullQuery.SourceQueryField__c = 'Segment__c';
    nullQuery.EmptyValueHandling__c = 'SKIP_RECORD';
    Assert.areEqual(
      'SKIPPED',
      new RecordHealthCheckSoqlEvaluator()
        .evaluate(nullQuery, nullRow.Id, nullRow)
        .status,
      'A legitimate null follows configured policy; it is not mechanically unhealthy.'
    );
  }

  private static RHC_Conformance_Record__c recordNamed(String name) {
    return [
      SELECT
        Id,
        Name,
        Parent__c,
        Quantity__c,
        Amount__c,
        Snapshot_Value__c,
        Current_Value__c,
        Segment__c,
        Snapshot_As_Of__c,
        Source_Changed_At__c
      FROM RHC_Conformance_Record__c
      WHERE Name = :name
      LIMIT 1
    ];
  }

  private static Record_Health_Check__mdt baseCheck(
    String developerName,
    String evaluationType
  ) {
    return new Record_Health_Check__mdt(
      DeveloperName = developerName,
      MasterLabel = developerName,
      CheckTitle__c = developerName,
      EvaluationType__c = evaluationType,
      FailureSeverity__c = 'WARNING',
      FailureMessage__c = 'Neutral conformance mismatch.',
      UnableToEvaluateMessage__c = 'Neutral conformance could not be evaluated.',
      FormulaResultType__c = 'AUTO',
      EvaluationOrder__c = 10,
      ApplicabilityMode__c = 'ALL_RECORDS',
      NoRowsResult__c = 'FAIL',
      EmptyValueHandling__c = 'SKIP_RECORD'
    );
  }

  private static Record_Health_Check__mdt queryCheck(String developerName) {
    Record_Health_Check__mdt check = baseCheck(developerName, 'QUERY');
    check.QueryResultHandling__c = 'ONE_RESULT';
    check.ComparisonOperator__c = 'EQUALS';
    check.ExpectedValueSource__c = 'FIXED_VALUE';
    check.ExpectedFixedValue__c = 'A';
    check.MaxQueryRows__c = 100;
    return check;
  }

  private static Record_Health_Check__mdt dualCheck(String developerName) {
    Record_Health_Check__mdt check = baseCheck(
      developerName,
      'COMPARE_TWO_QUERIES'
    );
    check.QueryResultHandling__c = 'ONE_RESULT';
    check.ComparisonOperator__c = 'EQUALS';
    check.MaxQueryRows__c = 100;
    return check;
  }
}
