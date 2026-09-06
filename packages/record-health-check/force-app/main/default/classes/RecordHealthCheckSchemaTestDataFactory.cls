/**
 * Namespace-neutral schema and permission-set helpers for packaged tests.
 */
@IsTest
public class RecordHealthCheckSchemaTestDataFactory {
  /** Resolves the packaged runner Permission Set API name in any install shape. */
  public static String runnerPermissionSetName() {
    return permissionSetName('Record_Health_Check_User');
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
