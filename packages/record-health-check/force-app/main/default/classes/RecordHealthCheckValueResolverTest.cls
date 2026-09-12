/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Unit tests for RecordHealthCheckValueResolver. Pure in-memory logic — no DML.
 * Focuses on consolidated behavior the evaluators share: native Date comparison
 * (never converted to midnight DateTime) and relationship-path extraction with
 * missing-field classification.
 */
@IsTest
private class RecordHealthCheckValueResolverTest {
  // ─── Extraction ────────────────────────────────────────────────────────────

  @IsTest
  static void singleValueFromRowReadsSimpleField() {
    Account a = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Acme' }
    );
    Assert.areEqual(
      'Acme',
      RecordHealthCheckValueResolver.singleValueFromRow(a, 'Name'),
      'A direct field must return its stored value.'
    );
  }

  @IsTest
  static void singleValueFromRowReadsAliasedAndUnaliasedAggregates() {
    AggregateResult aliased = [SELECT COUNT(Id) total FROM Account];
    AggregateResult unaliased = [SELECT COUNT(Id) FROM Account];
    Assert.areEqual(
      aliased.get('total'),
      RecordHealthCheckValueResolver.singleValueFromRow(aliased, null),
      'A sole explicitly aliased aggregate must resolve without a requested alias.'
    );
    Assert.areEqual(
      unaliased.get('expr0'),
      RecordHealthCheckValueResolver.singleValueFromRow(unaliased, null),
      'A sole implicit aggregate must resolve through its generated alias.'
    );
    Assert.areEqual(
      aliased.get('total'),
      RecordHealthCheckValueResolver.singleValueFromRow(aliased, 'total'),
      'An explicit requested aggregate alias must return that measure.'
    );
  }

  @IsTest
  static void multipleAggregatesRequireAnExplicitFieldAlias() {
    AggregateResult multiple = [
      SELECT COUNT(Id) recordCount, MAX(CreatedDate) newestRecord
      FROM Account
    ];

    Test.startTest();
    try {
      RecordHealthCheckValueResolver.singleValueFromRow(multiple, null);
      Assert.fail(
        'Multiple aggregate values must not use map iteration order.'
      );
    } catch (RecordHealthCheckValueResolver.ResolverException error) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        error.reasonCode,
        'Ambiguous aggregate selection must be classified as invalid configuration.'
      );
      Assert.isTrue(
        error.getMessage().contains('query field alias is required'),
        'The failure must tell the author how to select the intended measure.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void singleValueFromRowTraversesRelationshipPath() {
    // Build a nested SObject in memory via JSON so getSObject('Parent') resolves.
    Account a = (Account) JSON.deserialize(
      '{"attributes":{"type":"Account"},"Name":"Child","Parent":{"attributes":{"type":"Account"},"Name":"ParentCo"}}',
      Account.class
    );
    Assert.areEqual(
      'ParentCo',
      RecordHealthCheckValueResolver.singleValueFromRow(a, 'Parent.Name'),
      'Relationship traversal must return the related record field.'
    );
  }

  @IsTest
  static void singleValueFromRowNullRelationshipYieldsNull() {
    Account a = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Child' }
    );
    Assert.areEqual(
      null,
      RecordHealthCheckValueResolver.singleValueFromRow(a, 'Parent.Name'),
      'An absent parent relationship must yield null rather than a template error.'
    );
  }

  @IsTest
  static void singleValueFromRowMissingFieldThrowsInvalidTemplate() {
    Account a = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Acme' }
    );
    try {
      RecordHealthCheckValueResolver.singleValueFromRow(a, 'Not_A_Field__c');
      Assert.isTrue(false, 'Expected ResolverException.');
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'A nonexistent field must expose the stable invalid-template reason.'
      );
    }
  }

  // ─── Equality ──────────────────────────────────────────────────────────────

  @IsTest
  static void valuesEqualNumericAcrossTypes() {
    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.valuesEqual(1, 1.0),
      'Equal numeric magnitudes must compare equal across numeric types.'
    );
    Assert.areEqual(
      false,
      RecordHealthCheckValueResolver.valuesEqual(1, 2),
      'Different numeric magnitudes must not compare equal.'
    );
  }

  @IsTest
  static void valuesEqualNullSafe() {
    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.valuesEqual(null, null),
      'Two absent operands must compare equal.'
    );
    Assert.areEqual(
      false,
      RecordHealthCheckValueResolver.valuesEqual(null, 'x'),
      'An absent operand must differ from present text.'
    );
  }

  @IsTest
  static void valuesEqualDates() {
    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.valuesEqual(
        Date.newInstance(2026, 1, 1),
        Date.newInstance(2026, 1, 1)
      ),
      'Equal native Dates must compare equal without timezone conversion.'
    );
  }

  @IsTest
  static void valuesEqualDateStringsAndInvalidIds() {
    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.valuesEqual(
        Date.newInstance(2026, 1, 1),
        '2026-01-01 00:00:00'
      ),
      'Date equality should parse comparable string values.'
    );
    assertIncompatibleEquality(Date.newInstance(2026, 1, 1), 'not-a-date');

    Id accountId =
      Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
        .getKeyPrefix() + '000000000000';
    Assert.areEqual(
      false,
      RecordHealthCheckValueResolver.valuesEqual(accountId, 'not-an-id'),
      'An Id compared to an unparseable Id string should be false, not an exception.'
    );
  }

  // ─── Ordered comparison ────────────────────────────────────────────────────

  @IsTest
  static void orderedNumeric() {
    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.applyOrdered('GREATER_THAN', 5, 3),
      'A larger numeric Found operand must satisfy GREATER_THAN.'
    );
    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.applyOrdered('LESS_THAN_OR_EQUAL', 3, 3),
      'Equal numeric operands must satisfy the inclusive lower comparison.'
    );
  }

  @IsTest
  static void orderedNativeDateUsesDateLadderNotMidnightDateTime() {
    // L6: two native Dates must compare as Dates.
    Date earlier = Date.newInstance(2026, 1, 1);
    Date later = Date.newInstance(2026, 6, 19);
    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.applyOrdered('LESS_THAN', earlier, later),
      'An earlier native Date must satisfy LESS_THAN.'
    );
    Assert.areEqual(
      false,
      RecordHealthCheckValueResolver.applyOrdered(
        'GREATER_THAN',
        earlier,
        later
      ),
      'An earlier native Date must not satisfy GREATER_THAN.'
    );
  }

  @IsTest
  static void orderedDateTime() {
    Datetime earlier = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0);
    Datetime later = Datetime.newInstanceGmt(2026, 1, 1, 10, 0, 0);
    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.applyOrdered('LESS_THAN', earlier, later),
      'The earlier UTC instant must satisfy LESS_THAN in every user timezone.'
    );
  }

  @IsTest
  static void orderedDateTimeCoversInclusiveInvalidAndUtcTextPaths() {
    Datetime instant = Datetime.newInstanceGmt(2026, 1, 1, 10, 0, 0);
    Assert.isTrue(
      RecordHealthCheckValueResolver.applyOrdered(
        'GREATER_THAN_OR_EQUAL',
        instant,
        instant
      ),
      'Equal Datetimes satisfy the inclusive comparison.'
    );
    Assert.isTrue(
      RecordHealthCheckValueResolver.applyOrdered(
        'LESS_THAN',
        '2026-01-01T10:00:00Z',
        '2026-01-01T11:00:00Z'
      ),
      'UTC ISO text is normalized as GMT before comparison.'
    );
    try {
      RecordHealthCheckValueResolver.applyOrdered(
        'NOT_ORDERED',
        instant,
        instant
      );
      Assert.fail('An invalid Datetime operator must be rejected.');
    } catch (RecordHealthCheckValueResolver.ResolverException error) {
      Assert.areEqual(
        'INCOMPATIBLE_COMPARISON_TYPES',
        error.reasonCode,
        'The public ladder must not fall back to string ordering.'
      );
    }
  }

  @IsTest
  static void orderedIncompatibleTypesThrows() {
    try {
      RecordHealthCheckValueResolver.applyOrdered(
        'GREATER_THAN',
        'not-a-number',
        'also-not'
      );
      Assert.isTrue(false, 'Expected INCOMPATIBLE_COMPARISON_TYPES.');
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      Assert.areEqual(
        'INCOMPATIBLE_COMPARISON_TYPES',
        ex.reasonCode,
        'Unorderable text operands must expose incompatible types.'
      );
    }
  }

  // ─── Misc ──────────────────────────────────────────────────────────────────

  @IsTest
  static void isNumericObjectClassifies() {
    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.isNumericObject(5),
      'An Integer must be classified as a numeric object.'
    );
    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.isNumericObject(5.0),
      'A Decimal must be classified as a numeric object.'
    );
    Assert.areEqual(
      false,
      RecordHealthCheckValueResolver.isNumericObject('5'),
      'Numeric-looking text must remain a String rather than a numeric object.'
    );
  }

  @IsTest
  static void classifyQueryExceptionDistinguishesAccess() {
    Assert.areEqual(
      'INVALID_SOQL_TEMPLATE',
      RecordHealthCheckValueResolver.classifyQueryException(
        new TestQueryException('malformed query')
      ),
      'A malformed query must retain the invalid-template classification.'
    );
    Assert.areEqual(
      'INVALID_SOQL_TEMPLATE',
      RecordHealthCheckValueResolver.classifyQueryException(
        new TestQueryException('insufficient access rights on field')
      ),
      'English message text must not determine access classification.'
    );
  }

  @IsTest
  static void remainingTypedBranchesAreCovered() {
    Datetime earlier = Datetime.newInstance(2026, 1, 1, 0, 0, 0);
    Date earlierDate = Date.newInstance(2026, 1, 1);

    Assert.isTrue(
      RecordHealthCheckValueResolver.valuesEqual(
        earlier,
        '2026-01-01 00:00:00'
      ),
      'A local Datetime must equal matching local date-time text.'
    );
    assertIncompatibleEquality(earlier, 'not-a-datetime');
    assertIncompatibleEquality(earlierDate, 'not-a-date');

    try {
      RecordHealthCheckValueResolver.applyOrdered('Nope', 1, 1);
      Assert.isTrue(false, 'Expected an invalid ordered operator.');
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      Assert.areEqual(
        'INVALID_OPERATOR',
        ex.reasonCode,
        'An unknown numeric comparison operator must expose INVALID_OPERATOR.'
      );
    }
  }

  private static void assertIncompatibleEquality(Object left, Object right) {
    try {
      RecordHealthCheckValueResolver.valuesEqual(left, right);
      Assert.isTrue(false, 'Expected incompatible equality operands.');
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      Assert.areEqual(
        'INCOMPATIBLE_COMPARISON_TYPES',
        ex.reasonCode,
        'Unparseable typed equality operands must expose incompatible types.'
      );
    }
  }

  // Lets us construct a QueryException with a controlled message.
  private class TestQueryException extends Exception {
  }

  @IsTest
  static void singleValueFromRowIgnoresBulkCorrelationAlias() {
    AggregateResult grouped = [
      SELECT ProfileId rhcCorrelation, COUNT(Id) total
      FROM User
      WHERE Id = :UserInfo.getUserId()
      GROUP BY ProfileId
    ];
    Assert.areEqual(
      grouped.get('total'),
      RecordHealthCheckValueResolver.singleValueFromRow(grouped, null),
      'Bulk correlation metadata must not be mistaken for the aggregate measure.'
    );
  }
}
