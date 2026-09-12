/** Verifies repeated cross-object cache use and explicit cache reset. */
@IsTest
private class RHCDescribeCacheStressTest {
  /**
   * Stress the cache the way field planning does: many same-named fields across
   * several objects in one transaction, interleaved, then re-check each one.
   */
  @IsTest
  static void interleavedCrossObjectRoundTripKeepsDistinctDescribes() {
    RecordHealthCheckDescribeCache.clearForTest();

    List<Schema.SObjectType> objectTypes = new List<Schema.SObjectType>{
      Account.SObjectType,
      Contact.SObjectType,
      Opportunity.SObjectType,
      Case.SObjectType,
      Lead.SObjectType
    };
    List<String> commonFields = new List<String>{
      'Name',
      'Id',
      'CreatedDate',
      'LastModifiedDate',
      'OwnerId'
    };

    Map<String, String> expectedLabelByObjectAndField = new Map<String, String>();
    Integer described = 0;

    // First pass: describe every common field on every object (interleaved by field).
    for (String fieldName : commonFields) {
      for (Schema.SObjectType objectType : objectTypes) {
        Map<String, Schema.SObjectField> fields = RecordHealthCheckDescribeCache.fieldMap(
          objectType
        );
        Schema.SObjectField token = fields.get(fieldName.toLowerCase());
        if (token == null) {
          continue;
        }
        Schema.DescribeFieldResult description = RecordHealthCheckDescribeCache.describeField(
          token
        );
        String cacheKey =
          String.valueOf(objectType) +
          '.' +
          fieldName.toLowerCase();
        expectedLabelByObjectAndField.put(cacheKey, description.getLabel());
        described++;
      }
    }
    Assert.isTrue(
      described >= 20,
      'Expected a broad cross-object describe set; got ' + described
    );

    // Second pass: every cached entry must still match the label captured for
    // that object+field — not a sibling object's same-named field.
    Integer verified = 0;
    for (String fieldName : commonFields) {
      for (Schema.SObjectType objectType : objectTypes) {
        Map<String, Schema.SObjectField> fields = RecordHealthCheckDescribeCache.fieldMap(
          objectType
        );
        Schema.SObjectField token = fields.get(fieldName.toLowerCase());
        if (token == null) {
          continue;
        }
        String cacheKey =
          String.valueOf(objectType) +
          '.' +
          fieldName.toLowerCase();
        Assert.areEqual(
          expectedLabelByObjectAndField.get(cacheKey),
          RecordHealthCheckDescribeCache.describeField(token).getLabel(),
          'Round-trip mismatch for ' + cacheKey
        );
        verified++;
      }
    }
    Assert.areEqual(
      described,
      verified,
      'The second cache pass must verify every entry described in the first pass.'
    );

    // Spot-check the original collision pair after the stress pass.
    Assert.areEqual(
      'Account Name',
      RecordHealthCheckDescribeCache.describeField(Account.Name).getLabel(),
      'Cross-object stress must preserve the original Account Name label.'
    );
    Assert.areEqual(
      'Full Name',
      RecordHealthCheckDescribeCache.describeField(Contact.Name).getLabel(),
      'Cross-object stress must preserve the original Contact Name label.'
    );
  }

  @IsTest
  static void clearForTestDropsFieldCacheSoNextDescribeIsFresh() {
    RecordHealthCheckDescribeCache.clearForTest();
    Schema.DescribeFieldResult beforeClear = RecordHealthCheckDescribeCache.describeField(
      Account.Name
    );
    Assert.areEqual(
      'Account Name',
      beforeClear.getLabel(),
      'The cache-reset fixture must first contain the Account Name description.'
    );

    RecordHealthCheckDescribeCache.clearForTest();
    Schema.DescribeFieldResult afterClear = RecordHealthCheckDescribeCache.describeField(
      Contact.Name
    );
    Assert.areEqual(
      'Full Name',
      afterClear.getLabel(),
      'After clear, Contact.Name must not inherit a stale Account.Name entry'
    );
    Assert.areEqual(
      'Account Name',
      RecordHealthCheckDescribeCache.describeField(Account.Name).getLabel(),
      'After reset and Contact lookup, Account must still receive its own label.'
    );
  }
}
