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
      'sourceRows[1].Name'
    );
    Assert.isTrue(source.isUsable(), 'A well-formed row token resolves.');
    Assert.areEqual(
      RecordHealthCheckTokenShape.KIND_QUERY_ROW_FIELD,
      source.kind
    );
    Assert.areEqual('sourceRows', source.collection);
    Assert.areEqual(1, source.rowIndex, 'Indexes are one-based.');
    Assert.areEqual('Name', source.fieldPath);
    Assert.isTrue(
      source.isTypedField,
      'A query row field still has a Salesforce data type.'
    );
    Assert.isFalse(source.readsComparisonQuery());

    RecordHealthCheckTokenShape comparison = RecordHealthCheckTokenRegistry.resolve(
      'rhcQuery',
      'comparisonRows[4].Owner.Name'
    );
    Assert.isTrue(comparison.readsComparisonQuery());
    Assert.areEqual(4, comparison.rowIndex);
    Assert.areEqual('Owner.Name', comparison.fieldPath);

    RecordHealthCheckTokenShape count = RecordHealthCheckTokenRegistry.resolve(
      'rhcQuery',
      'sourceRowCount'
    );
    Assert.areEqual(
      RecordHealthCheckTokenShape.KIND_QUERY_ROW_COUNT,
      count.kind
    );
    Assert.isFalse(
      count.isTypedField,
      'A count is a whole number the Framework already renders.'
    );
  }

  @IsTest
  static void rejectsEveryIndexThatIsNotAPositiveWholeNumber() {
    for (
      String property : new List<String>{
        'sourceRows[0].Id',
        'sourceRows[-1].Id',
        'sourceRows[1.5].Id',
        'sourceRows[i].Id',
        'sourceRows[1+1].Id',
        'sourceRows[*].Id',
        'sourceRows[1:3].Id',
        'sourceRows[+1].Id',
        'sourceRows[01].Id',
        'sourceRows[].Id',
        'sourceRows[ ].Id',
        'sourceRows[2001].Id',
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
      RecordHealthCheckTokenRegistry.resolve('rhcQuery', 'sourceRows[2000].Id')
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
    Assert.areEqual('UNKNOWN_TOKEN_PROPERTY', shape.reasonCode);
    Assert.isTrue(
      shape.message.contains('sourceRows[1].Field'),
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
      RecordHealthCheckTokenRegistry.contains('rhcResult', 'foundValue')
    );
    Assert.isTrue(RecordHealthCheckTokenRegistry.contains('record', 'Name'));
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
