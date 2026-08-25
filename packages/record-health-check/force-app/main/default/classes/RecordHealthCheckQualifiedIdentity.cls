/** Shared validation for every qualified metadata-identity boundary. */
public with sharing class RecordHealthCheckQualifiedIdentity {
  /** Trims and bounds one Check or Check Set QualifiedApiName. */
  public static String normalize(String supplied, String label) {
    if (supplied == null) {
      throw new IllegalArgumentException(
        label + ' QualifiedApiName is required.'
      );
    }
    if (String.isBlank(supplied.trim())) {
      throw new IllegalArgumentException(
        label + ' QualifiedApiName is required.'
      );
    }
    String normalized = supplied.trim();
    if (
      normalized.length() >
      RecordHealthCheckConstants.MAX_QUALIFIED_API_NAME_LENGTH
    ) {
      throw new IllegalArgumentException(
        label +
          ' QualifiedApiName must not exceed ' +
          RecordHealthCheckConstants.MAX_QUALIFIED_API_NAME_LENGTH +
          ' characters.'
      );
    }
    return normalized;
  }
}
