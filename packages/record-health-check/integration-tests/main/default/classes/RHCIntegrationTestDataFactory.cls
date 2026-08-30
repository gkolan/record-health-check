/** Centralizes integration-harness test records that are not part of Framework. */
@IsTest
public class RHCIntegrationTestDataFactory {
  public static final String HEALTHY_ACCOUNT_NAME_PREFIX = 'Record Health Test Account';

  /** Creates the standard record graph used by integration surface tests. */
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
    createAccount(healthyAccount);
    createCompletedTask(healthyAccount.Id);
  }

  /** Creates the expanded standard record graph used by integration coverage tests. */
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

  public static Account createDeletedAccount(String name) {
    Account accountRecord = createAccount(name);
    delete accountRecord;
    return accountRecord;
  }

  public static void createAccounts(List<Account> records) {
    List<SObject> values = new List<SObject>();
    values.addAll(records);
    createRecords(values);
  }

  public static Contact createContact(Contact contactRecord) {
    createContacts(new List<Contact>{ contactRecord });
    return contactRecord;
  }

  public static Contact createContact(Map<String, Object> fields) {
    return createContact(RecordHealthCheckTestDataFactory.contact(fields));
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

  public static Opportunity createOpportunity(
    Id accountId,
    String name,
    Decimal amount
  ) {
    return createOpportunity(
      new Opportunity(
        Name = name,
        AccountId = accountId,
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(30),
        Amount = amount
      )
    );
  }

  public static Opportunity createOpportunity(Opportunity opportunityRecord) {
    populateRequiredFields(opportunityRecord);
    insertAllowingDuplicates(new List<SObject>{ opportunityRecord });
    return opportunityRecord;
  }

  public static Opportunity createOpportunity(Map<String, Object> fields) {
    return createOpportunity(
      RecordHealthCheckTestDataFactory.opportunity(fields)
    );
  }

  public static void createOpportunities(List<Opportunity> records) {
    List<SObject> values = new List<SObject>();
    values.addAll(records);
    createRecords(values);
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
    return createTask(RecordHealthCheckTestDataFactory.task(fields));
  }

  public static Event createEvent(Event eventRecord) {
    populateRequiredFields(eventRecord);
    insertAllowingDuplicates(new List<SObject>{ eventRecord });
    return eventRecord;
  }

  public static Event createEvent(Map<String, Object> fields) {
    return createEvent(RecordHealthCheckTestDataFactory.event(fields));
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

  /** Creates a persisted integration-only persona record. */
  public static RHC_Persona_Record__c personaRecord(
    String accessibleValue,
    String restrictedValue
  ) {
    RHC_Persona_Record__c result = new RHC_Persona_Record__c(
      Accessible_Value__c = accessibleValue,
      Restricted_Value__c = restrictedValue
    );
    insert result;
    return result;
  }

  /** Shares one persona record read-only with one restricted user. */
  public static void sharePersonaRecord(Id recordId, Id userId) {
    insert new RHC_Persona_Record__Share(
      ParentId = recordId,
      UserOrGroupId = userId,
      AccessLevel = 'Read',
      RowCause = Schema.RHC_Persona_Record__Share.RowCause.Manual
    );
  }

  public static void createRecords(List<SObject> records) {
    insertAllowingDuplicates(records);
  }

  public static SObject createRecord(SObject record) {
    insert record;
    return record;
  }

  public static Contact contact(Id accountId, String lastName) {
    Contact result = new Contact(AccountId = accountId, LastName = lastName);
    insert result;
    return result;
  }

  public static Opportunity opportunity(Id accountId, String name) {
    Opportunity result = new Opportunity(
      AccountId = accountId,
      Name = name,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
    insert result;
    return result;
  }

  public static RHC_Benchmark_Result__c benchmarkResult(
    Map<String, Object> fields
  ) {
    RHC_Benchmark_Result__c result = new RHC_Benchmark_Result__c();
    applyFields(result, fields);
    return result;
  }

  public static RHC_Event_Export__c eventExport(Map<String, Object> fields) {
    RHC_Event_Export__c result = new RHC_Event_Export__c();
    applyFields(result, fields);
    return result;
  }

  /** Builds one neutral data-shape record without persisting it. */
  public static RHC_Conformance_Record__c conformanceRecord(
    Map<String, Object> fields
  ) {
    RHC_Conformance_Record__c result = new RHC_Conformance_Record__c();
    applyFields(result, fields);
    return result;
  }

  private static void applyFields(SObject record, Map<String, Object> fields) {
    if (fields == null) {
      return;
    }
    for (String fieldName : fields.keySet()) {
      record.put(fieldName, fields.get(fieldName));
    }
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
      Assert.isTrue(
        saveResult.isSuccess(),
        'Integration test data insert failed: ' +
        JSON.serialize(saveResult.getErrors())
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
}
