/**
 * Query row tokens against real related records.
 *
 * Unit tests can prove the grammar and the refusals, because both are decided
 * from metadata alone. They cannot prove that the rows a query actually
 * returned reach the finished message, in the order Salesforce returned them,
 * for the record the Check was asked about. That needs records, a real query,
 * and the whole evaluation path, which is what this file exercises.
 */
@IsTest
private with sharing class RHCQueryRowTokenIT {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  private static Account accountWithContacts(
    String accountName,
    List<String> lastNames,
    List<String> emails
  ) {
    Account parent = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => accountName }
    );
    RHCIntegrationTestDataFactory.createAccounts(new List<Account>{ parent });
    List<Contact> contacts = new List<Contact>();
    for (Integer i = 0; i < lastNames.size(); i++) {
      Map<String, Object> fields = new Map<String, Object>{
        'LastName' => lastNames[i],
        'AccountId' => parent.Id
      };
      if (emails[i] != null) {
        fields.put('Email', emails[i]);
      }
      contacts.add(RecordHealthCheckTestDataFactory.contact(fields));
    }
    if (!contacts.isEmpty()) {
      RHCIntegrationTestDataFactory.createContacts(contacts);
    }
    return parent;
  }

  /**
   * Rendered text is only produced when the caller asks for display content, so
   * every request here does. A row token that never renders proves nothing.
   */
  private static RecordHealthCheckResponse run(
    String checkName,
    List<Id> recordIds
  ) {
    return RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheck(
          RecordHealthCheckTestDataFactory.qualifiedCheckName(checkName),
          recordIds
        )
        .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
    );
  }

  private static RecordHealthCheckResultItem evaluate(
    String checkName,
    Id recordId
  ) {
    return run(checkName, new List<Id>{ recordId }).results[0];
  }

  @IsTest
  static void addressesTheSecondContactOfTheAccountBeingChecked() {
    Account target = accountWithContacts(
      'Row Token Target',
      new List<String>{ 'Alpha', 'Beta' },
      new List<String>{ 'alpha@example.com', null }
    );

    Test.startTest();
    RecordHealthCheckResultItem item = evaluate(
      'Account_Rows_SecondContactEmail',
      target.Id
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      item.evaluation.status,
      'A contact without an email fails the Check.'
    );
    String message = item.display.renderedMessage;
    Assert.isTrue(
      message.contains('2 contacts'),
      'The row count is the number of rows the query returned: ' + message
    );
    Assert.isTrue(
      message.contains('Row Token Target'),
      'A parent path on a queried row reads through to the Account: ' + message
    );
    Assert.isTrue(
      message.contains('Beta'),
      'Row 2 is the second contact in the query ORDER BY: ' + message
    );
    Assert.isTrue(
      message.contains('no address'),
      'A null selected field falls back rather than printing nothing: ' +
      message
    );
    Assert.isFalse(
      message.contains('{!'),
      'No token survives resolution: ' + message
    );
  }

  @IsTest
  static void buildsASafeActionLinkFromTheQueriedRow() {
    Account target = accountWithContacts(
      'Row Token Link',
      new List<String>{ 'Linkable' },
      new List<String>{ null }
    );

    Test.startTest();
    RecordHealthCheckResultItem item = evaluate(
      'Account_Rows_ActionLink',
      target.Id
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      item.evaluation.status,
      'The failing action-link fixture must retain its evaluation outcome.'
    );
    Assert.areEqual(
      'View Linkable',
      item.display.actionLabel,
      'The label names the queried record.'
    );
    Assert.isTrue(
      item.display.actionUrl.startsWith('/lightning/r/Contact/'),
      'The administrator-authored URL structure survives: ' +
      item.display.actionUrl
    );
    Assert.isTrue(
      item.display.actionUrl.endsWith('/view'),
      'And so does its tail: ' + item.display.actionUrl
    );
    Assert.isFalse(
      item.display.actionUrl.contains('{!'),
      'The row Id was substituted, not left as a token.'
    );
  }

  @IsTest
  static void readsAnAggregateAliasFromTheSingleReturnedRow() {
    Account target = accountWithContacts(
      'Row Token Aggregate',
      new List<String>{ 'One', 'Two', 'Three', 'Four', 'Five', 'Six' },
      new List<String>{ null, null, null, null, null, null }
    );

    Test.startTest();
    RecordHealthCheckResultItem item = evaluate(
      'Account_Rows_AggregateAlias',
      target.Id
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      item.evaluation.status,
      'Six contacts is not fewer than five.'
    );
    Assert.isTrue(
      item.display.renderedMessage.contains('6 contacts'),
      'The aggregate alias reads off the one row an ungrouped aggregate ' +
        'returns: ' +
        item.display.renderedMessage
    );
  }

  @IsTest
  static void fallsBackForARowTheQueryNeverReturned() {
    Account target = accountWithContacts(
      'Row Token Missing',
      new List<String>{ 'Only', 'Second' },
      new List<String>{ null, null }
    );

    Test.startTest();
    RecordHealthCheckResultItem item = evaluate(
      'Account_Rows_MissingRow',
      target.Id
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      item.evaluation.status,
      'The missing row does not change the outcome.'
    );
    Assert.isTrue(
      item.display.renderedMessage.contains('there is no third contact'),
      'Row 3 of a two-row result is empty and uses its fallback: ' +
      item.display.renderedMessage
    );
  }

  @IsTest
  static void reportsZeroForAQueryThatMatchedNothing() {
    Account target = accountWithContacts(
      'Row Token Empty',
      new List<String>{ 'Present' },
      new List<String>{ null }
    );

    Test.startTest();
    RecordHealthCheckResultItem item = evaluate(
      'Account_Rows_NoRowsReturned',
      target.Id
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      item.evaluation.status,
      'No Rows Result governs the outcome.'
    );
    String message = item.display.renderedMessage;
    Assert.isTrue(
      message.contains('Matched 0 contacts'),
      'A query that ran and matched nothing counts zero, which is not the ' +
        'same as a query that never ran: ' +
        message
    );
    Assert.isTrue(
      message.contains('absent'),
      'And its first row falls back: ' + message
    );
  }

  @IsTest
  static void keepsEachRecordsRowsToItselfAcrossAScope() {
    Account first = accountWithContacts(
      'Row Token Scope A',
      new List<String>{ 'AOne', 'ATwo' },
      new List<String>{ null, null }
    );
    Account second = accountWithContacts(
      'Row Token Scope B',
      new List<String>{ 'BOne' },
      new List<String>{ null }
    );

    Test.startTest();
    RecordHealthCheckResponse response = run(
      'Account_Rows_SecondContactEmail',
      new List<Id>{ first.Id, second.Id }
    );
    Test.stopTest();

    Map<Id, String> messageByRecord = new Map<Id, String>();
    for (RecordHealthCheckResultItem item : response.results) {
      messageByRecord.put(
        item.evaluation.recordId,
        item.display.renderedMessage
      );
    }
    Assert.isTrue(
      messageByRecord.get(first.Id).contains('2 contacts'),
      'The first record sees its own two rows: ' + messageByRecord.get(first.Id)
    );
    Assert.isTrue(
      messageByRecord.get(second.Id).contains('1 contacts'),
      'The second sees only its own: ' + messageByRecord.get(second.Id)
    );
    Assert.isTrue(
      messageByRecord.get(second.Id).contains('not present'),
      'And has no second row to name: ' + messageByRecord.get(second.Id)
    );
  }

  /**
   * What an automation is told the Check found and expected.
   *
   * The card wants a sentence: "to equal Manufacturing" reads well beside a
   * value. A Flow wants the operand, because it compares. Those were the same
   * field, so a Flow asking whether Expected was `Manufacturing` received
   * `to equal Manufacturing` and never matched, while the operator it needed
   * was already travelling separately on `comparisonOperator`.
   *
   * This lives here rather than in a package test because it has to run the
   * real evaluator against a real record: the fault was in what the evaluator
   * recorded, not in how the result was mapped afterwards.
   */
  @IsTest
  static void reportsTheOperandToCallersAndTheSentenceToTheCard() {
    Account target = accountWithContacts(
      'Operand Contract',
      new List<String>{ 'Only' },
      new List<String>{ null }
    );

    Test.startTest();
    RecordHealthCheckResultItem item = evaluate(
      'Account_Rows_SecondContactEmail',
      target.Id
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      item.evaluation.status,
      'A contact without an email fails the Check.'
    );
    // IS_NOT_BLANK compares against nothing, so there is no expected operand
    // and saying so is the honest answer. The operator carries the meaning, in
    // the field built for it. Previously this returned the sentence "to not be
    // blank" as though an automation could compare against it.
    Assert.isNull(
      item.evaluation.expected,
      'This operator expects no value: ' + item.evaluation.expected?.storedValue
    );
    Assert.areEqual(
      'IS_NOT_BLANK',
      item.evaluation.comparisonOperator,
      'The operator has its own field, which is why it never belongs in a value.'
    );
    Assert.isFalse(
      item.evaluation.found?.storedValue?.startsWith('to ') == true,
      'Found is never a comparison sentence either: ' +
      item.evaluation.found?.storedValue
    );
    Assert.isTrue(
      item.display.expectedDisplayValue?.contains('blank') == true,
      'While the card still reads the sentence: ' +
      item.display.expectedDisplayValue
    );
  }

  /**
   * The same Check asked twice gives the same answer.
   *
   * Query rows are now carried on the result as transient state, and transient
   * state that outlives one evaluation is how a second run starts reporting the
   * first run's data. Two evaluations in one transaction, then a third after
   * the records change, all have to agree with what is actually there.
   */
  @IsTest
  static void repeatingAnEvaluationRepeatsItsAnswer() {
    Account target = accountWithContacts(
      'Idempotent',
      new List<String>{ 'First', 'Second' },
      new List<String>{ null, null }
    );

    Test.startTest();
    String first = evaluate('Account_Rows_SecondContactEmail', target.Id)
      .display.renderedMessage;
    String second = evaluate('Account_Rows_SecondContactEmail', target.Id)
      .display.renderedMessage;
    Assert.areEqual(
      first,
      second,
      'Two evaluations in one transaction must agree: ' +
        first +
        ' vs ' +
        second
    );
    Assert.isTrue(
      first.contains('2 contacts'),
      'Precondition: two contacts were counted: ' + first
    );

    delete [
      SELECT Id
      FROM Contact
      WHERE AccountId = :target.Id AND LastName = 'Second'
    ];
    String afterChange = evaluate('Account_Rows_SecondContactEmail', target.Id)
      .display.renderedMessage;
    Test.stopTest();

    Assert.isTrue(
      afterChange.contains('1 contacts'),
      'And a later run reads the records as they now are, not as they were: ' +
      afterChange
    );
    Assert.isTrue(
      afterChange.contains('not present'),
      'With no second row left to name: ' + afterChange
    );
  }

  /**
   * Every negative-path Check finishes its sentence.
   *
   * A row the query never returned, and a query that matched nothing, both end
   * with something to read rather than a token, a gap, or a failure to resolve.
   */
  @IsTest
  static void everyNegativePathStillProducesReadableText() {
    Account target = accountWithContacts(
      'Negative Paths',
      new List<String>{ 'Only', 'Second' },
      new List<String>{ null, null }
    );

    Test.startTest();
    for (
      String checkName : new List<String>{
        'Account_Rows_MissingRow',
        'Account_Rows_NoRowsReturned'
      }
    ) {
      RecordHealthCheckResultItem item = evaluate(checkName, target.Id);
      Assert.isNotNull(
        item.evaluation.status,
        checkName + ' reports an outcome.'
      );
      String message = item.display?.renderedMessage;
      Assert.isNotNull(message, checkName + ' says something.');
      Assert.isFalse(
        message.contains('{!'),
        checkName + ' leaves no token unresolved: ' + message
      );
      Assert.isFalse(
        message.contains('null'),
        checkName + ' never prints the word null: ' + message
      );
    }
    Test.stopTest();
  }

  /**
   * The only Check shape that produces comparisonRows.
   *
   * A Query Check has one collection; a Compare Two Queries Check has two, and
   * a token addressing the wrong one is a sentence about the wrong query. Both
   * counts and both row collections are read in one message so a swap between
   * them cannot pass unnoticed.
   */
  @IsTest
  static void producesBothRowCollectionsForACompareTwoQueriesCheck() {
    Account target = accountWithContacts(
      'Comparison Rows',
      new List<String>{ 'One', 'Two' },
      new List<String>{ 'one@example.com', null }
    );

    Test.startTest();
    RecordHealthCheckResultItem item = evaluate(
      'Account_Rows_ComparisonRows',
      target.Id
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      item.evaluation.status,
      'The first and last surnames of two contacts are not equal.'
    );
    String message = item.display.renderedMessage;
    Assert.isTrue(
      message.contains('from One'),
      'The source aggregate is read from its own single row: ' + message
    );
    Assert.isTrue(
      message.contains('to Two'),
      'And the comparison aggregate from its own: ' + message
    );
    Assert.isTrue(
      message.contains('1 source row') && message.contains('1 comparison row'),
      'Each collection counts only the rows its own query returned: ' + message
    );
    Assert.isFalse(
      message.contains('{!'),
      'No token survives resolution: ' + message
    );
  }

  /**
   * A row field is a Salesforce field, so it takes a format attribute.
   *
   * Rendered through Display: Found Text, which is the surface a passing Check
   * still shows, so the formatting is proven where a reader actually meets it.
   */
  @IsTest
  static void formatsARowValueTheWayARecordValueIsFormatted() {
    Account target = accountWithContacts(
      'Formatted Row',
      new List<String>{ 'Dated' },
      new List<String>{ null }
    );

    Test.startTest();
    RecordHealthCheckResultItem item = evaluate(
      'Account_Rows_FormattedRowValue',
      target.Id
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      item.evaluation.status,
      'Every contact row has an Id.'
    );
    String found = item.display.foundDisplayValue;
    Assert.isTrue(
      found.contains('First of 1 contacts'),
      'The row count reads into Display: Found Text: ' + found
    );
    Assert.isFalse(
      found.contains('{!'),
      'The formatted row token resolved: ' + found
    );
    Assert.isFalse(
      found.contains('on an unknown date'),
      'CreatedDate is never blank, so the fallback is not used: ' + found
    );
    Assert.isFalse(
      found.contains(':'),
      'DATE formatting drops the time a DATETIME field would print: ' + found
    );
  }

  @IsTest
  static void readsOuterScalarBesideOpaqueChildSubquery() {
    Account target = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Scalar Beside Subquery',
        'Website' => 'https://example.com'
      }
    );
    RHCIntegrationTestDataFactory.createAccounts(new List<Account>{ target });

    Test.startTest();
    RecordHealthCheckResultItem item = evaluate(
      'Account_Rows_Scalar_Beside_Subquery',
      target.Id
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      item.evaluation.status,
      'The outer scalar fixture must pass despite an opaque child subquery: ' +
      JSON.serialize(item.evaluation)
    );
    Assert.isTrue(
      item.display.foundDisplayValue.contains('example.com'),
      'The Found projection must contain the selected outer website value.'
    );
    Assert.isFalse(
      item.display.foundDisplayValue.contains('{!'),
      'The Found projection must not expose unresolved merge syntax.'
    );
  }

  /**
   * A message can name the card it is on and the run that produced it.
   *
   * rhcSet and rhcRun are the two namespaces no fixture exercised, so nothing
   * proved they still resolve against deployed configuration and a live run
   * rather than only against a hand-built context in a unit test.
   */
  @IsTest
  static void namesItsCheckSetAndItsRunBesideItsRows() {
    Account target = accountWithContacts(
      'Set And Run',
      new List<String>{ 'Named' },
      new List<String>{ null }
    );

    Test.startTest();
    RecordHealthCheckResultItem item = evaluate(
      'Account_Rows_SetAndRunTokens',
      target.Id
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      item.evaluation.status,
      'No contact is surnamed ZzzNeverMatches.'
    );
    String message = item.display.renderedMessage;
    Assert.isTrue(
      message.contains('Coverage: Query Row Tokens That Resolve'),
      'The Check Set names itself: ' + message
    );
    Assert.isTrue(
      message.contains('on Account'),
      'Including the object it is built for: ' + message
    );
    Assert.isTrue(
      message.contains('Account_Rows_SetAndRunTokens'),
      'The Check names itself: ' + message
    );
    Assert.isTrue(
      message.contains('Named'),
      'And the row is still read in the same sentence: ' + message
    );
    Assert.isFalse(
      message.contains('{!'),
      'Every namespace resolved: ' + message
    );
    Assert.isFalse(
      message.contains('null'),
      'A run value that is not available yet uses its fallback rather than ' +
        'printing null: ' +
        message
    );
  }

  /**
   * Every refusal this framework can report, reported by the rule that owns it.
   *
   * One deployed Check per refusal, because a rule proven only against a
   * hand-built metadata row is a rule proven against the test author's idea of
   * the configuration. These rows went through Salesforce.
   */
  @IsTest
  static void everyRefusedRowTokenIsReportedByTheRuleThatOwnsIt() {
    Map<String, String> expectedReason = new Map<String, String>{
      'Account_Rows_UnselectedField' => 'QUERY_FIELD_NOT_SELECTED',
      'Account_Rows_NoStableOrder' => 'QUERY_ORDER_NOT_DETERMINISTIC',
      'Account_Rows_BeyondQueryLimit' => 'TOKEN_ROW_INDEX_INVALID',
      'Account_Rows_OneResultSecondRow' => 'TOKEN_ROW_INDEX_INVALID',
      'Account_Rows_SubqueryProjection' => 'QUERY_PROJECTION_NOT_ANALYZABLE',
      'Account_Rows_ComparisonWithoutQuery' => 'QUERY_ROLE_NOT_AVAILABLE',
      'Account_Rows_CountQueryRowCount' => 'QUERY_ROLE_NOT_AVAILABLE',
      'Account_Rows_EncryptedField' => RecordHealthCheckReasonCodes.FIELD_TYPE_NOT_SUPPORTED,
      'Account_Rows_TokenOnFormulaCheck' => 'TOKEN_NOT_ALLOWED_ON_SURFACE',
      'Account_Rows_TokenOnApexCheck' => 'TOKEN_NOT_ALLOWED_ON_SURFACE',
      'Account_Rows_UnknownFormat' => 'UNKNOWN_TOKEN_FORMAT'
    };
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    Test.startTest();
    for (String developerName : expectedReason.keySet()) {
      Record_Health_Check__mdt check = service.loadCheck(
        developerName,
        'Account_Row_Tokens_Negative'
      );
      Assert.isNotNull(check, developerName + ' is deployed and active.');
      RecordHealthCheckTokenIssue issue = RecordHealthCheckConfigValidator.firstTemplateIssue(
        check
      );
      Assert.isNotNull(issue, developerName + ' is refused.');
      Assert.areEqual(
        expectedReason.get(developerName),
        issue.reasonCode,
        developerName +
          ' is refused by the rule that owns it, not by another rule that ' +
          'happened to run first: ' +
          issue.message
      );
      Assert.isTrue(
        String.isNotBlank(issue.message),
        developerName + ' explains itself to the author.'
      );
    }
    Test.stopTest();
  }

  /**
   * A misconfigured Check is contained, not contagious.
   *
   * Setup refuses a row token naming a field the query does not select, but
   * Salesforce does not run the framework's validator at deploy time, so an
   * administrator can deploy one anyway. What matters then is that the Check
   * degrades honestly and alone: an outcome that says it cannot be evaluated,
   * an incident addressed to the administrator, the Check's own unable message
   * to the reader, and every other Check in the Check Set completely unaffected.
   *
   * The unit tests prove the rule returns a finding. Only this proves the card
   * survives someone ignoring it.
   */
  @IsTest
  static void oneMisconfiguredCheckDoesNotTakeDownItsCheckSet() {
    Account target = accountWithContacts(
      'Contained Failure',
      new List<String>{ 'Present' },
      new List<String>{ null }
    );
    String checkSetName = [
      SELECT QualifiedApiName
      FROM Record_Health_Check_Set__mdt
      WHERE DeveloperName = 'Account_Row_Tokens_Negative'
      LIMIT 1
    ]
    .QualifiedApiName;

    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
          checkSetName,
          new List<Id>{ target.Id }
        )
        .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
    );
    Test.stopTest();

    // A qualified name carries the package namespace in a namespaced org and
    // does not in a source org, so match on the developer name at its end.
    Set<String> refused = new Set<String>{
      'Account_Rows_UnselectedField',
      'Account_Rows_NoStableOrder',
      'Account_Rows_BeyondQueryLimit',
      'Account_Rows_OneResultSecondRow',
      'Account_Rows_SubqueryProjection',
      'Account_Rows_ComparisonWithoutQuery',
      'Account_Rows_CountQueryRowCount',
      'Account_Rows_EncryptedField',
      'Account_Rows_TokenOnFormulaCheck',
      'Account_Rows_TokenOnApexCheck',
      'Account_Rows_UnknownFormat'
    };
    Set<String> evaluated = new Set<String>{
      'Account_Rows_MissingRow',
      'Account_Rows_NoRowsReturned'
    };
    Map<String, RecordHealthCheckResultItem> byCheck = new Map<String, RecordHealthCheckResultItem>();
    for (RecordHealthCheckResultItem item : response.results) {
      for (String developerName : refused) {
        if (
          item.evaluation.checkQualifiedApiName?.endsWith(developerName) == true
        ) {
          byCheck.put(developerName, item);
        }
      }
      for (String developerName : evaluated) {
        if (
          item.evaluation.checkQualifiedApiName?.endsWith(developerName) == true
        ) {
          byCheck.put(developerName, item);
        }
      }
    }
    Assert.areEqual(
      refused.size() + evaluated.size(),
      response.results.size(),
      'Every Check in the set still reports: ' + byCheck.keySet()
    );

    for (String name : refused) {
      RecordHealthCheckResultItem broken = byCheck.get(name);
      Assert.areEqual(
        RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
        broken.evaluation.status,
        name + ' says it cannot be evaluated.'
      );
      Assert.areEqual(
        'INVALID_CONFIG',
        broken.evaluation.reasonCode,
        name + ' names configuration as the cause, not the data.'
      );
      Assert.isFalse(
        broken.display.renderedMessage.contains('{!'),
        name +
          ' never shows the reader a raw token: ' +
          broken.display.renderedMessage
      );
    }

    for (String name : evaluated) {
      Assert.areEqual(
        RecordHealthCheckStatus.FAIL,
        byCheck.get(name).evaluation.status,
        name + ' is unaffected by its neighbours being broken.'
      );
      Assert.isFalse(
        byCheck.get(name).display.renderedMessage.contains('{!'),
        name + ' still renders cleanly.'
      );
    }
  }
}
