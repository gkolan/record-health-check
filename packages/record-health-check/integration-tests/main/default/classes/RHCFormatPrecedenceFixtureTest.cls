/** Saved RHC_Format_Precedence fixtures through the public evaluation API. */
@IsTest
private class RHCFormatPrecedenceFixtureTest {
  private static final String NO_OPERAND = 'RHC_Format_Ratio_No_Operand';

  @IsTest
  static void noOperandCheckKeepsPluginLinks() {
    Account target = fixtureAccount();
    RecordHealthCheckResponse response = evaluate(
      RecordHealthCheckRequest.forCheck(
        RecordHealthCheckTestDataFactory.qualifiedCheckName(NO_OPERAND),
        target.Id
      )
    );
    Assert.areEqual(
      1,
      response.results.size(),
      'The single saved Check must return one result.'
    );
    assertLinkedUnable(response.results[0], target.Id);
  }

  @IsTest
  static void mixedSetKeepsLinksAndFormatsSiblings() {
    Account target = fixtureAccount();
    RecordHealthCheckResponse response = evaluate(
      RecordHealthCheckRequest.forCheckSet(
        RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
          'RHC_Format_Precedence'
        ),
        target.Id
      )
    );
    Map<String, RecordHealthCheckResultItem> byCheck = new Map<String, RecordHealthCheckResultItem>();
    for (RecordHealthCheckResultItem item : response.results) {
      byCheck.put(item.evaluation.checkQualifiedApiName, item);
    }
    Assert.areEqual(
      5,
      byCheck.size(),
      'The mixed Set must return each of its five Checks once.'
    );
    assertLinkedUnable(
      byCheck.get(
        RecordHealthCheckTestDataFactory.qualifiedCheckName(NO_OPERAND)
      ),
      target.Id
    );
    RecordHealthCheckResultItem ratioFail = byCheck.get(
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'RHC_Format_Ratio_Fail'
      )
    );
    Assert.areEqual(
      'FAIL',
      ratioFail.evaluation.status,
      'The sibling ratio Check must keep its independent FAIL.'
    );
    Assert.areEqual(
      '75%',
      ratioFail.display.foundDisplayValue,
      'A sibling with operands must still use the configured ratio format.'
    );
    Assert.areEqual(
      '80%',
      ratioFail.display.expectedDisplayValue,
      'A sibling with operands must still use the configured ratio format.'
    );
  }

  private static Account fixtureAccount() {
    Account target = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'RHC Format No Operand' }
    );
    RHCIntegrationTestDataFactory.createAccounts(new List<Account>{ target });
    return target;
  }

  private static RecordHealthCheckResponse evaluate(
    RecordHealthCheckRequest request
  ) {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      Test.startTest();
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
        request.withResultMode(
          RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY
        )
      );
      Test.stopTest();
      return response;
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  private static void assertLinkedUnable(
    RecordHealthCheckResultItem item,
    Id recordId
  ) {
    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      item.evaluation.status,
      'The no-operand plugin outcome must stay unable to evaluate.'
    );
    RecordHealthCheckDisplayContent content = item.display.displayContent;
    Assert.isNotNull(content, 'The plugin display must reach the response.');
    assertLink(
      content.found,
      'Open record',
      '/lightning/r/Account/' + recordId + '/view',
      'Found'
    );
    assertLink(
      content.expected,
      'Open Accounts',
      '/lightning/o/Account/home',
      'Expected'
    );
  }

  private static void assertLink(
    List<RecordHealthCheckDisplayNode> nodes,
    String label,
    String href,
    String side
  ) {
    Assert.isNotNull(
      nodes,
      side + ' nodes must survive an explicit format with no operand.'
    );
    for (RecordHealthCheckDisplayNode node : nodes) {
      if (node.kind == 'link') {
        Assert.areEqual(label, node.text, side + ' link label must survive.');
        Assert.areEqual(
          href,
          node.href,
          side + ' link destination must survive.'
        );
        return;
      }
    }
    Assert.fail(
      side + ' must keep the plugin link, not a plain-text fallback.'
    );
  }
}
