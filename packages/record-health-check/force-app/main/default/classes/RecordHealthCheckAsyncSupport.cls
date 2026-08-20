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
    normalizedIds = idsForSelectedObject(normalizedIdentity, normalizedIds);
    if (normalizedIds.isEmpty()) {
      throw new IllegalArgumentException(
        populationLabel +
        ' must contain at least one ID for the selected Check Set object.'
      );
    }
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

  private static List<Id> idsForSelectedObject(
    String checkSetQualifiedApiName,
    List<Id> normalizedIds
  ) {
    // Custom Metadata is framework configuration and is read in system context.
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata defines the packaged Check Set object and must remain available to authorized async runners.
    List<Record_Health_Check_Set__mdt> checkSets = [
      SELECT ObjectApiName__c
      FROM Record_Health_Check_Set__mdt
      WHERE QualifiedApiName = :checkSetQualifiedApiName
      LIMIT 2
    ];
    if (
      checkSets.size() != 1 || String.isBlank(checkSets[0].ObjectApiName__c)
    ) {
      return normalizedIds;
    }
    String expectedObject = checkSets[0].ObjectApiName__c;
    List<Id> matchingIds = new List<Id>();
    for (Id recordId : normalizedIds) {
      String actualObject = RecordHealthCheckDescribeCache.objectApiName(
        recordId
      );
      if (expectedObject.equalsIgnoreCase(actualObject)) {
        matchingIds.add(recordId);
      }
    }
    return matchingIds;
  }
}
