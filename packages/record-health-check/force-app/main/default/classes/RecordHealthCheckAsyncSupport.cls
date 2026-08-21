/** Shared normalization and population bounds for asynchronous adapters. */
public with sharing class RecordHealthCheckAsyncSupport {
  /** Normalized asynchronous request state. */
  public class RequestState {
    public String checkSetQualifiedApiName { get; private set; }
    public List<Id> recordIds { get; private set; }

    private RequestState(String identity, List<Id> ids) {
      this.checkSetQualifiedApiName = identity;
      this.recordIds = ids;
    }
  }

  /** Normalizes one Check Set population and enforces its adapter-specific cap. */
  public static RequestState requestState(
    String checkSetQualifiedApiName,
    List<Id> suppliedIds,
    Integer maximumRecords,
    String populationLabel
  ) {
    String normalizedIdentity = RecordHealthCheckQualifiedIdentity.normalize(
      checkSetQualifiedApiName,
      'Check Set'
    );
    List<Id> normalizedIds = normalizeIds(suppliedIds);
    if (normalizedIds.isEmpty() || normalizedIds.size() > maximumRecords) {
      throw new IllegalArgumentException(
        populationLabel +
          ' must contain 1–' +
          maximumRecords +
          ' IDs; suppliedCount=' +
          normalizedIds.size() +
          '.'
      );
    }
    requireIdsForSelectedObject(
      normalizedIdentity,
      normalizedIds,
      populationLabel
    );
    return new RequestState(normalizedIdentity, normalizedIds);
  }

  /** Returns a detached, null-free, insertion-ordered list of unique IDs. */
  public static List<Id> normalizeIds(List<Id> suppliedIds) {
    List<Id> result = new List<Id>();
    if (suppliedIds == null) {
      return result;
    }
    Set<Id> seen = new Set<Id>();
    for (Id recordId : suppliedIds) {
      if (recordId != null && seen.add(recordId)) {
        result.add(recordId);
      }
    }
    return result;
  }

  private static void requireIdsForSelectedObject(
    String checkSetQualifiedApiName,
    List<Id> normalizedIds,
    String populationLabel
  ) {
    // Custom Metadata is framework configuration and is read in system context.
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata defines the packaged Check Set object and must remain available to authorized async runners.
    List<Record_Health_Check_Set__mdt> checkSets = [
      SELECT ObjectApiName__c
      FROM Record_Health_Check_Set__mdt
      WHERE QualifiedApiName = :checkSetQualifiedApiName AND IsActive__c = TRUE
      LIMIT 2
    ];
    if (
      checkSets.size() != 1 || String.isBlank(checkSets[0].ObjectApiName__c)
    ) {
      throw new IllegalArgumentException(
        'Check Set "' +
          checkSetQualifiedApiName +
          '" was not found, is inactive, or has no configured object.'
      );
    }
    String expectedObject = checkSets[0].ObjectApiName__c;
    Integer mismatchCount = 0;
    for (Id recordId : normalizedIds) {
      String actualObject = RecordHealthCheckDescribeCache.objectApiName(
        recordId
      );
      if (expectedObject.equalsIgnoreCase(actualObject)) {
        continue;
      }
      mismatchCount++;
    }
    if (mismatchCount > 0) {
      throw new IllegalArgumentException(
        populationLabel +
          ' contains ' +
          mismatchCount +
          ' ID(s) outside the selected Check Set object ' +
          expectedObject +
          '; no records were submitted.'
      );
    }
  }
}
