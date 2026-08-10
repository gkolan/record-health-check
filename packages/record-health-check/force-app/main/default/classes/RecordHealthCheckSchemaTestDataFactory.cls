/**
 * Namespace-neutral schema and permission-set helpers for packaged tests.
 */
@IsTest
public class RecordHealthCheckSchemaTestDataFactory {
  /** Resolves the packaged runner Permission Set API name in any install shape. */
  public static String runnerPermissionSetName() {
    return permissionSetName('Record_Health_Check_User');
  }

  /** Resolves the packaged admin Permission Set API name in any install shape. */
  public static String adminPermissionSetName() {
    return permissionSetName('Record_Health_Check_Admin');
  }

  /**
   * Returns a global describe type by local API name, including namespaced installs
   * where the key is prefixed (for example `rhc__RHC_Event_Export__c`).
   */
  public static Schema.SObjectType globalDescribeType(String localApiName) {
    Map<String, Schema.SObjectType> typesByName = Schema.getGlobalDescribe();
    if (typesByName.containsKey(localApiName)) {
      return typesByName.get(localApiName);
    }
    String suffix = '__' + localApiName;
    for (String apiName : typesByName.keySet()) {
      if (apiName.endsWith(suffix)) {
        return typesByName.get(apiName);
      }
    }
    return null;
  }

  /**
   * Returns the org-specific field API name for a schema token or a local suffix match.
   */
  public static String fieldApiName(Schema.SObjectField fieldToken) {
    return fieldToken.getDescribe().getName();
  }

  /**
   * Returns a field API name on the given type, matching an exact local name or a
   * namespace-qualified suffix (for example `Tags__c` or `rhc__Tags__c`).
   */
  public static String fieldApiNameOnType(
    Schema.SObjectType objectType,
    String localFieldApiName
  ) {
    if (objectType == null) {
      return localFieldApiName;
    }
    Map<String, Schema.SObjectField> fields = objectType.getDescribe()
      .fields.getMap();
    if (fields.containsKey(localFieldApiName)) {
      return localFieldApiName;
    }
    String suffix = '__' + localFieldApiName;
    for (Schema.SObjectField fieldToken : fields.values()) {
      String apiName = fieldToken.getDescribe().getName();
      if (apiName.endsWith(suffix)) {
        return apiName;
      }
    }
    return localFieldApiName;
  }

  private static String permissionSetName(String developerName) {
    List<PermissionSet> permissionSets = [
      SELECT Name
      FROM PermissionSet
      WHERE Name = :developerName
      LIMIT 1
    ];
    Assert.isFalse(
      permissionSets.isEmpty(),
      'Permission set not found: ' + developerName
    );
    return permissionSets[0].Name;
  }
}
