/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Focused tests for SOQL record-token binding.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RecordHealthCheckSoqlTokenBinderTest {
  @IsTest
  static void bindsTypedAndEscapedValues() {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'O\'Hare', 'NumberOfEmployees' => 25 }
    );

    Test.startTest();
    String bound = RecordHealthCheckSoqlTokenBinder.bindTokens(
      'SELECT Id FROM Account WHERE Name = {!record.Name} ' +
      'AND NumberOfEmployees = {!record.NumberOfEmployees}',
      record
    );
    Test.stopTest();

    Assert.isTrue(
      bound.contains('O\\\'Hare'),
      'String values should be escaped before insertion.'
    );
    Assert.isTrue(
      bound.contains('NumberOfEmployees = 25'),
      'Numeric values should remain unquoted.'
    );
  }

  @IsTest
  static void escapesBackslashesBeforeBuildingSoqlLiterals() {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'folder\\' }
    );
    RecordHealthCheckTestDataFactory.createAccount(record);

    Test.startTest();
    String bound = RecordHealthCheckSoqlTokenBinder.bindTokens(
      'SELECT Id FROM Account WHERE Name = {!record.Name}',
      record
    );
    List<SObject> matches = Database.query(
      RecordHealthCheckSoqlTemplate.prepareForExecution(bound, 10)
    );
    Test.stopTest();

    Assert.areEqual(
      'SELECT Id FROM Account WHERE Name = \'folder\\\\\'',
      bound,
      'A trailing backslash must be escaped before the closing SOQL quote.'
    );
    Assert.areEqual(
      1,
      matches.size(),
      'The escaped literal must remain executable and match the source record.'
    );
  }

  @IsTest
  static void rejectsDisallowedQueryKeywords() {
    Test.startTest();
    try {
      RecordHealthCheckSoqlTokenBinder.validateNoDisallowedKeywords(
        'SELECT Id FROM Account FOR UPDATE'
      );
      Assert.fail('FOR UPDATE should be rejected.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'The rejection should use the template error reason.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void bindsUnquotedMultiSelectAsIncludesOperand() {
    Schema.SObjectType quickTextType = Schema.getGlobalDescribe()
      .get('QuickText');
    Schema.DescribeFieldResult channelField = quickTextType
      .getDescribe()
      .fields.getMap()
      .get('Channel')
      .getDescribe();
    List<Schema.PicklistEntry> entries = channelField.getPicklistValues();
    Assert.isTrue(
      entries.size() >= 2,
      'QuickText.Channel should expose multiple standard channel values.'
    );
    String firstValue = entries[0].getValue();
    String secondValue = entries[1].getValue();
    SObject quickTextRow = quickTextType.newSObject();
    quickTextRow.put('Channel', firstValue + ';' + secondValue);

    Test.startTest();
    String bound = RecordHealthCheckSoqlTokenBinder.bindTokens(
      'SELECT Id FROM QuickText WHERE Channel INCLUDES {!record.Channel}',
      quickTextRow
    );
    Test.stopTest();

    Assert.areEqual(
      'SELECT Id FROM QuickText WHERE Channel INCLUDES (\'' +
        firstValue +
        '\', \'' +
        secondValue +
        '\')',
      bound,
      'Each multi-select API value should become a separately quoted INCLUDES operand.'
    );
  }
}
