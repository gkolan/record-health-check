/** Verifies scope-wide bounds before optional plugin fields are detached. */
@IsTest
private class RHCPluginDisplayBudgetTest {
  @IsTest
  static void detachedFieldsShareOneScopeBudget() {
    RecordHealthCheckScope scope = scopeFor(5);
    BudgetPlugin plugin = new BudgetPlugin(false);
    Test.startTest();
    Map<Id, RecordHealthCheckDisplayOverride> copied = RecordHealthCheckPluginDisplayDispatch.run(
      plugin,
      scope
    );
    Test.stopTest();
    Integer bytes = 0;
    for (Id recordId : scope.recordIds) {
      if (copied.get(recordId).found != null) {
        bytes += Blob.valueOf(
            JSON.serialize(copied.get(recordId).found.copyNodes())
          )
          .size();
      }
    }
    Assert.isTrue(
      Blob.valueOf(JSON.serialize(copied)).size() <= 262144,
      'The scope bound must include record identities, object properties and builder state.'
    );
    Assert.isTrue(
      bytes <= 262144,
      'Detached fields must share the 256 KiB scope allocation.'
    );
    Assert.isNotNull(
      copied.get(scope.recordIdAt(0)).found,
      'The first requested record must retain its field.'
    );
    Assert.isNull(
      copied.get(scope.recordIdAt(4)).found,
      'The first field beyond the shared budget must be omitted.'
    );
  }

  @IsTest
  static void messageAndFixPrecedeValueOverrides() {
    RecordHealthCheckScope scope = scopeFor(2);
    Test.startTest();
    Map<Id, RecordHealthCheckDisplayOverride> copied = RecordHealthCheckPluginDisplayDispatch.run(
      new BudgetPlugin(true),
      scope
    );
    Test.stopTest();
    RecordHealthCheckDisplayOverride second = copied.get(scope.recordIdAt(1));
    Assert.isNotNull(
      second.message,
      'Message must receive allocation before value overrides.'
    );
    Assert.isNotNull(
      second.fix,
      'Fix must receive allocation before value overrides.'
    );
    Assert.isNull(
      second.found,
      'Found must yield when message and fix consume the available scope budget.'
    );
    Assert.isNull(
      second.expected,
      'Expected must remain omitted after scope exhaustion.'
    );
  }

  @IsTest
  static void acceptedFieldsAreDetachedFromPluginState() {
    RecordHealthCheckScope scope = scopeFor(1);
    BudgetPlugin plugin = new BudgetPlugin(false);
    Test.startTest();
    Map<Id, RecordHealthCheckDisplayOverride> copied = RecordHealthCheckPluginDisplayDispatch.run(
      plugin,
      scope
    );
    Test.stopTest();
    String before = JSON.serialize(
      copied.get(scope.recordIdAt(0)).found.copyNodes()
    );
    plugin.authored.text('Later mutation');
    Assert.areEqual(
      before,
      JSON.serialize(copied.get(scope.recordIdAt(0)).found.copyNodes()),
      'Budgeting must preserve the existing detached-copy boundary.'
    );
  }

  private static RecordHealthCheckScope scopeFor(Integer count) {
    List<Id> ids = new List<Id>();
    for (Integer index = 0; index < count; index++) {
      ids.add(
        RecordHealthCheckTestDataFactory.syntheticId(
          Account.SObjectType,
          index + 1
        )
      );
    }
    return new RecordHealthCheckScope(
      'Account',
      ids,
      null,
      'Budget',
      null,
      'budget-run'
    );
  }

  @IsTest
  static void emptyBuildersRemainAbsent() {
    RecordHealthCheckScope scope = scopeFor(1);
    BudgetPlugin plugin = new BudgetPlugin(false);
    plugin.authored = new RecordHealthCheckDisplayText();
    Test.startTest();
    Map<Id, RecordHealthCheckDisplayOverride> copied = RecordHealthCheckPluginDisplayDispatch.run(
      plugin,
      scope
    );
    Test.stopTest();
    Assert.isNull(
      copied.get(scope.recordIdAt(0)).found,
      'A zero-node field must remain absent after the allocation check.'
    );
  }

  @IsTest
  static void breakOnlyBuildersRemainPresent() {
    RecordHealthCheckScope scope = scopeFor(1);
    BudgetPlugin plugin = new BudgetPlugin(false);
    plugin.authored = new RecordHealthCheckDisplayText().lineBreak();
    Test.startTest();
    Map<Id, RecordHealthCheckDisplayOverride> copied = RecordHealthCheckPluginDisplayDispatch.run(
      plugin,
      scope
    );
    Test.stopTest();
    Assert.areEqual(
      'break',
      copied.get(scope.recordIdAt(0)).found.copyNodes()[0].kind,
      'Structural emptiness must not discard an intentional break-only override.'
    );
  }

  @IsTest
  static void scopeExhaustionProducesOneAggregateFinding() {
    RecordHealthCheckScope scope = scopeFor(7);
    Test.startTest();
    Map<Id, RecordHealthCheckDisplayOverride> copied = RecordHealthCheckPluginDisplayDispatch.run(
      new BudgetPlugin(false),
      scope
    );
    Test.stopTest();
    Integer findings = 0;
    for (RecordHealthCheckDisplayOverride value : copied.values()) {
      if (value.invalidFields.contains('displayBudget')) {
        findings++;
      }
    }
    Assert.areEqual(
      1,
      findings,
      'Further rejected records must not repeat the scope-budget finding.'
    );
  }

  @IsTest
  static void sizeInspectionMatchesSerializedNodes() {
    RecordHealthCheckDisplayText value = new RecordHealthCheckDisplayText()
      .text('é😀"\t')
      .lineBreak()
      .link('Open', '/record');
    Test.startTest();
    Integer measured = value.serializedSize();
    Integer count = value.nodeCount();
    Test.stopTest();
    Assert.areEqual(
      Blob.valueOf(JSON.serialize(value.copyNodes())).size(),
      measured,
      'The allocation counter must include UTF-8 and JSON escaping.'
    );
    Assert.areEqual(
      value.copyNodes().size(),
      count,
      'Structural inspection must report all retained nodes without changing them.'
    );
  }

  @IsTest
  static void oversizedMetadataDoesNotBypassTheScopeBudget() {
    RecordHealthCheckScope scope = scopeFor(1);
    BudgetPlugin plugin = new BudgetPlugin(false);
    plugin.expectedLabel = ''.leftPad(270000, 'x');
    Test.startTest();
    Map<Id, RecordHealthCheckDisplayOverride> copied = RecordHealthCheckPluginDisplayDispatch.run(
      plugin,
      scope
    );
    Test.stopTest();
    RecordHealthCheckDisplayOverride value = copied.get(scope.recordIdAt(0));
    Assert.isNull(
      value.expectedLabel,
      'Oversized non-node presentation metadata must not bypass the shared allocation.'
    );
    Assert.isNotNull(
      value.found,
      'A rejected metadata allocation must preserve a valid field accepted earlier.'
    );
    Assert.isTrue(
      value.invalidFields.contains('displayBudget'),
      'Metadata exhaustion must expose the same bounded aggregate finding.'
    );
    Assert.areEqual(
      270000,
      plugin.expectedLabel.length(),
      'Budget enforcement must not mutate subscriber-owned metadata.'
    );
  }

  @IsTest
  static void acceptedMetadataRemainsAvailable() {
    RecordHealthCheckScope scope = scopeFor(1);
    BudgetPlugin plugin = new BudgetPlugin(false);
    plugin.expectedLabel = 'Required amount';
    Test.startTest();
    Map<Id, RecordHealthCheckDisplayOverride> copied = RecordHealthCheckPluginDisplayDispatch.run(
      plugin,
      scope
    );
    Test.stopTest();
    Assert.areEqual(
      'Required amount',
      copied.get(scope.recordIdAt(0)).expectedLabel,
      'Metadata within the shared budget must remain available to presentation.'
    );
    Assert.isTrue(
      Blob.valueOf(JSON.serialize(copied)).size() <= 262144,
      'The complete serialized detached map must remain within the scope budget.'
    );
  }

  @IsTest
  static void completeCopyAcceptsOneByteBelowLimit() {
    assertCompleteCopyBoundary(262143, true);
  }

  @IsTest
  static void completeCopyAcceptsExactLimit() {
    assertCompleteCopyBoundary(262144, true);
  }

  @IsTest
  static void completeCopyRejectsOneByteAboveLimit() {
    assertCompleteCopyBoundary(262145, false);
  }

  private static void assertCompleteCopyBoundary(
    Integer targetBytes,
    Boolean accepted
  ) {
    RecordHealthCheckScope scope = scopeFor(1);
    BudgetPlugin plugin = new BudgetPlugin(false);
    plugin.expectedLabel = 'é😀"\t';
    Integer baseBytes = Blob.valueOf(JSON.serialize(plugin.getDisplay(scope)))
      .size();
    plugin.expectedLabel += ''.leftPad(targetBytes - baseBytes, 'x');
    Assert.areEqual(
      targetBytes,
      Blob.valueOf(JSON.serialize(plugin.getDisplay(scope))).size(),
      'The fixture must hit its exact serialized UTF-8 boundary, including escaping and all object overhead.'
    );
    Test.startTest();
    Map<Id, RecordHealthCheckDisplayOverride> copied = RecordHealthCheckPluginDisplayDispatch.run(
      plugin,
      scope
    );
    Test.stopTest();
    RecordHealthCheckDisplayOverride value = copied.get(scope.recordIdAt(0));
    Assert.areEqual(
      accepted,
      value.expectedLabel != null,
      'Metadata acceptance must follow the inclusive complete-map byte limit.'
    );
    Assert.isNotNull(
      value.found,
      'Valid earlier rich content must survive a metadata boundary rejection.'
    );
    Assert.areEqual(
      !accepted,
      value.invalidFields.contains('displayBudget'),
      'Only an actual overflow may emit the scope-budget finding.'
    );
    if (accepted) {
      Assert.areEqual(
        targetBytes,
        Blob.valueOf(JSON.serialize(copied)).size(),
        'Detaching an accepted boundary value must preserve its exact serialized size.'
      );
    } else {
      Assert.isTrue(
        Blob.valueOf(JSON.serialize(copied)).size() <= 262144,
        'Omitting overflowing metadata must leave a bounded complete map.'
      );
    }
  }

  @IsTest
  static void everyMetadataStringSharesTheBudget() {
    RecordHealthCheckScope scope = scopeFor(1);
    String oversized = ''.leftPad(270000, 'x');
    Test.startTest();
    for (
      String field : new List<String>{
        'foundFormat',
        'foundCurrencyIsoCode',
        'expectedFormat',
        'expectedCurrencyIsoCode',
        'actionLabel',
        'actionDestination'
      }
    ) {
      BudgetPlugin plugin = new BudgetPlugin(false);
      plugin.authored = new RecordHealthCheckDisplayText()
        .text('Retain this field');
      plugin.expectedLabel = 'Safe sibling';
      plugin.metadata.put(field, oversized);
      RecordHealthCheckDisplayOverride value = RecordHealthCheckPluginDisplayDispatch.run(
          plugin,
          scope
        )
        .get(scope.recordIdAt(0));
      Assert.isNotNull(
        value.found,
        field + ': rich content accepted first must survive.'
      );
      Assert.isNull(
        value.expectedLabel,
        field + ': overflowing metadata must be omitted as one allocation.'
      );
      Assert.isNull(
        value.action,
        field + ': an overflowing action or sibling metadata must not survive.'
      );
      Assert.isNull(
        value.foundFormat,
        field + ': rejected metadata must not retain its Found format.'
      );
      Assert.isNull(
        value.foundCurrencyIsoCode,
        field + ': rejected metadata must not retain its Found currency.'
      );
      Assert.isNull(
        value.expectedFormat,
        field + ': rejected metadata must not retain its Expected format.'
      );
      Assert.isNull(
        value.expectedCurrencyIsoCode,
        field + ': rejected metadata must not retain its Expected currency.'
      );
      Assert.isTrue(
        value.invalidFields.contains('displayBudget'),
        field + ': overflow must remain diagnosable.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void acceptedActionAndFormatsArePreserved() {
    RecordHealthCheckScope scope = scopeFor(1);
    BudgetPlugin plugin = new BudgetPlugin(false);
    plugin.metadata.put('actionLabel', 'Open é😀"');
    plugin.metadata.put('actionDestination', '/record?name=example');
    plugin.metadata.put('foundFormat', 'CURRENCY');
    plugin.metadata.put('foundCurrencyIsoCode', 'USD');
    plugin.metadata.put('expectedFormat', 'NUMBER');
    plugin.metadata.put('expectedCurrencyIsoCode', 'EUR');
    Test.startTest();
    RecordHealthCheckDisplayOverride value = RecordHealthCheckPluginDisplayDispatch.run(
        plugin,
        scope
      )
      .get(scope.recordIdAt(0));
    Test.stopTest();
    Assert.areEqual(
      'Open é😀"',
      value.action.label,
      'Accepted action labels must preserve Unicode and quotes.'
    );
    Assert.areEqual(
      '/record?name=example',
      value.action.destination,
      'Accepted actions must preserve their destination.'
    );
    Assert.areEqual(
      'CURRENCY',
      value.foundFormat,
      'Accepted Found formats must survive.'
    );
    Assert.areEqual(
      'USD',
      value.foundCurrencyIsoCode,
      'Accepted Found currency codes must survive.'
    );
    Assert.areEqual(
      'NUMBER',
      value.expectedFormat,
      'Accepted Expected formats must survive.'
    );
    Assert.areEqual(
      'EUR',
      value.expectedCurrencyIsoCode,
      'Accepted Expected currency codes must survive.'
    );
    Assert.isFalse(
      value.invalidFields.contains('displayBudget'),
      'Accepted metadata must not emit a budget finding.'
    );
  }

  private class BudgetPlugin implements RecordHealthCheckPlugin, RecordHealthCheckDisplayPlugin {
    private Boolean allFields;
    public RecordHealthCheckDisplayText authored;
    public String expectedLabel;
    public Map<String, String> metadata = new Map<String, String>();

    public BudgetPlugin(Boolean allFields) {
      this.allFields = allFields;
      authored = new RecordHealthCheckDisplayText();
      String href = 'https://example.com/' + ''.leftPad(1950, 'a');
      Integer links = allFields ? 20 : 30;
      for (Integer index = 0; index < links; index++) {
        authored.link('Evidence', href);
      }
    }

    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      return new Map<Id, RecordHealthCheckOutcome>();
    }

    public Map<Id, RecordHealthCheckDisplayOverride> getDisplay(
      RecordHealthCheckScope scope
    ) {
      Map<Id, RecordHealthCheckDisplayOverride> returned = new Map<Id, RecordHealthCheckDisplayOverride>();
      for (Id recordId : scope.recordIds) {
        RecordHealthCheckDisplayOverride value = new RecordHealthCheckDisplayOverride()
          .withFound(authored)
          .withExpectedLabel(expectedLabel)
          .withFoundFormat(
            metadata.get('foundFormat'),
            metadata.get('foundCurrencyIsoCode')
          )
          .withExpectedFormat(
            metadata.get('expectedFormat'),
            metadata.get('expectedCurrencyIsoCode')
          );
        if (
          metadata.containsKey('actionLabel') ||
          metadata.containsKey('actionDestination')
        ) {
          value.withAction(
            new RecordHealthCheckDisplayAction(
              metadata.get('actionLabel'),
              metadata.get('actionDestination')
            )
          );
        }
        if (allFields) {
          value.withMessage(authored).withFix(authored).withExpected(authored);
        }
        returned.put(recordId, value);
      }
      return returned;
    }
  }
}
