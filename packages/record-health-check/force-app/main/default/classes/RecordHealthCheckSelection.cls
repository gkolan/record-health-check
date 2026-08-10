/**
 * Immutable XOR selection of one qualified Check Set or one qualified Check.
 */
global class RecordHealthCheckSelection {
  /** Selected qualified Check Set identity, or null for Check selection. */
  global String checkSetQualifiedApiName { get; private set; }
  /** Selected qualified Check identity, or null for Check Set selection. */
  global String checkQualifiedApiName { get; private set; }

  private RecordHealthCheckSelection(
    String checkSetQualifiedApiName,
    String checkQualifiedApiName
  ) {
    this.checkSetQualifiedApiName = checkSetQualifiedApiName;
    this.checkQualifiedApiName = checkQualifiedApiName;
  }

  /**
   * @param qualifiedApiName Custom Metadata QualifiedApiName for a Check Set.
   * @return A Check Set selection.
   */
  global static RecordHealthCheckSelection forCheckSet(
    String qualifiedApiName
  ) {
    return new RecordHealthCheckSelection(
      normalizedIdentity(qualifiedApiName, 'Check Set'),
      null
    );
  }

  /**
   * @param qualifiedApiName Custom Metadata QualifiedApiName for a Check.
   * @return A Check selection.
   */
  global static RecordHealthCheckSelection forCheck(String qualifiedApiName) {
    return new RecordHealthCheckSelection(
      null,
      normalizedIdentity(qualifiedApiName, 'Check')
    );
  }

  private static String normalizedIdentity(
    String qualifiedApiName,
    String label
  ) {
    try {
      return RecordHealthCheckQualifiedIdentity.normalize(
        qualifiedApiName,
        label
      );
    } catch (IllegalArgumentException error) {
      throw new RecordHealthCheckSelectionException(error.getMessage());
    }
  }

  /** Invalid immutable-selection construction. */
  global class RecordHealthCheckSelectionException extends Exception {
  }
}
