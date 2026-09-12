@IsTest
private class RecordHealthCheckPreviewFingerprintTest {
  @IsTest
  static void fieldInsertionAndPrerequisiteOrderAreCanonical() {
    Record_Health_Check__mdt left = check(
      new Map<String, Object>{
        'DeveloperName' => 'Draft',
        'FailureMessage__c' => 'Message',
        'EvaluationOrder__c' => 10
      }
    );
    Record_Health_Check__mdt right = check(
      new Map<String, Object>{
        'EvaluationOrder__c' => 10,
        'FailureMessage__c' => 'Message',
        'DeveloperName' => 'Draft'
      }
    );
    List<Record_Health_Check__mdt> firstOrder = new List<Record_Health_Check__mdt>{
      prerequisite('Second'),
      prerequisite('First')
    };
    List<Record_Health_Check__mdt> secondOrder = new List<Record_Health_Check__mdt>{
      prerequisite('First'),
      prerequisite('Second')
    };

    Test.startTest();
    String first = RecordHealthCheckPreviewFingerprint.compute(
      left,
      checkSet(),
      firstOrder,
      'Plugin@1'
    );
    String second = RecordHealthCheckPreviewFingerprint.compute(
      right,
      checkSet(),
      secondOrder,
      'Plugin@1'
    );
    Test.stopTest();

    Assert.areEqual(
      first,
      second,
      'Map insertion and prerequisite query order must not change the fingerprint.'
    );
    Assert.areEqual(
      64,
      first.length(),
      'SHA-256 must be lowercase 64-character hexadecimal.'
    );
    Assert.areEqual(
      first.toLowerCase(),
      first,
      'Fingerprint hexadecimal must be lowercase.'
    );
  }

  @IsTest
  static void whitespaceNullAndPluginRevisionChangeFingerprint() {
    Record_Health_Check__mdt baseline = check(
      new Map<String, Object>{
        'DeveloperName' => 'Draft',
        'PassConditionFormula__c' => 'Website != null'
      }
    );
    Record_Health_Check__mdt whitespace = check(
      new Map<String, Object>{
        'DeveloperName' => 'Draft',
        'PassConditionFormula__c' => 'Website  != null'
      }
    );
    Record_Health_Check__mdt explicitNull = check(
      new Map<String, Object>{
        'DeveloperName' => 'Draft',
        'PassConditionFormula__c' => null
      }
    );

    Test.startTest();
    String original = RecordHealthCheckPreviewFingerprint.compute(
      baseline,
      checkSet(),
      null,
      'Plugin@1'
    );
    String changedWhitespace = RecordHealthCheckPreviewFingerprint.compute(
      whitespace,
      checkSet(),
      null,
      'Plugin@1'
    );
    String changedNull = RecordHealthCheckPreviewFingerprint.compute(
      explicitNull,
      checkSet(),
      null,
      'Plugin@1'
    );
    String changedPlugin = RecordHealthCheckPreviewFingerprint.compute(
      baseline,
      checkSet(),
      null,
      'Plugin@2'
    );
    Test.stopTest();

    Assert.areNotEqual(
      original,
      changedWhitespace,
      'Formula whitespace is authored content and must be preserved.'
    );
    Assert.areNotEqual(
      original,
      changedNull,
      'Explicit null must not equal an authored formula.'
    );
    Assert.areNotEqual(
      original,
      changedPlugin,
      'A reliable plugin revision must participate in freshness.'
    );
  }

  @IsTest
  static void optionalQualifiedIdentityDoesNotChangeFingerprint() {
    Record_Health_Check__mdt developerIdentity = check(
      new Map<String, Object>{ 'DeveloperName' => 'Draft' }
    );
    Record_Health_Check__mdt qualifiedIdentity = check(
      new Map<String, Object>{
        'DeveloperName' => 'Draft',
        'QualifiedApiName' => 'Draft'
      }
    );

    Assert.areEqual(
      RecordHealthCheckPreviewFingerprint.compute(
        developerIdentity,
        checkSet(),
        null,
        null
      ),
      RecordHealthCheckPreviewFingerprint.compute(
        qualifiedIdentity,
        checkSet(),
        null,
        null
      ),
      'The same detached Check must retain its receipt fingerprint when QualifiedApiName is omitted.'
    );
  }

  private static Record_Health_Check__mdt check(Map<String, Object> fields) {
    return RecordHealthCheckTestDataFactory.check(fields);
  }

  private static Record_Health_Check__mdt prerequisite(String identity) {
    return check(new Map<String, Object>{ 'QualifiedApiName' => identity });
  }

  private static Record_Health_Check_Set__mdt checkSet() {
    return RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'QualifiedApiName' => 'RHC_SP_Preview',
        'ObjectApiName__c' => 'Account',
        'IsActive__c' => true
      }
    );
  }
}
