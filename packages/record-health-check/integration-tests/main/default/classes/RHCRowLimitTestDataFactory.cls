/** Test-data factory for row-limit boundary fixtures. */
@IsTest
public class RHCRowLimitTestDataFactory {
  public static void createAccounts(String namePrefix, Integer recordCount) {
    List<Account> records = new List<Account>();
    for (Integer index = 0; index < recordCount; index++) {
      records.add(
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => namePrefix + index }
        )
      );
    }
    insert records;
  }
}
