/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
/**
 * Packaged tests should prefer builders plus syntheticId. Subscriber-shaped
 * business-object persistence belongs in the clean-scratch integration factory;
 * unlocked-package local tests execute against customer automation.
 */
public class RecordHealthCheckTestDataFactory {
  public static final String HEALTHY_ACCOUNT_NAME_PREFIX = 'Record Health Test Account';
  private static Integer fixtureSequence = 800000;

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

  /** Creates a test user with the Minimum Access profile. */
  public static User createMinimumAccessUser(String alias) {
    return RecordHealthCheckPersonaTestDataFactory.createMinimumAccessUser(
      alias
    );
  }

  /** Persists a supplied integration-test user. */
  public static User createUser(User userRecord) {
    return RecordHealthCheckPersonaTestDataFactory.createUser(userRecord);
  }

  /** Creates a locale-pinned user for display integration tests. */
  public static User createUserWithLocale(String localeSidKey, String alias) {
    return RecordHealthCheckPersonaTestDataFactory.createUserWithLocale(
      localeSidKey,
      alias
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

  /** Prepares package-safe fixtures without persisting subscriber-shaped data. */
  public static void prepareTestFixtures() {
    fixtureSequence = Math.max(fixtureSequence, 800000);
  }

  /** Prepares the expanded package-safe fixture set without DML. */
  public static void prepareCoverageFixtures() {
    fixtureSequence = Math.max(fixtureSequence, 800000);
  }

  public static Account accountFixture(String name) {
    return accountFixture(account(new Map<String, Object>{ 'Name' => name }));
  }

  public static Account accountFixture(Account accountRecord) {
    assignSyntheticId(accountRecord);
    return accountRecord;
  }

  public static void accountsFixture(List<Account> records) {
    List<SObject> values = new List<SObject>();
    values.addAll(records);
    recordsFixture(values);
  }

  public static Account deletedAccountFixture(String name) {
    return accountFixture(name);
  }

  public static Contact contactFixture(Contact contactRecord) {
    assignSyntheticId(contactRecord);
    return contactRecord;
  }

  public static Contact contactFixture(Map<String, Object> fields) {
    return contactFixture(contact(fields));
  }

  public static List<Contact> contactsFixture(List<Contact> contacts) {
    for (Contact contactRecord : contacts) {
      assignSyntheticId(contactRecord);
    }
    return contacts;
  }

  public static Opportunity opportunityFixture(
    Id accountId,
    String name,
    Decimal amount
  ) {
    return opportunityFixture(
      opportunity(
        new Map<String, Object>{
          'AccountId' => accountId,
          'Name' => name,
          'StageName' => 'Prospecting',
          'CloseDate' => Date.today().addDays(30),
          'Amount' => amount
        }
      )
    );
  }

  public static Opportunity opportunityFixture(Opportunity opportunityRecord) {
    assignSyntheticId(opportunityRecord);
    return opportunityRecord;
  }

  public static Opportunity opportunityFixture(Map<String, Object> fields) {
    return opportunityFixture(opportunity(fields));
  }

  public static void opportunitiesFixture(List<Opportunity> records) {
    List<SObject> values = new List<SObject>();
    values.addAll(records);
    recordsFixture(values);
  }

  public static Task completedTaskFixture(Id whatId) {
    return taskFixture(
      task(
        new Map<String, Object>{
          'Subject' => 'Coverage Task',
          'WhatId' => whatId,
          'Status' => 'Completed',
          'ActivityDate' => Date.today()
        }
      )
    );
  }

  public static Task taskFixture(Task taskRecord) {
    assignSyntheticId(taskRecord);
    return taskRecord;
  }

  public static Task taskFixture(Map<String, Object> fields) {
    return taskFixture(task(fields));
  }

  public static Event eventFixture(Event eventRecord) {
    assignSyntheticId(eventRecord);
    return eventRecord;
  }

  public static Event eventFixture(Map<String, Object> fields) {
    return eventFixture(event(fields));
  }

  public static void recordsFixture(List<SObject> records) {
    for (SObject record : records) {
      assignSyntheticId(record);
    }
  }

  public static void emailCoverageContactsFixture(Id accountId) {
    contactsFixture(
      new List<Contact>{
        contact(new Map<String, Object>{ 'AccountId' => accountId }),
        contact(
          new Map<String, Object>{
            'AccountId' => accountId,
            'Email' => 'healthy@example.com'
          }
        )
      }
    );
  }

  public static void matchingCityContactsFixture(
    Id accountId,
    String mailingCity
  ) {
    contactsFixture(
      new List<Contact>{
        contact(
          new Map<String, Object>{
            'AccountId' => accountId,
            'MailingCity' => mailingCity
          }
        )
      }
    );
  }

  public static Account healthyAccountFixture() {
    return accountFixture(
      account(
        new Map<String, Object>{
          'Name' => HEALTHY_ACCOUNT_NAME_PREFIX,
          'BillingStreet' => '1 Test Way',
          'BillingCity' => 'Chicago',
          'BillingState' => 'IL',
          'BillingPostalCode' => '60601',
          'BillingCountry' => 'USA',
          'ShippingStreet' => '1 Test Way',
          'ShippingCity' => 'Chicago',
          'ShippingState' => 'IL',
          'ShippingPostalCode' => '60601',
          'ShippingCountry' => 'USA',
          'Website' => 'https://healthy.example.com',
          'Phone' => '312-555-0100',
          'Industry' => 'Technology',
          'Rating' => 'Hot',
          'AnnualRevenue' => 1000000,
          'NumberOfEmployees' => 25,
          'AccountNumber' => 'RHC-FIXTURE'
        }
      )
    );
  }

  private static void assignSyntheticId(SObject record) {
    if (record.Id == null) {
      fixtureSequence++;
      record.Id = syntheticId(record.getSObjectType(), fixtureSequence);
    }
  }
}
