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
}
