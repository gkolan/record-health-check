/** Produces bounded, source-free categories for formula compiler failures. */
public with sharing class RecordHealthCheckCompileDiagnostic {
  private static final Integer ATTEMPT_LIMIT = 120;
  private static final Integer AGGREGATE_LIMIT = 1000;

  /**
   * Classifies one compiler attempt without retaining its exception message.
   * @param returnType Formula compiler return type attempted.
   * @param failure Rejected compiler attempt, or null when compilation returned null.
   * @return One-line category that contains no formula or compiler message.
   */
  public static String fromAttempt(String returnType, Exception failure) {
    String normalizedType = String.isBlank(returnType)
      ? 'UNKNOWN'
      : bound(returnType.replaceAll('[^A-Z0-9_]', ''), 40);
    String category = failure == null
      ? 'COMPILER_RETURNED_NULL'
      : 'FORMULA_COMPILE_REJECTED';
    return bound(normalizedType + ':' + category, ATTEMPT_LIMIT);
  }

  /**
   * Joins attempt categories under the authorized aggregate response limit.
   * @param categories Source-free categories returned by fromAttempt.
   * @return Joined categories no longer than 1,000 characters.
   */
  public static String boundedCategories(List<String> categories) {
    return bound(
      categories == null ? '' : String.join(categories, '; '),
      AGGREGATE_LIMIT
    );
  }

  private static String bound(String value, Integer maxLength) {
    return value.length() <= maxLength ? value : value.substring(0, maxLength);
  }
}
