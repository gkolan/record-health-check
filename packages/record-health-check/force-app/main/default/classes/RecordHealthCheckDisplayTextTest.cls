@IsTest
private class RecordHealthCheckDisplayTextTest {
  @IsTest
  static void buildsEquivalentTextLinksAndBreaksInOrder() {
    RecordHealthCheckDisplayText content = new RecordHealthCheckDisplayText()
      .text('Step 1 - ')
      .link('Approval', '/lightning/r/Account/001000000000001AAA/view')
      .lineBreak()
      .text('Step 2')
      .paragraphBreak()
      .text('Done');

    Assert.isFalse(content.isEmpty());
    Assert.areEqual(
      'Step 1 - Approval\nStep 2\n\nDone',
      plain(content.copyNodes())
    );
    Assert.areEqual('link', content.copyNodes()[1].kind);
  }

  @IsTest
  static void normalizesNewlinesAndCoalescesAdjacentText() {
    RecordHealthCheckDisplayText content = new RecordHealthCheckDisplayText()
      .text(null)
      .text('')
      .text(' A\r\nB\rC')
      .text(' D');

    Assert.areEqual(' A\nB\nC D', plain(content.copyNodes()));
    Assert.areEqual(5, content.copyNodes().size());
  }

  @IsTest
  static void unsafeOrMissingLinksDegradeToLiteralLabels() {
    RecordHealthCheckDisplayText content = new RecordHealthCheckDisplayText()
      .link('Unsafe', 'javascript:alert(1)')
      .link(' Missing', null)
      .link('', '/safe')
      .text('{!link label="data" href="/still-data"}');

    Assert.areEqual(
      'Unsafe Missing{!link label="data" href="/still-data"}',
      plain(content.copyNodes())
    );
    Assert.isTrue(
      content.copyNodes().isEmpty() || content.copyNodes()[0].kind != 'link',
      'Unsafe destinations never become anchors.'
    );
  }

  @IsTest
  static void recordLinksRenderFourAndFiveRecordsWithExactSeparators() {
    List<SObject> stepOneUsers = userRecords('Step One User', 4, 810000);
    List<SObject> stepTwoUsers = userRecords('Step Two User', 5, 820000);

    RecordHealthCheckDisplayText content = new RecordHealthCheckDisplayText()
      .text('Step 1: ')
      .recordLinks(stepOneUsers, User.Username)
      .lineBreak()
      .text('Step 2: ')
      .recordLinks(stepTwoUsers, User.Username);

    Assert.areEqual(
      'Step 1: Step One User 1, Step One User 2, Step One User 3, Step One User 4\n' +
      'Step 2: Step Two User 1, Step Two User 2, Step Two User 3, Step Two User 4, Step Two User 5',
      plain(content.copyNodes()),
      'Each group must be separated by one line and each record by comma-space.'
    );
    Assert.areEqual(
      9,
      linkCount(content.copyNodes()),
      'Every supplied User must remain an independently clickable link.'
    );
    Assert.areEqual(
      '/lightning/r/User/' + stepTwoUsers[4].Id + '/view',
      lastLink(content.copyNodes()).href,
      'The generic helper must build a canonical Lightning record URL.'
    );
  }

  @IsTest
  static void recordLinksSupportCustomSeparatorsAndUnsavedPlainFallback() {
    Account first = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Id' => RecordHealthCheckTestDataFactory.syntheticId(
          Account.SObjectType,
          830001
        ),
        'Name' => 'First'
      }
    );
    Account unsaved = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Unsaved' }
    );
    RecordHealthCheckDisplayText content = new RecordHealthCheckDisplayText()
      .recordLinks(new List<SObject>{ first, unsaved }, Account.Name, ' | ')
      .recordLinks(null, Account.Name);

    Assert.areEqual('First | Unsaved', plain(content.copyNodes()));
    Assert.areEqual(
      1,
      linkCount(content.copyNodes()),
      'A record without an Id remains readable but cannot become a link.'
    );
  }

  @IsTest
  static void recordLinksRejectInvalidFieldContractsAndSkipsBlankRows() {
    Account blankAccount = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Id' => RecordHealthCheckTestDataFactory.syntheticId(
          Account.SObjectType,
          830002
        )
      }
    );
    RecordHealthCheckDisplayText skippedBlank = new RecordHealthCheckDisplayText()
      .recordLinks(new List<SObject>{ null, blankAccount }, Account.Name);
    RecordHealthCheckDisplayText missingField = new RecordHealthCheckDisplayText()
      .recordLinks(new List<SObject>{ blankAccount }, null);
    RecordHealthCheckDisplayText mismatchedField = new RecordHealthCheckDisplayText()
      .recordLinks(new List<SObject>{ blankAccount }, User.Name);

    Assert.isTrue(skippedBlank.isEmpty());
    Assert.isFalse(missingField.valid);
    Assert.isFalse(mismatchedField.valid);
  }

  @IsTest
  static void overrideMethodsAreChainableAndKeepNullMeaningAbsent() {
    RecordHealthCheckDisplayText found = new RecordHealthCheckDisplayText()
      .text('found');
    RecordHealthCheckDisplayOverride value = new RecordHealthCheckDisplayOverride()
      .withFound(found)
      .withExpected(null);

    Assert.areEqual(found, value.found);
    Assert.isNull(value.expected);
  }

  @IsTest
  static void metadataLinksResolveIntoCardNodesAndPlainProjection() {
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'A &/ Name' }
      )
    );
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(record);

    List<RecordHealthCheckDisplayNode> nodes = RecordHealthCheckDisplayComposer.compose(
      'Review {!link label="{!record.Name}" href="/lightning/r/Account/{!record.Name}/view"}',
      RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE,
      context
    );

    Assert.areEqual(2, nodes.size());
    Assert.areEqual('text', nodes[0].kind);
    Assert.areEqual('link', nodes[1].kind);
    Assert.areEqual('A &/ Name', nodes[1].text);
    Assert.isTrue(nodes[1].href.contains('A%20%26%2F%20Name'));
    Assert.areEqual(
      'Review A &/ Name',
      RecordHealthCheckDisplayComposer.plain(nodes)
    );
  }

  @IsTest
  static void inlineUrlResolutionSeparatesWholePathAndQueryValues() {
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'A &/ Name',
          'Website' => 'https://example.com/a%20b?q=one'
        }
      )
    );
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(record);

    Assert.areEqual(
      'https://example.com/a%20b?q=one',
      RecordHealthCheckTemplateService.resolveInlineUrl(
        '{!record.Website}',
        context
      ),
      'A lone bare token is validated as a complete URL without re-encoding.'
    );
    Assert.areEqual(
      '/search/A%20%26%2F%20Name?q=A+%26%2F+Name',
      RecordHealthCheckTemplateService.resolveInlineUrl(
        '/search/{!record.Name}?q={!record.Name}',
        context
      ),
      'Path components use percent-20 while query values preserve plus.'
    );
    record.Website = 'javascript:alert(1)';
    Assert.isNull(
      RecordHealthCheckTemplateService.resolveInlineUrl(
        '{!record.Website}',
        context
      ),
      'A dynamic unsafe complete destination degrades without exposure.'
    );
  }

  @IsTest
  static void cardAdapterAddsVersionedContentWithoutChangingPlainConsumers() {
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Acme' }
      )
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'DisplayFoundText__c' => 'Found {!link label="{!record.Name}" href="/lightning/r/Account/{!record.Id}/view"}'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.FAIL;
    result.message = 'Review {!link label="guide" href="https://example.com/guide"}';
    result.actualValue = 'Found Acme';
    result.expectedValue = 'Expected value';
    RecordHealthCheckScopeResultSupport support = new RecordHealthCheckScopeResultSupport();

    support.finalizeDisplay(check, record, result, false, true);
    RecordHealthCheckResultItem item = support.toItem(
      check,
      record.Id,
      result,
      RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY
    );

    Assert.areEqual(1, item.display.displayContent.version);
    Assert.areEqual('link', item.display.displayContent.message[1].kind);
    Assert.areEqual('link', item.display.displayContent.found[1].kind);
    Assert.areEqual('Review guide', item.display.renderedMessage);
    Assert.areEqual('Found Acme', item.display.foundDisplayValue);

    RecordHealthCheckInternalResult plain = new RecordHealthCheckInternalResult();
    plain.status = RecordHealthCheckStatus.FAIL;
    plain.message = 'Plain\nmessage';
    support.finalizeDisplay(check, record, plain, false);
    Assert.isNull(
      plain.displayContent,
      'The established non-card path does not create structured content.'
    );
  }

  private static String plain(List<RecordHealthCheckDisplayNode> nodes) {
    String result = '';
    for (RecordHealthCheckDisplayNode node : nodes) {
      result += node.kind == 'break' ? '\n' : node.text;
    }
    return result;
  }

  private static List<SObject> userRecords(
    String labelPrefix,
    Integer count,
    Integer sequenceStart
  ) {
    List<SObject> users = new List<SObject>();
    for (Integer index = 1; index <= count; index++) {
      SObject userRecord = User.SObjectType.newSObject();
      userRecord.put(
        User.Id,
        RecordHealthCheckTestDataFactory.syntheticId(
          User.SObjectType,
          sequenceStart + index
        )
      );
      userRecord.put(User.Username, labelPrefix + ' ' + index);
      users.add(userRecord);
    }
    return users;
  }

  private static Integer linkCount(List<RecordHealthCheckDisplayNode> nodes) {
    Integer count = 0;
    for (RecordHealthCheckDisplayNode node : nodes) {
      count += node.kind == 'link' ? 1 : 0;
    }
    return count;
  }

  private static RecordHealthCheckDisplayNode lastLink(
    List<RecordHealthCheckDisplayNode> nodes
  ) {
    for (Integer index = nodes.size() - 1; index >= 0; index--) {
      if (nodes[index].kind == 'link') {
        return nodes[index];
      }
    }
    return null;
  }
}
