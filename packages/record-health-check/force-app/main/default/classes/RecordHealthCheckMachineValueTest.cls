/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * What a machine caller is told the Check found and expected.
 *
 * The card needs a sentence: "to equal Manufacturing" reads well beside a
 * value. An automation needs the operand, because it compares. These were the
 * same field, so a Flow asking whether Expected was `Manufacturing` was handed
 * `to equal Manufacturing` and never matched.
 *
 * The operator already travels separately on `comparisonOperator`, so putting
 * it inside the value duplicated it in a form nothing could parse.
 */
@IsTest
private class RecordHealthCheckMachineValueTest {
  private static Record_Health_Check__mdt industryCheck() {
    return new Record_Health_Check__mdt(
      DeveloperName = 'IndustryOperand',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT Id, Industry FROM Account WHERE Id = {!record.Id}',
      SourceQueryField__c = 'Industry',
      QueryResultHandling__c = 'ONE_RESULT',
      ComparisonOperator__c = 'EQUALS',
      ExpectedValueSource__c = 'FIXED_VALUE',
      ExpectedFixedValue__c = 'Manufacturing',
      FailureSeverity__c = 'WARNING',
      FailureMessage__c = 'Wrong industry.'
    );
  }

  @IsTest
  static void aQueryCheckReportsTheOperandNotTheComparisonSentence() {
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'Operand Co',
          'Industry' => 'Technology'
        }
      )
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.actualValue = 'Technology';
    result.expectedValue = 'to equal Manufacturing';
    result.evaluationFound = RecordHealthCheckValue.ofString('Technology');
    result.evaluationExpected = RecordHealthCheckValue.ofString(
      'Manufacturing'
    );
    result.status = 'FAIL';
    result.operandsRecorded = true;

    RecordHealthCheckResultItem item = new RecordHealthCheckScopeResultSupport()
      .toItem(
        industryCheck(),
        record.Id,
        result,
        RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY
      );

    Assert.areEqual(
      'Manufacturing',
      item.evaluation.expected?.storedValue,
      'A caller comparing Expected must receive the operand.'
    );
    Assert.areEqual(
      'Technology',
      item.evaluation.found?.storedValue,
      'And the value the record actually held.'
    );
    Assert.areEqual(
      'EQUALS',
      item.evaluation.comparisonOperator,
      'The operator travels in its own field, so it never belongs in the value.'
    );
    Assert.areEqual(
      'to equal Manufacturing',
      item.display.expectedDisplayValue,
      'The card keeps the sentence, which is what it is for.'
    );
  }

  /**
   * The Check Result event carries the vocabulary Setup stores.
   *
   * `Severity__c` used to be remapped into the card's words on its way out, so
   * an automation matching the documented `CRITICAL` never fired and even
   * `WARNING` missed, because the wire sent `Warning`. The event copies
   * `evaluation.severity` directly, so proving the evaluation is right proves
   * the event is right, and the reference page and the payload finally agree.
   */
  @IsTest
  static void theEventVocabularyMatchesTheDocumentedContract() {
    for (String stored : new List<String>{ 'CRITICAL', 'WARNING', 'INFO' }) {
      RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
      result.status = 'FAIL';
      result.severity = stored;
      result.actualValue = 'found';
      result.expectedValue = 'expected';
      result.operandsRecorded = true;

      RecordHealthCheckResultItem item = new RecordHealthCheckScopeResultSupport()
        .toItem(
          new Record_Health_Check__mdt(
            DeveloperName = 'SeverityContract',
            EvaluationType__c = 'QUERY',
            FailureSeverity__c = stored
          ),
          RecordHealthCheckTestDataFactory.accountFixture('Severity Co').Id,
          result,
          RecordHealthCheckResultMode.EVALUATION
        );

      Assert.areEqual(
        stored,
        item.evaluation.severity,
        'Setup, the docs, the evaluation, and the event all say ' + stored
      );
    }
  }
}
