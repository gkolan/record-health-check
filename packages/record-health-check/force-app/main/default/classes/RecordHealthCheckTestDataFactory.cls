/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
public class RecordHealthCheckTestDataFactory {
  public static final String HEALTHY_ACCOUNT_NAME_PREFIX = 'Record Health Test Account';

  public static Account account(Map<String, Object> fields) {
    return (Account) buildRecord(Account.SObjectType, fields);
  }

  public static Lead lead(Map<String, Object> fields) {
    return (Lead) buildRecord(Lead.SObjectType, fields);
  }

  public static Contact contact(Map<String, Object> fields) {
    return (Contact) buildRecord(Contact.SObjectType, fields);
  }

  public static Opportunity opportunity(Map<String, Object> fields) {
    return (Opportunity) buildRecord(Opportunity.SObjectType, fields);
  }

  public static Task task(Map<String, Object> fields) {
    return (Task) buildRecord(Task.SObjectType, fields);
  }

  public static Event event(Map<String, Object> fields) {
    return (Event) buildRecord(Event.SObjectType, fields);
  }

  public static Case caseRecord(Map<String, Object> fields) {
    return (Case) buildRecord(Case.SObjectType, fields);
  }

  public static User user(Map<String, Object> fields) {
    return (User) buildRecord(User.SObjectType, fields);
  }

  public static Record_Health_Check__mdt check(Map<String, Object> fields) {
    return (Record_Health_Check__mdt) buildRecord(
      Record_Health_Check__mdt.SObjectType,
      fields
    );
  }

  public static Record_Health_Check_Set__mdt checkSet(
    Map<String, Object> fields
  ) {
    return (Record_Health_Check_Set__mdt) buildRecord(
      Record_Health_Check_Set__mdt.SObjectType,
      fields
    );
  }

  public static User currentUser() {
    return RecordHealthCheckPersonaTestDataFactory.currentUser();
  }

  /** Assigns a packaged permission set to a test user. */
  public static void assignPermissionSet(
    User userRecord,
    String permissionSetName
  ) {
    PermissionSet permissionSet = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = :permissionSetName
      LIMIT 1
    ];
    List<PermissionSetAssignment> existingAssignments = [
      SELECT Id
      FROM PermissionSetAssignment
      WHERE AssigneeId = :userRecord.Id AND PermissionSetId = :permissionSet.Id
      LIMIT 1
    ];
    if (!existingAssignments.isEmpty()) {
      return;
    }
    System.runAs(currentUser()) {
      insert new PermissionSetAssignment(
        AssigneeId = userRecord.Id,
        PermissionSetId = permissionSet.Id
      );
    }
  }

  /** Assigns the packaged runner entitlement to the current test user. */
  public static void assignRunPermissionToCurrentUser() {
    assignPermissionSet(
      currentUser(),
      RecordHealthCheckSchemaTestDataFactory.runnerPermissionSetName()
    );
  }

  /** Creates a uniquely named inactive user for permission and ownership tests. */
  public static User createInactiveUser(String firstName, String lastName) {
    return RecordHealthCheckPersonaTestDataFactory.createInactiveUser(
      firstName,
      lastName
    );
  }

  public static Id syntheticId(
    Schema.SObjectType objectType,
    Integer sequence
  ) {
    String suffix = String.valueOf(sequence ?? 0).leftPad(12, '0');
    return Id.valueOf(objectType.getDescribe().getKeyPrefix() + suffix);
  }

  private static SObject buildRecord(
    Schema.SObjectType objectType,
    Map<String, Object> fields
  ) {
    SObject result = objectType.newSObject();
    Set<String> fieldNames = fields == null
      ? new Set<String>()
      : fields.keySet();
    for (String fieldName : fieldNames) {
      result.put(fieldName, fields.get(fieldName));
    }
    return result;
  }

  public static String qualifiedCheckName(String developerName) {
    return [
      SELECT QualifiedApiName
      FROM Record_Health_Check__mdt
      WHERE DeveloperName = :developerName
      LIMIT 1
    ]
    .QualifiedApiName;
  }

  public static String qualifiedCheckSetName(String developerName) {
    return [
      SELECT QualifiedApiName
      FROM Record_Health_Check_Set__mdt
      WHERE DeveloperName = :developerName
      LIMIT 1
    ]
    .QualifiedApiName;
  }

  public static Boolean hasIntegrationFixtures() {
    return [
        SELECT COUNT()
        FROM Record_Health_Check_Set__mdt
        WHERE DeveloperName = 'Account_Data_Quality'
      ] > 0;
  }

  public static void createTestRecords() {
    String token = uniqueToken();
    Account healthyAccount = new Account(
      Name = HEALTHY_ACCOUNT_NAME_PREFIX + ' ' + token,
      BillingStreet = '1 Test Way',
      BillingCity = 'Chicago',
      BillingState = 'IL',
      BillingPostalCode = '60601',
      BillingCountry = 'USA',
      ShippingStreet = '1 Test Way',
      ShippingCity = 'Chicago',
      ShippingState = 'IL',
      ShippingPostalCode = '60601',
      ShippingCountry = 'USA',
      Website = 'https://' + token.toLowerCase() + '.example.com',
      Phone = '312-555-' + token.right(4),
      Industry = 'Technology',
      Rating = 'Hot',
      AnnualRevenue = 1000000,
      NumberOfEmployees = 25,
      AccountNumber = token
    );

    populateRequiredFields(healthyAccount);
    insertAllowingDuplicates(new List<SObject>{ healthyAccount });
    createCompletedTask(healthyAccount.Id);
  }

  public static void createCoverageTestRecords() {
    createTestRecords();

    Account accountRecord = getHealthyAccount();
    createContacts(
      new List<Contact>{
        new Contact(
          LastName = 'Alpha',
          AccountId = accountRecord.Id,
          Title = 'Primary Contact',
          Email = 'alpha@example.com',
          Phone = '312-555-0101',
          MailingCity = accountRecord.BillingCity,
          MailingState = accountRecord.BillingState
        ),
        new Contact(
          LastName = 'Beta',
          AccountId = accountRecord.Id,
          Title = 'Secondary Contact',
          Email = 'beta@example.com',
          Phone = '312-555-0102',
          MailingCity = 'Evanston',
          MailingState = accountRecord.BillingState
        )
      }
    );
    createOpportunity(accountRecord.Id, 'Coverage Opportunity', 50000);
  }

  public static Account createAccount(String name) {
    return createAccount(new Account(Name = name));
  }

  public static Account createAccount(Account accountRecord) {
    populateRequiredFields(accountRecord);
    insertAllowingDuplicates(new List<SObject>{ accountRecord });
    return accountRecord;
  }

  /** Persists arbitrary test records while keeping test DML at one review point. */
  public static void createRecords(List<SObject> records) {
    insertAllowingDuplicates(records);
  }

  public static void createAccounts(List<Account> records) {
    List<SObject> values = new List<SObject>();
    values.addAll(records);
    insertAllowingDuplicates(values);
  }

  public static void createOpportunities(List<Opportunity> records) {
    List<SObject> values = new List<SObject>();
    values.addAll(records);
    insertAllowingDuplicates(values);
  }

  public static User createMinimumAccessUser(String alias) {
    return RecordHealthCheckPersonaTestDataFactory.createMinimumAccessUser(
      alias
    );
  }

  public static User createUser(User userRecord) {
    return RecordHealthCheckPersonaTestDataFactory.createUser(userRecord);
  }

  /**
   * A user pinned to a locale, for tests that assert on grouping separators or
   * date formats. Running those assertions under System.runAs keeps them stable
   * in an org whose default locale is not English (US).
   *
   * The insert runs as the current user so User DML does not mix with SObject
   * DML in the calling test.
   */
  public static User createUserWithLocale(String localeSidKey, String alias) {
    return RecordHealthCheckPersonaTestDataFactory.createUserWithLocale(
      localeSidKey,
      alias
    );
  }

  public static Account createDeletedAccount(String name) {
    Account accountRecord = createAccount(name);
    delete accountRecord;
    return accountRecord;
  }

  public static void createEmailCoverageContacts(Id accountId) {
    createContacts(
      new List<Contact>{
        new Contact(LastName = 'No Email', AccountId = accountId),
        new Contact(
          LastName = 'Has Email',
          AccountId = accountId,
          Email = 'healthy@example.com'
        )
      }
    );
  }

  public static void createMatchingCityContacts(
    Id accountId,
    String mailingCity
  ) {
    createContacts(
      new List<Contact>{
        new Contact(
          LastName = 'Chicago One',
          AccountId = accountId,
          MailingCity = mailingCity
        ),
        new Contact(
          LastName = 'Chicago Two',
          AccountId = accountId,
          MailingCity = mailingCity
        )
      }
    );
  }

  public static Contact createContact(Contact contactRecord) {
    createContacts(new List<Contact>{ contactRecord });
    return contactRecord;
  }

  public static Contact createContact(Map<String, Object> fields) {
    return createContact(contact(fields));
  }

  public static Opportunity createOpportunity(
    Id accountId,
    String name,
    Decimal amount
  ) {
    Opportunity opportunityRecord = new Opportunity(
      Name = name,
      AccountId = accountId,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      Amount = amount
    );
    populateRequiredFields(opportunityRecord);
    insertAllowingDuplicates(new List<SObject>{ opportunityRecord });
    return opportunityRecord;
  }

  public static Opportunity createOpportunity(Opportunity opportunity) {
    List<SObject> values = new List<SObject>{ opportunity };
    insertAllowingDuplicates(values);
    return opportunity;
  }

  public static Opportunity createOpportunity(Map<String, Object> fields) {
    return createOpportunity(opportunity(fields));
  }

  public static Task createCompletedTask(Id whatId) {
    return createTask(
      new Task(
        Subject = 'Coverage Task',
        WhatId = whatId,
        Status = 'Completed',
        ActivityDate = Date.today()
      )
    );
  }

  public static Task createTask(Task taskRecord) {
    populateRequiredFields(taskRecord);
    insertAllowingDuplicates(new List<SObject>{ taskRecord });
    return taskRecord;
  }

  public static Task createTask(Map<String, Object> fields) {
    return createTask(task(fields));
  }

  public static Event createEvent(Event eventRecord) {
    populateRequiredFields(eventRecord);
    insertAllowingDuplicates(new List<SObject>{ eventRecord });
    return eventRecord;
  }

  public static Event createEvent(Map<String, Object> fields) {
    return createEvent(event(fields));
  }

  public static List<Contact> createContacts(List<Contact> contacts) {
    List<SObject> records = new List<SObject>();
    for (Contact contactRecord : contacts) {
      populateRequiredFields(contactRecord);
      records.add(contactRecord);
    }
    insertAllowingDuplicates(records);
    return contacts;
  }

  private static String uniqueToken() {
    String token = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    return token.length() > 8 ? token.right(8) : token;
  }

  private static void insertAllowingDuplicates(List<SObject> records) {
    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.allowSave = true;
    dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;

    Database.SaveResult[] saveResults = Database.insert(records, dmlOptions);
    for (Database.SaveResult saveResult : saveResults) {
      Assert.areEqual(
        true,
        saveResult.isSuccess(),
        'Test data insert failed: ' + JSON.serialize(saveResult.getErrors())
      );
    }
  }

  private static void populateRequiredFields(SObject record) {
    Map<String, Schema.SObjectField> fields = record.getSObjectType()
      .getDescribe()
      .fields.getMap();
    for (String fieldName : fields.keySet()) {
      Schema.DescribeFieldResult fieldDescribe = fields.get(fieldName)
        .getDescribe();
      if (
        record.get(fieldName) != null ||
        fieldName == 'Id' ||
        fieldDescribe.isNillable() ||
        fieldDescribe.isDefaultedOnCreate() ||
        !fieldDescribe.isCreateable()
      ) {
        continue;
      }

      Object value = sampleValueFor(fieldDescribe);
      if (value != null) {
        record.put(fieldName, value);
      }
    }
  }

  private static Object sampleValueFor(
    Schema.DescribeFieldResult fieldDescribe
  ) {
    Schema.DisplayType fieldType = fieldDescribe.getType();
    if (fieldType == Schema.DisplayType.String) {
      return 'Test ' + uniqueToken();
    }
    if (fieldType == Schema.DisplayType.TextArea) {
      return 'Test data';
    }
    if (fieldType == Schema.DisplayType.Email) {
      return 'record.health+' + uniqueToken().toLowerCase() + '@example.com';
    }
    if (fieldType == Schema.DisplayType.Phone) {
      return '312-555-' + uniqueToken().right(4);
    }
    if (fieldType == Schema.DisplayType.Url) {
      return 'https://' + uniqueToken().toLowerCase() + '.example.com';
    }
    if (fieldType == Schema.DisplayType.Boolean) {
      return false;
    }
    if (
      fieldType == Schema.DisplayType.Integer ||
      fieldType == Schema.DisplayType.Double ||
      fieldType == Schema.DisplayType.Currency ||
      fieldType == Schema.DisplayType.Percent
    ) {
      return 1;
    }
    if (fieldType == Schema.DisplayType.Date) {
      return Date.today();
    }
    if (fieldType == Schema.DisplayType.DateTime) {
      return System.now();
    }
    if (fieldType == Schema.DisplayType.Picklist) {
      for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
        if (entry.isActive()) {
          return entry.getValue();
        }
      }
    }
    return null;
  }

  public static Account getHealthyAccount() {
    String namePattern = HEALTHY_ACCOUNT_NAME_PREFIX + '%';
    return [
      SELECT
        Id,
        Name,
        BillingStreet,
        BillingCity,
        BillingState,
        BillingPostalCode,
        BillingCountry,
        ShippingStreet,
        ShippingCity,
        ShippingState,
        ShippingPostalCode,
        ShippingCountry,
        Website,
        Phone,
        Industry,
        Rating,
        AnnualRevenue
      FROM Account
      WHERE Name LIKE :namePattern
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
  }
}
