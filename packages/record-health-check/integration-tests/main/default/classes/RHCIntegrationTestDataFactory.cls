/** Centralizes integration-harness test records that are not part of Framework. */
@IsTest
public class RHCIntegrationTestDataFactory {
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
    insert records;
  }

  public static SObject createRecord(SObject record) {
    insert record;
    return record;
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

  private static void applyFields(SObject record, Map<String, Object> fields) {
    if (fields == null) {
      return;
    }
    for (String fieldName : fields.keySet()) {
      record.put(fieldName, fields.get(fieldName));
    }
  }
}
