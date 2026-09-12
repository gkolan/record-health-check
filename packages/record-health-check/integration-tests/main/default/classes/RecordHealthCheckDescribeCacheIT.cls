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
      RecordHealthCheckDescribeCache.containsObject('Account'),
      'The first known-object lookup must populate a usable global describe cache.'
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
    Assert.areEqual(
      first.getName(),
      second.getName(),
      'Repeated object descriptions must preserve the same object identity.'
    );
    Assert.areEqual(
      first.fields.getMap().size(),
      RecordHealthCheckDescribeCache.fieldMap(Account.SObjectType).size(),
      'The cached field map must contain every described Account field.'
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
    Assert.areEqual(
      fieldFirst.getName(),
      fieldSecond.getName(),
      'Repeated field descriptions must preserve the same field identity.'
    );
    Assert.areEqual(
      'Account',
      RecordHealthCheckDescribeCache.objectApiName(Account.SObjectType),
      'Object-token lookup must return the canonical Account API name.'
    );
  }

  @IsTest
  static void nullAndUnknownInputsAreSafe() {
    RecordHealthCheckDescribeCache.clearForTest();

    Assert.areEqual(
      false,
      RecordHealthCheckDescribeCache.containsObject(null),
      'A null object name must not resolve to an existing object.'
    );
    Assert.areEqual(
      false,
      RecordHealthCheckDescribeCache.containsObject('Not_A_Real_Object__x'),
      'An unknown object name must not create a false cache hit.'
    );
    Assert.areEqual(
      null,
      RecordHealthCheckDescribeCache.objectApiName((Id) null),
      'A null record identity must not resolve an object API name.'
    );
    Assert.areEqual(
      null,
      RecordHealthCheckDescribeCache.describeSObject(null),
      'A null object token must not produce a describe result.'
    );
    Assert.areEqual(
      0,
      RecordHealthCheckDescribeCache.fieldMap(null).size(),
      'A null object token must produce an empty field map.'
    );
    Assert.areEqual(
      null,
      RecordHealthCheckDescribeCache.describeField(null),
      'A null field token must not produce a field description.'
    );
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
      RecordHealthCheckDescribeCache.objectApiName(accountRecord.Id),
      'A saved Account identity must resolve its object through the describe cache.'
    );
  }

  @IsTest
  static void resolveSObjectTypeReturnsTokenForKnownObject() {
    RecordHealthCheckDescribeCache.clearForTest();

    Assert.areNotEqual(
      null,
      RecordHealthCheckDescribeCache.resolveSObjectType('account'),
      'Lowercase object names must resolve a real schema token.'
    );
    Assert.areEqual(
      Account.SObjectType,
      RecordHealthCheckDescribeCache.resolveSObjectType('Account'),
      'Canonical object names must resolve the matching schema token.'
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
    Assert.areEqual(
      'Name',
      String.valueOf(Account.Name),
      'The collision fixture must exercise the unqualified Name token.'
    );

    Schema.DescribeFieldResult accountName = RecordHealthCheckDescribeCache.describeField(
      Account.Name
    );
    Schema.DescribeFieldResult contactName = RecordHealthCheckDescribeCache.describeField(
      Contact.Name
    );

    Assert.areEqual(
      'Name',
      accountName.getName(),
      'Cached Account.Name must retain its own field identity.'
    );
    Assert.areEqual(
      'Name',
      contactName.getName(),
      'Cached Contact.Name must retain its own field identity.'
    );
    Assert.areNotEqual(
      accountName.getLabel(),
      contactName.getLabel(),
      'Account.Name and Contact.Name must keep distinct labels after both are cached'
    );
    Assert.areEqual(
      'Account Name',
      accountName.getLabel(),
      'Account.Name must retain the Account-specific label.'
    );
    Assert.areEqual(
      'Full Name',
      contactName.getLabel(),
      'Contact.Name must retain the Contact-specific label.'
    );

    // Re-fetch Account.Name after Contact.Name was cached — must still be Account.
    Schema.DescribeFieldResult accountNameAgain = RecordHealthCheckDescribeCache.describeField(
      Account.Name
    );
    Assert.areEqual(
      'Account Name',
      accountNameAgain.getLabel(),
      'A later Contact lookup must not replace the cached Account label.'
    );
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

    Assert.areEqual(
      'OwnerId',
      accountOwner.getName(),
      'Account ownership metadata must retain its OwnerId field identity.'
    );
    Assert.areEqual(
      'OwnerId',
      caseOwner.getName(),
      'Case ownership metadata must retain its OwnerId field identity.'
    );
    Assert.areEqual(
      false,
      accountOwner.getReferenceTo().isEmpty(),
      'Account ownership metadata must retain its reference targets.'
    );
    Assert.areEqual(
      false,
      caseOwner.getReferenceTo().isEmpty(),
      'Case ownership metadata must retain its reference targets.'
    );
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
        .size(),
      'Interleaved Case lookup must not alter the Account reference target count.'
    );
    Assert.areEqual(
      caseOwner.getReferenceTo().size(),
      RecordHealthCheckDescribeCache.describeField(Case.OwnerId)
        .getReferenceTo()
        .size(),
      'Interleaved Account lookup must not alter the Case reference target count.'
    );

    // ParentId / AccountId exercise the same cache path used when walking
    // relationships across objects in one transaction.
    Schema.DescribeFieldResult accountParent = RecordHealthCheckDescribeCache.describeField(
      Account.ParentId
    );
    Schema.DescribeFieldResult contactAccount = RecordHealthCheckDescribeCache.describeField(
      Contact.AccountId
    );
    Assert.areEqual(
      Account.SObjectType,
      accountParent.getReferenceTo()[0],
      'The Account parent relationship must still point to Account.'
    );
    Assert.areEqual(
      Account.SObjectType,
      contactAccount.getReferenceTo()[0],
      'The Contact account relationship must still point to Account.'
    );
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

    Assert.areNotEqual(
      null,
      accountNameFromMap,
      'The runtime Account field map must expose its Name token.'
    );
    Assert.areNotEqual(
      null,
      contactNameFromMap,
      'The runtime Contact field map must expose its Name token.'
    );
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
    Assert.areEqual(
      'Account Name',
      fromAccountMap.getLabel(),
      'Runtime Account tokens must retain Account-specific labels.'
    );
    Assert.areEqual(
      'Full Name',
      fromContactMap.getLabel(),
      'Runtime Contact tokens must retain Contact-specific labels.'
    );

    // Compile-time token and field-map token for the same field must share one
    // cache entry (same Map key), not silently double-describe under two keys.
    Schema.DescribeFieldResult fromCompileTime = RecordHealthCheckDescribeCache.describeField(
      Account.Name
    );
    Assert.areEqual(
      fromAccountMap.getLabel(),
      fromCompileTime.getLabel(),
      'Runtime and compile-time tokens must share the same field description.'
    );
    Assert.areEqual(
      accountNameFromMap,
      Account.Name,
      'fieldMap Name token must equal the compile-time Account.Name token'
    );
  }
}
