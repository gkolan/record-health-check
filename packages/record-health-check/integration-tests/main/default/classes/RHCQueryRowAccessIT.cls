/**
 * What a restricted reader can obtain through a query row token.
 *
 * Row tokens read rows the Check's own query returned, and that query runs in
 * user mode. A reader who cannot see an object, a record, or a field must not
 * be handed its contents through a message, a label, or a link — the token is
 * a rendering device, never a way around access.
 *
 * The assertion is deliberately not "it fails". It is that the reader receives
 * either nothing or a refusal, never data, and that the same Check behaves the
 * same way every time it is asked.
 */
@IsTest
private with sharing class RHCQueryRowAccessIT {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @IsTest
  static void aRestrictedReaderNeverReceivesRowDataThroughAToken() {
    Account parent = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Row Access Parent' }
    );
    RHCIntegrationTestDataFactory.createAccounts(new List<Account>{ parent });
    RHCIntegrationTestDataFactory.createContacts(
      new List<Contact>{
        RecordHealthCheckTestDataFactory.contact(
          new Map<String, Object>{
            'LastName' => 'SecretName',
            'Email' => 'secret@example.com',
            'AccountId' => parent.Id
          }
        )
      }
    );
    User restricted = RecordHealthCheckPersonaTestDataFactory.createMinimumAccessUser(
      'rowacc'
    );

    String rendered;
    String failure;
    Test.startTest();
    System.runAs(restricted) {
      try {
        RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
          RecordHealthCheckRequest.forCheck(
              RecordHealthCheckTestDataFactory.qualifiedCheckName(
                'Account_Rows_SecondContactEmail'
              ),
              new List<Id>{ parent.Id }
            )
            .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
        );
        rendered = response.results.isEmpty()
          ? null
          : response.results[0].display?.renderedMessage;
      } catch (Exception refused) {
        failure = refused.getMessage();
      }
    }
    Test.stopTest();

    String everythingTheReaderSaw =
      String.valueOf(rendered) +
      ' ' +
      String.valueOf(failure);
    Assert.isFalse(
      everythingTheReaderSaw.contains('SecretName'),
      'A restricted reader must not be handed the queried name: ' +
      everythingTheReaderSaw
    );
    Assert.isFalse(
      everythingTheReaderSaw.contains('secret@example.com'),
      'Nor the queried email: ' + everythingTheReaderSaw
    );
  }

  /**
   * The same question asked twice by the same restricted reader gives the same
   * answer. A degradation that varies between runs is indistinguishable from a
   * leak that only sometimes happens.
   */
  @IsTest
  static void restrictedBehaviourIsTheSameEveryTime() {
    Account parent = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Row Access Stable' }
    );
    RHCIntegrationTestDataFactory.createAccounts(new List<Account>{ parent });
    User restricted = RecordHealthCheckPersonaTestDataFactory.createMinimumAccessUser(
      'rowsta'
    );

    List<String> outcomes = new List<String>();
    Test.startTest();
    System.runAs(restricted) {
      for (Integer attempt = 0; attempt < 2; attempt++) {
        try {
          RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
            RecordHealthCheckRequest.forCheck(
              RecordHealthCheckTestDataFactory.qualifiedCheckName(
                'Account_Rows_SecondContactEmail'
              ),
              new List<Id>{ parent.Id }
            )
          );
          outcomes.add(
            response.results.isEmpty()
              ? 'no result'
              : String.valueOf(response.results[0].evaluation.status) +
                '/' +
                String.valueOf(response.results[0].evaluation.reasonCode)
          );
        } catch (Exception refused) {
          outcomes.add('refused:' + refused.getTypeName());
        }
      }
    }
    Test.stopTest();

    Assert.areEqual(
      outcomes[0],
      outcomes[1],
      'The same reader asking twice must be told the same thing: ' + outcomes
    );
  }
}
