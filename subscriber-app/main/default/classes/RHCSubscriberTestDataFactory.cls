/**
 * Subscriber-owned smoke-test data helpers. Not part of the RHC package.
 */
@IsTest
public class RHCSubscriberTestDataFactory {
  public static Boolean isPackageInstalled() {
    return Type.forName('rhc.RecordHealthCheck') != null;
  }

  public static String qualifiedCheckSetName(String developerName) {
    return [
      SELECT QualifiedApiName
      FROM rhc__Record_Health_Check_Set__mdt
      WHERE DeveloperName = :developerName
      LIMIT 1
    ]
    .QualifiedApiName;
  }

  public static Account createAccount(String name) {
    Account accountRecord = new Account(Name = name);
    populateRequiredFields(accountRecord);
    insert accountRecord;
    return accountRecord;
  }

  public static User createStandardUserWithoutRunAccess() {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    User userRecord = new User(
      Alias = 'nosmoke',
      Email = 'subscriber.norun@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'NoRunAccess',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = standardProfile.Id,
      TimeZoneSidKey = 'America/Chicago',
      Username = 'subscriber.norun.' +
        System.currentTimeMillis() +
        '@example.com'
    );
    insert userRecord;
    return userRecord;
  }

  public static void assignPackagedPermissionSet(
    Id userId,
    String permissionSetName
  ) {
    PermissionSet permissionSet = resolvePermissionSet(permissionSetName);
    List<PermissionSetAssignment> existing = [
      SELECT Id
      FROM PermissionSetAssignment
      WHERE AssigneeId = :userId AND PermissionSetId = :permissionSet.Id
      LIMIT 1
    ];
    if (!existing.isEmpty()) {
      return;
    }
    insert new PermissionSetAssignment(
      AssigneeId = userId,
      PermissionSetId = permissionSet.Id
    );
  }

  private static PermissionSet resolvePermissionSet(String permissionSetName) {
    List<PermissionSet> permissionSets = [
      SELECT Id, Name
      FROM PermissionSet
      WHERE Name = :permissionSetName
      LIMIT 1
    ];
    if (permissionSets.isEmpty()) {
      String suffix = permissionSetName.contains('__')
        ? permissionSetName.substring(permissionSetName.indexOf('__') + 2)
        : permissionSetName;
      for (PermissionSet candidate : [
        SELECT Id, Name
        FROM PermissionSet
        WHERE Name LIKE :('%' + suffix)
        LIMIT 20
      ]) {
        if (candidate.Name.endsWith(suffix)) {
          return candidate;
        }
      }
    }
    System.assert(
      !permissionSets.isEmpty(),
      'Permission set not found: ' + permissionSetName
    );
    return permissionSets[0];
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
      return 'Subscriber Test';
    }
    if (fieldType == Schema.DisplayType.Email) {
      return 'subscriber.test@example.com';
    }
    if (fieldType == Schema.DisplayType.Phone) {
      return '312-555-0100';
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
