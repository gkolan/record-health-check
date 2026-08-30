/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckDescribeCacheIT {
  @IsTest
  static void resolvesUniquelyNamespacedFieldFromUnqualifiedApiName() {
    Schema.SObjectField field = RecordHealthCheckDescribeCache.resolveField(
      Record_Health_Check_Set__mdt.SObjectType,
      'FoundExpectedDisplay__c'
    );

    Assert.isNotNull(
      field,
      'Framework Custom Metadata fields should resolve in namespaced and unpackaged orgs.'
    );
    Assert.areEqual(
      Schema.DisplayType.PICKLIST,
      RecordHealthCheckDescribeCache.describeField(field).getType(),
      'The resolved field should preserve its describe metadata.'
    );
  }

  @IsTest
  static void rejectsAmbiguousNamespacedFieldSuffix() {
    Assert.isNull(
      RecordHealthCheckDescribeCache.resolveField(
        Record_Health_Check__mdt.SObjectType,
        'c'
      ),
      'A suffix shared by multiple Custom Metadata fields must not resolve ambiguously.'
    );
  }

  @IsTest
  static void cachesObjectAndFieldDescribeAcrossRepeatedCalls() {
    RecordHealthCheckDescribeCache.clearForTest();

    Assert.areEqual(
      true,
      RecordHealthCheckDescribeCache.containsObject('Account')
    );
    Assert.areEqual(
      true,
      RecordHealthCheckDescribeCache.containsObject('account'),
      'Object lookup should be case-insensitive against the cached global describe'
    );
    Assert.areEqual(
      true,
      RecordHealthCheckDescribeCache.containsObject('Account'),
      'Second global-describe lookup should reuse the cache'
    );

    Schema.DescribeSObjectResult first = RecordHealthCheckDescribeCache.describeSObject(
      Account.SObjectType
    );
    Schema.DescribeSObjectResult second = RecordHealthCheckDescribeCache.describeSObject(
      Account.SObjectType
    );
    Assert.areEqual(first.getName(), second.getName());
    Assert.areEqual(
      first.fields.getMap().size(),
      RecordHealthCheckDescribeCache.fieldMap(Account.SObjectType).size()
    );

    Schema.SObjectField billingCity = RecordHealthCheckDescribeCache.fieldMap(
        Account.SObjectType
      )
      .get('billingcity');
    Schema.DescribeFieldResult fieldFirst = RecordHealthCheckDescribeCache.describeField(
      billingCity
    );
    Schema.DescribeFieldResult fieldSecond = RecordHealthCheckDescribeCache.describeField(
      billingCity
    );
    Assert.areEqual(fieldFirst.getName(), fieldSecond.getName());
    Assert.areEqual(
      'Account',
      RecordHealthCheckDescribeCache.objectApiName(Account.SObjectType)
    );
  }

  @IsTest
  static void nullAndUnknownInputsAreSafe() {
    RecordHealthCheckDescribeCache.clearForTest();

    Assert.areEqual(false, RecordHealthCheckDescribeCache.containsObject(null));
    Assert.areEqual(
      false,
      RecordHealthCheckDescribeCache.containsObject('Not_A_Real_Object__x')
    );
    Assert.areEqual(
      null,
      RecordHealthCheckDescribeCache.objectApiName((Id) null)
    );
    Assert.areEqual(null, RecordHealthCheckDescribeCache.describeSObject(null));
    Assert.areEqual(0, RecordHealthCheckDescribeCache.fieldMap(null).size());
    Assert.areEqual(null, RecordHealthCheckDescribeCache.describeField(null));
    Assert.isNull(
      RecordHealthCheckDescribeCache.resolveField(null, 'Name'),
      'A field cannot resolve without an object type.'
    );
    Assert.isNull(
      RecordHealthCheckDescribeCache.resolveField(Account.SObjectType, ' '),
      'A blank field API name cannot resolve.'
    );
  }

  @IsTest
  static void objectApiNameFromRecordIdUsesCachedDescribe() {
    RecordHealthCheckDescribeCache.clearForTest();
    Account accountRecord = RHCIntegrationTestDataFactory.createAccount(
      'Cache Test Account'
    );

    Assert.areEqual(
      'Account',
      RecordHealthCheckDescribeCache.objectApiName(accountRecord.Id)
    );
  }

  @IsTest
  static void resolveSObjectTypeReturnsTokenForKnownObject() {
    RecordHealthCheckDescribeCache.clearForTest();

    Assert.areNotEqual(
      null,
      RecordHealthCheckDescribeCache.resolveSObjectType('account')
    );
    Assert.areEqual(
      Account.SObjectType,
      RecordHealthCheckDescribeCache.resolveSObjectType('Account')
    );
  }

  /**
   * Regression: the old cache keyed on String.valueOf(field), which returns the
   * unqualified API name. Account.Name and Contact.Name both stringify to "Name",
   * so the second describe would return the first object's metadata (wrong label,
   * type, and isAccessible()). Keying on the Schema.SObjectField token must keep
   * those describes distinct across the whole transaction.
   */
  @IsTest
  static void sameNamedFieldsOnDifferentObjectsDoNotCollide() {
    RecordHealthCheckDescribeCache.clearForTest();

    // Prove the old key would have collided — if this ever stops being true the
    // regression below is no longer testing the original failure mode.
    Assert.areEqual(
      String.valueOf(Account.Name),
      String.valueOf(Contact.Name),
      'Precondition: String.valueOf collapses both tokens to the same unqualified name'
    );
    Assert.areEqual('Name', String.valueOf(Account.Name));

    Schema.DescribeFieldResult accountName = RecordHealthCheckDescribeCache.describeField(
      Account.Name
    );
    Schema.DescribeFieldResult contactName = RecordHealthCheckDescribeCache.describeField(
      Contact.Name
    );

    Assert.areEqual('Name', accountName.getName());
    Assert.areEqual('Name', contactName.getName());
    Assert.areNotEqual(
      accountName.getLabel(),
      contactName.getLabel(),
      'Account.Name and Contact.Name must keep distinct labels after both are cached'
    );
    Assert.areEqual('Account Name', accountName.getLabel());
    Assert.areEqual('Full Name', contactName.getLabel());

    // Re-fetch Account.Name after Contact.Name was cached — must still be Account.
    Schema.DescribeFieldResult accountNameAgain = RecordHealthCheckDescribeCache.describeField(
      Account.Name
    );
    Assert.areEqual('Account Name', accountNameAgain.getLabel());
    Assert.areEqual(
      accountName.getLabel(),
      accountNameAgain.getLabel(),
      'Cached Account.Name describe must be stable across later same-named lookups'
    );
  }

  /**
   * Same unqualified name, different objects — the collision would also return the wrong
   * getReferenceTo() used by relationship traversal. Assert each cached describe
   * stays tied to its own field token (do not assume OwnerId's first reference
   * target is identical across objects: Case.OwnerId can include Group/queues).
   */
  @IsTest
  static void sameNamedLookupsKeepDistinctReferenceTargets() {
    RecordHealthCheckDescribeCache.clearForTest();

    Assert.areEqual(
      String.valueOf(Account.OwnerId),
      String.valueOf(Case.OwnerId),
      'Precondition: OwnerId stringifies identically across objects'
    );

    Schema.DescribeFieldResult accountOwner = RecordHealthCheckDescribeCache.describeField(
      Account.OwnerId
    );
    Schema.DescribeFieldResult caseOwner = RecordHealthCheckDescribeCache.describeField(
      Case.OwnerId
    );

    Assert.areEqual('OwnerId', accountOwner.getName());
    Assert.areEqual('OwnerId', caseOwner.getName());
    Assert.areEqual(false, accountOwner.getReferenceTo().isEmpty());
    Assert.areEqual(false, caseOwner.getReferenceTo().isEmpty());
    Assert.areEqual(
      true,
      accountOwner.getReferenceTo().contains(User.SObjectType),
      'Account.OwnerId must reference User'
    );
    Assert.areEqual(
      true,
      caseOwner.getReferenceTo().contains(User.SObjectType),
      'Case.OwnerId must still reference User (may also reference Group)'
    );

    // Re-fetch after both are cached — each token must keep its own reference list.
    Assert.areEqual(
      accountOwner.getReferenceTo().size(),
      RecordHealthCheckDescribeCache.describeField(Account.OwnerId)
        .getReferenceTo()
        .size()
    );
    Assert.areEqual(
      caseOwner.getReferenceTo().size(),
      RecordHealthCheckDescribeCache.describeField(Case.OwnerId)
        .getReferenceTo()
        .size()
    );

    // ParentId / AccountId exercise the same cache path used when walking
    // relationships across objects in one transaction.
    Schema.DescribeFieldResult accountParent = RecordHealthCheckDescribeCache.describeField(
      Account.ParentId
    );
    Schema.DescribeFieldResult contactAccount = RecordHealthCheckDescribeCache.describeField(
      Contact.AccountId
    );
    Assert.areEqual(Account.SObjectType, accountParent.getReferenceTo()[0]);
    Assert.areEqual(Account.SObjectType, contactAccount.getReferenceTo()[0]);
  }

  /**
   * Tokens acquired from fields.getMap() (runtime path used by the engine) must
   * not collide with each other across objects, and must agree with compile-time
   * tokens for the same field so the cache is shared rather than duplicated.
   */
  @IsTest
  static void fieldMapTokensDoNotCollideAcrossObjects() {
    RecordHealthCheckDescribeCache.clearForTest();

    Schema.SObjectField accountNameFromMap = RecordHealthCheckDescribeCache.fieldMap(
        Account.SObjectType
      )
      .get('name');
    Schema.SObjectField contactNameFromMap = RecordHealthCheckDescribeCache.fieldMap(
        Contact.SObjectType
      )
      .get('name');

    Assert.areNotEqual(null, accountNameFromMap);
    Assert.areNotEqual(null, contactNameFromMap);
    Assert.areEqual(
      String.valueOf(accountNameFromMap),
      String.valueOf(contactNameFromMap),
      'Precondition: field-map tokens also stringify to the same unqualified name'
    );

    Schema.DescribeFieldResult fromAccountMap = RecordHealthCheckDescribeCache.describeField(
      accountNameFromMap
    );
    Schema.DescribeFieldResult fromContactMap = RecordHealthCheckDescribeCache.describeField(
      contactNameFromMap
    );
    Assert.areEqual('Account Name', fromAccountMap.getLabel());
    Assert.areEqual('Full Name', fromContactMap.getLabel());

    // Compile-time token and field-map token for the same field must share one
    // cache entry (same Map key), not silently double-describe under two keys.
    Schema.DescribeFieldResult fromCompileTime = RecordHealthCheckDescribeCache.describeField(
      Account.Name
    );
    Assert.areEqual(fromAccountMap.getLabel(), fromCompileTime.getLabel());
    Assert.areEqual(
      accountNameFromMap,
      Account.Name,
      'fieldMap Name token must equal the compile-time Account.Name token'
    );
  }

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
    Assert.areEqual(described, verified);

    // Spot-check the original collision pair after the stress pass.
    Assert.areEqual(
      'Account Name',
      RecordHealthCheckDescribeCache.describeField(Account.Name).getLabel()
    );
    Assert.areEqual(
      'Full Name',
      RecordHealthCheckDescribeCache.describeField(Contact.Name).getLabel()
    );
  }

  @IsTest
  static void clearForTestDropsFieldCacheSoNextDescribeIsFresh() {
    RecordHealthCheckDescribeCache.clearForTest();
    Schema.DescribeFieldResult beforeClear = RecordHealthCheckDescribeCache.describeField(
      Account.Name
    );
    Assert.areEqual('Account Name', beforeClear.getLabel());

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
      RecordHealthCheckDescribeCache.describeField(Account.Name).getLabel()
    );
  }
}
