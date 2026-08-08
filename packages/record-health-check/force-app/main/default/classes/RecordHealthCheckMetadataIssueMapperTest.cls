/** Focused tests for shared-finding metadata issue mapping. */
@IsTest
private class RecordHealthCheckMetadataIssueMapperTest {
  @IsTest
  static void mapsFormulaFindingToOriginalContract() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{ 'DeveloperName' => 'Missing_Formula' }
    );
    List<RecordHealthCheckValidator.Finding> findings = new List<RecordHealthCheckValidator.Finding>{
      new RecordHealthCheckValidator.Finding(
        RecordHealthCheckValidator.FindingCode.FORMULA_MISSING,
        null
      )
    };

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RecordHealthCheckMetadataIssueMapper.toIssues(
      findings,
      check
    );
    Test.stopTest();

    Assert.areEqual(1, issues.size(), 'One finding should produce one issue.');
    Assert.areEqual(
      'INVALID_FORMULA',
      issues[0].reasonCode,
      'The established reason code must remain stable.'
    );
  }
}
