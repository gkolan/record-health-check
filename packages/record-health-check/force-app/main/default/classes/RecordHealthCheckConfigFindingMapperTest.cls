/** Focused tests for runtime check-finding mapping. */
@IsTest
private class RecordHealthCheckConfigFindingMapperTest {
  @IsTest
  static void mapsMissingFormulaToUnableResult() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Missing_Formula',
        'CheckTitle__c' => 'Missing formula',
        'EvaluationType__c' => 'FORMULA'
      }
    );
    List<RecordHealthCheckValidator.Finding> findings = new List<RecordHealthCheckValidator.Finding>{
      new RecordHealthCheckValidator.Finding(
        RecordHealthCheckValidator.FindingCode.FORMULA_MISSING,
        null
      )
    };

    Test.startTest();
    RecordHealthCheckInternalResult result = RecordHealthCheckConfigFindingMapper.firstResult(
      findings,
      check
    );
    Test.stopTest();

    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      result.status,
      'Invalid checks remain unable.'
    );
    Assert.areEqual(
      'INVALID_FORMULA',
      result.reasonCode,
      'Reason code must remain stable.'
    );
  }

  @IsTest
  static void mapsEveryFindingCodeToUnableResult() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Every_Finding',
        'CheckTitle__c' => 'Every finding',
        'EvaluationType__c' => 'FORMULA'
      }
    );

    Test.startTest();
    for (
      RecordHealthCheckValidator.FindingCode code : RecordHealthCheckValidator.FindingCode.values()
    ) {
      RecordHealthCheckInternalResult result = RecordHealthCheckConfigFindingMapper.firstResult(
        new List<RecordHealthCheckValidator.Finding>{
          new RecordHealthCheckValidator.Finding(code, 'invalid')
        },
        check
      );
      Assert.areEqual(
        'UNABLE_TO_EVALUATE',
        result.status,
        'Every invalid Check finding must remain unable: ' +
        String.valueOf(code)
      );
      Assert.isFalse(
        String.isBlank(result.reasonCode),
        'Every finding must map to a stable reason code: ' +
        String.valueOf(code)
      );
      Assert.areEqual(
        'Every_Finding',
        result.checkDeveloperName,
        'Every result must retain the selected Check identity.'
      );
    }
    Test.stopTest();
  }
}
