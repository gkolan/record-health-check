@IsTest
private class RecordHealthCheckDisplayGroupTest {
  @IsTest
  static void rendersOrderedClickableStepsWithOneTwoAndThreeUsers() {
    List<SObject> stepOneUsers = userRecords('Step One User', 1, 840000);
    List<SObject> stepTwoUsers = userRecords('Step Two User', 2, 850000);
    List<SObject> stepThreeUsers = userRecords('Step Three User', 3, 860000);

    List<RecordHealthCheckDisplayGroup> groups = new List<RecordHealthCheckDisplayGroup>{
      group('step-1', 'Step 1', accountId(840001), stepOneUsers),
      group('step-2', 'Step 2', accountId(840002), stepTwoUsers),
      group('step-3', 'Step 3', accountId(840003), stepThreeUsers)
    };

    RecordHealthCheckDisplayText content = new RecordHealthCheckDisplayText()
      .groups(groups);

    Assert.isTrue(
      content.valid,
      'Ordered groups with record links must remain valid.'
    );
    Assert.areEqual(
      'Step 1: Step One User 1\n' +
        'Step 2: Step Two User 1, Step Two User 2\n' +
        'Step 3: Step Three User 1, Step Three User 2, Step Three User 3',
      plain(content.copyNodes()),
      'Groups preserve explicit group and item order with one line per group.'
    );
    Assert.areEqual(
      9,
      linkCount(content.copyNodes()),
      'Each Step and each User remains an independently clickable link.'
    );
  }

  @IsTest
  static void hidesEmptyGroupsUnlessAnEmptyStateIsSupplied() {
    List<RecordHealthCheckDisplayGroup> groups = new List<RecordHealthCheckDisplayGroup>{
      new RecordHealthCheckDisplayGroup('hidden')
        .withLabel(new RecordHealthCheckDisplayText().text('Hidden'))
        .withItems(new RecordHealthCheckDisplayText()),
      new RecordHealthCheckDisplayGroup('shown')
        .withLabel(new RecordHealthCheckDisplayText().text('Step 2'))
        .withItems(new RecordHealthCheckDisplayText())
        .withEmptyState(new RecordHealthCheckDisplayText().text('No users'))
    };

    RecordHealthCheckDisplayText content = new RecordHealthCheckDisplayText()
      .groups(groups);

    Assert.isTrue(
      content.valid,
      'Hidden and explicit empty-state groups must remain valid.'
    );
    Assert.areEqual(
      'Step 2: No users',
      plain(content.copyNodes()),
      'A hidden empty group must not leave a leading or trailing break.'
    );
  }

  @IsTest
  static void preservesDuplicateItemsAndSupportsExplicitSeparator() {
    List<SObject> repeatedUser = userRecords('Repeated User', 1, 870000);
    repeatedUser.add(repeatedUser[0]);
    RecordHealthCheckDisplayGroup displayGroup = new RecordHealthCheckDisplayGroup(
        'duplicates'
      )
      .withLabel(new RecordHealthCheckDisplayText().text('Reviewers'))
      .withSeparator(' -> ')
      .withItems(
        new RecordHealthCheckDisplayText()
          .recordLinks(repeatedUser, User.Username)
      );

    RecordHealthCheckDisplayText content = new RecordHealthCheckDisplayText()
      .groups(new List<RecordHealthCheckDisplayGroup>{ displayGroup });

    Assert.areEqual(
      'Reviewers -> Repeated User 1, Repeated User 1',
      plain(content.copyNodes()),
      'Explicit separators must preserve duplicate item text.'
    );
    Assert.areEqual(
      2,
      linkCount(content.copyNodes()),
      'Duplicate items must retain both independent links.'
    );
  }

  @IsTest
  static void rejectsInvalidGroupContracts() {
    RecordHealthCheckDisplayText blankKey = new RecordHealthCheckDisplayText()
      .groups(
        new List<RecordHealthCheckDisplayGroup>{
          new RecordHealthCheckDisplayGroup(' ')
            .withLabel(new RecordHealthCheckDisplayText().text('Step'))
            .withItems(new RecordHealthCheckDisplayText().text('User'))
        }
      );
    RecordHealthCheckDisplayText duplicateKeys = new RecordHealthCheckDisplayText()
      .groups(
        new List<RecordHealthCheckDisplayGroup>{
          textGroup('same', 'Step 1', 'User 1'),
          textGroup('same', 'Step 2', 'User 2')
        }
      );
    RecordHealthCheckDisplayText nullGroup = new RecordHealthCheckDisplayText()
      .groups(new List<RecordHealthCheckDisplayGroup>{ null });
    RecordHealthCheckDisplayText emptyLabel = new RecordHealthCheckDisplayText()
      .groups(
        new List<RecordHealthCheckDisplayGroup>{
          new RecordHealthCheckDisplayGroup('empty-label')
            .withLabel(new RecordHealthCheckDisplayText())
            .withItems(new RecordHealthCheckDisplayText().text('User'))
        }
      );
    RecordHealthCheckDisplayText nullSeparator = new RecordHealthCheckDisplayText()
      .groups(
        new List<RecordHealthCheckDisplayGroup>{
          textGroup('separator', 'Step', 'User').withSeparator(null)
        }
      );

    Assert.isFalse(
      blankKey.valid,
      'A blank group key must invalidate grouped content.'
    );
    Assert.isFalse(
      duplicateKeys.valid,
      'Duplicate group keys must invalidate grouped content.'
    );
    Assert.isFalse(
      nullGroup.valid,
      'A null group must invalidate grouped content.'
    );
    Assert.isFalse(
      emptyLabel.valid,
      'An empty group label must invalidate grouped content.'
    );
    Assert.isFalse(
      nullSeparator.valid,
      'A null group separator must invalidate grouped content.'
    );
  }

  @IsTest
  static void rejectsInvalidNestedFragmentsAndAggregateOverflow() {
    RecordHealthCheckDisplayText invalidItems = new RecordHealthCheckDisplayText()
      .recordLinks(userRecords('User', 1, 880000), null);
    RecordHealthCheckDisplayText invalidNested = new RecordHealthCheckDisplayText()
      .groups(
        new List<RecordHealthCheckDisplayGroup>{
          new RecordHealthCheckDisplayGroup('invalid')
            .withLabel(new RecordHealthCheckDisplayText().text('Step'))
            .withItems(invalidItems)
        }
      );

    String largeValue = ''.leftPad(11000, 'x');
    RecordHealthCheckDisplayText overflow = new RecordHealthCheckDisplayText()
      .groups(
        new List<RecordHealthCheckDisplayGroup>{
          textGroup('large-1', 'Step 1', largeValue),
          textGroup('large-2', 'Step 2', largeValue)
        }
      );

    Assert.isFalse(
      invalidNested.valid,
      'Invalid nested items must invalidate their group content.'
    );
    Assert.isFalse(
      overflow.valid,
      'Aggregate group overflow must invalidate grouped content.'
    );
  }

  @IsTest
  static void nullAndEmptyGroupCollectionsAreNoOps() {
    RecordHealthCheckDisplayText content = new RecordHealthCheckDisplayText()
      .text('Before')
      .groups(null)
      .groups(new List<RecordHealthCheckDisplayGroup>());

    Assert.isTrue(
      content.valid,
      'Null and empty group collections must preserve validity.'
    );
    Assert.areEqual(
      'Before',
      plain(content.copyNodes()),
      'Null and empty group collections must preserve existing text.'
    );
  }

  private static RecordHealthCheckDisplayGroup group(
    String key,
    String label,
    Id accountId,
    List<SObject> users
  ) {
    return new RecordHealthCheckDisplayGroup(key)
      .withLabel(
        new RecordHealthCheckDisplayText()
          .link(label, '/lightning/r/Account/' + accountId + '/view')
      )
      .withItems(
        new RecordHealthCheckDisplayText().recordLinks(users, User.Username)
      );
  }

  private static Id accountId(Integer sequence) {
    return RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      sequence
    );
  }

  private static RecordHealthCheckDisplayGroup textGroup(
    String key,
    String label,
    String items
  ) {
    return new RecordHealthCheckDisplayGroup(key)
      .withLabel(new RecordHealthCheckDisplayText().text(label))
      .withItems(new RecordHealthCheckDisplayText().text(items));
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

  private static String plain(List<RecordHealthCheckDisplayNode> nodes) {
    String result = '';
    for (RecordHealthCheckDisplayNode node : nodes) {
      result += node.kind == 'break' ? '\n' : node.text;
    }
    return result;
  }

  private static Integer linkCount(List<RecordHealthCheckDisplayNode> nodes) {
    Integer count = 0;
    for (RecordHealthCheckDisplayNode node : nodes) {
      count += node.kind == 'link' ? 1 : 0;
    }
    return count;
  }
}
