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

  @IsTest
  static void mapsEveryFindingCodeToOneMetadataIssue() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{ 'DeveloperName' => 'Every_Finding' }
    );
    List<RecordHealthCheckValidator.Finding> findings = new List<RecordHealthCheckValidator.Finding>();
    for (
      RecordHealthCheckValidator.FindingCode code : RecordHealthCheckValidator.FindingCode.values()
    ) {
      findings.add(new RecordHealthCheckValidator.Finding(code, 'invalid'));
    }

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RecordHealthCheckMetadataIssueMapper.toIssues(
      findings,
      check
    );
    Test.stopTest();

    Assert.areEqual(
      findings.size(),
      issues.size(),
      'Every shared finding code must map to exactly one metadata issue.'
    );
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      Assert.areEqual(
        'ERROR',
        issue.severity,
        'Every invalid Check finding must remain a metadata error.'
      );
      Assert.areEqual(
        'Every_Finding',
        issue.componentName,
        'Every issue must retain the selected Check identity.'
      );
      Assert.isFalse(
        String.isBlank(issue.reasonCode),
        'Every mapped issue must expose a stable reason code.'
      );
    }
  }
}
