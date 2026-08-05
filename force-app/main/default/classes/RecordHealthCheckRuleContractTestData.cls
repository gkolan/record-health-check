/** Data and permission test setups supplied by a plugin author's contract test. */
global abstract class RecordHealthCheckRuleContractTestData {
  /** Builds an isolated scope of exactly the requested size. */
  global abstract RecordHealthCheckScope createScope(Integer size);

  /** Optional controlled test setup whose user-mode and system-mode visibility differ. */
  global virtual PermissionFixture permissionFixture() {
    return null;
  }

  global class PermissionFixture {
    global User leastPrivilegeUser;
    global RecordHealthCheckScope scope;
    global Id assertedRecordId;
    global String expectedStatus = RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
  }
}
