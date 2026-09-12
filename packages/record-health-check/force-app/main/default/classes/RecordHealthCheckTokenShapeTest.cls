/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckTokenShapeTest {
  @IsTest
  static void readsRowCollectionPositionAndField() {
    RecordHealthCheckTokenShape source = RecordHealthCheckTokenRegistry.resolve(
      'rhcQuery',
      'sourceRows[0].Name'
    );
    Assert.isTrue(source.isUsable(), 'A well-formed row token resolves.');
    Assert.areEqual(
      RecordHealthCheckTokenShape.KIND_QUERY_ROW_FIELD,
      source.kind,
      'A row field token must retain its query-row-field kind.'
    );
    Assert.areEqual(
      'sourceRows',
      source.collection,
      'The primary row token must select sourceRows.'
    );
    Assert.areEqual(0, source.rowIndex, 'Indexes are zero-based.');
    Assert.areEqual(
      'Name',
      source.fieldPath,
      'The primary row token must retain its terminal Name field.'
    );
    Assert.isTrue(
      source.isTypedField,
      'A query row field still has a Salesforce data type.'
    );
    Assert.isFalse(
      source.readsComparisonQuery(),
      'A sourceRows token must not read the comparison query.'
    );

    RecordHealthCheckTokenShape comparison = RecordHealthCheckTokenRegistry.resolve(
      'rhcQuery',
      'comparisonRows[3].Owner.Name'
    );
    Assert.isTrue(
      comparison.readsComparisonQuery(),
      'A comparisonRows token must read the comparison query.'
    );
    Assert.areEqual(
      3,
      comparison.rowIndex,
      'The comparison row index must remain zero-based at three.'
    );
    Assert.areEqual(
      'Owner.Name',
      comparison.fieldPath,
      'The comparison token must retain the complete Owner.Name path.'
    );

    RecordHealthCheckTokenShape count = RecordHealthCheckTokenRegistry.resolve(
      'rhcQuery',
      'sourceRowCount'
    );
    Assert.areEqual(
      RecordHealthCheckTokenShape.KIND_QUERY_ROW_COUNT,
      count.kind,
      'A source row count must use the row-count kind.'
    );
    Assert.isFalse(
      count.isTypedField,
      'A count is a whole number the Framework already renders.'
    );
  }

  @IsTest
  static void rejectsEveryIndexThatIsNotAZeroBasedWholeNumber() {
    for (
      String property : new List<String>{
        'sourceRows[-1].Id',
        'sourceRows[1.5].Id',
        'sourceRows[i].Id',
        'sourceRows[1+1].Id',
        'sourceRows[*].Id',
        'sourceRows[1:3].Id',
        'sourceRows[+1].Id',
        'sourceRows[00].Id',
        'sourceRows[01].Id',
        'sourceRows[].Id',
        'sourceRows[ ].Id',
        'sourceRows[2000].Id',
        'sourceRows[999999999999999999999999999999999].Id'
      }
    ) {
      RecordHealthCheckTokenShape shape = RecordHealthCheckTokenRegistry.resolve(
        'rhcQuery',
        property
      );
      Assert.isFalse(shape.isUsable(), 'Must be refused: ' + property);
      Assert.areEqual(
        'TOKEN_ROW_INDEX_INVALID',
        shape.reasonCode,
        'An unusable index is an index problem, not a missing row: ' + property
      );
    }
    Assert.isTrue(
      RecordHealthCheckTokenRegistry.resolve('rhcQuery', 'sourceRows[1999].Id')
        .isUsable(),
      'The last row a Check can return is addressable.'
    );
  }

  @IsTest
  static void rejectsRowReferencesThatDoNotEndInAField() {
    for (
      String property : new List<String>{
        'sourceRows[1]',
        'sourceRows[1].',
        'sourceRows[1].Owner.',
        'sourceRows[1].Owner Name',
        'sourceRows[1].9Field',
        'sourceRows',
        'sourceRow[1].Id',
        'rows[1].Id'
      }
    ) {
      Assert.isFalse(
        RecordHealthCheckTokenRegistry.resolve('rhcQuery', property).isUsable(),
        'A row token needs a terminal field path: ' + property
      );
    }
  }

  @IsTest
  static void namesTheSupportedSyntaxWhenTheAuthorGuessed() {
    RecordHealthCheckTokenShape shape = RecordHealthCheckTokenRegistry.resolve(
      'rhcQuery',
      'firstSourceRow.Id'
    );
    Assert.areEqual(
      'UNKNOWN_TOKEN_PROPERTY',
      shape.reasonCode,
      'An unsupported guessed property must retain its unknown-property reason.'
    );
    Assert.isTrue(
      shape.message.contains('sourceRows[0].Field'),
      'The message must name the supported form: ' + shape.message
    );
  }

  @IsTest
  static void refusesRecordPathsThatCouldOnlyFailWhenTheCheckRuns() {
    // The framework cannot know every field of every object while an author is
    // editing, and does not try. It can tell that a path is not shaped like a
    // field path, and that it is deeper than the resolver will follow. Both
    // used to be discovered only when the Check ran on a record page.
    for (
      String property : new List<String>{
        'Amount+1',
        '.Name',
        'Name.',
        'Owner..Name',
        'Owner Name',
        '9Field',
        'A.B.C.D.E.F.G'
      }
    ) {
      RecordHealthCheckTokenShape shape = RecordHealthCheckTokenRegistry.resolve(
        'record',
        property
      );
      Assert.isFalse(shape.isUsable(), 'Must be refused: ' + property);
      Assert.areEqual('UNKNOWN_TOKEN_PROPERTY', shape.reasonCode, property);
    }
    for (
      String property : new List<String>{
        'Name',
        'Owner.Name',
        'Custom_Field__c',
        'A.B.C.D.E.F'
      }
    ) {
      Assert.isTrue(
        RecordHealthCheckTokenRegistry.resolve('record', property).isUsable(),
        'Must still be accepted: ' + property
      );
    }
  }

  @IsTest
  static void keepsExistingNamespacesUnchanged() {
    Assert.isTrue(
      RecordHealthCheckTokenRegistry.contains('rhcResult', 'foundValue'),
      'The established finalized Found property must remain registered.'
    );
    Assert.isTrue(
      RecordHealthCheckTokenRegistry.contains('record', 'Name'),
      'The established record Name property must remain registered.'
    );
    Assert.isFalse(
      RecordHealthCheckTokenRegistry.contains('rhcResult', 'sourceRows[1].Id'),
      'Row syntax belongs to rhcQuery alone.'
    );
    Assert.isFalse(
      RecordHealthCheckTokenRegistry.resolve('rhcResult', 'foundValue')
        .isTypedField,
      'A result value is finished text and can no longer be formatted.'
    );
    Assert.isTrue(
      RecordHealthCheckTokenRegistry.resolve('record', 'Amount').isTypedField,
      'A record field keeps its Salesforce data type.'
    );
  }
}
