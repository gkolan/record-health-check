/**
 * Request validation and correlation identifiers shared by every Agentforce
 * surface: the two native actions and the REST tool resource.
 */
public with sharing class RecordHealthCheckAgentContract {
  private static final String IDENTITY_PATTERN = '^[a-zA-Z][a-zA-Z0-9_]*(?:__[a-zA-Z][a-zA-Z0-9_]*)?$';
  private static final String CORRELATION_ID_PATTERN = '^[a-zA-Z0-9._:-]+$';

  /** Rejection message for a caller-supplied correlation identifier. */
  public static final String CORRELATION_ID_MESSAGE = 'Correlation ID must use 1 to 120 letters, numbers, periods, underscores, colons, or hyphens.';

  /**
   * Accepts a caller-supplied correlation identifier that is safe to log.
   *
   * @param value Trimmed caller value.
   * @return True when the value is within 120 safe characters.
   */
  public static Boolean isValidCorrelationId(String value) {
    return value.length() <= 120 &&
      Pattern.matches(CORRELATION_ID_PATTERN, value);
  }

  /**
   * Returns the caller's correlation identifier, or generates a collision-resistant one.
   *
   * @param value Caller-supplied identifier; blank or unsafe values are replaced.
   * @return An identifier safe to place in operational logs.
   */
  public static String safeCorrelationId(String value) {
    if (!String.isBlank(value) && isValidCorrelationId(value.trim())) {
      return value.trim();
    }
    String randomSuffix = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
    return 'agent-' +
      String.valueOf(DateTime.now().getTime()) +
      '-' +
      randomSuffix;
  }

  /**
   * Validates one native Agentforce action request.
   *
   * @param recordId Record the caller asked to evaluate.
   * @param qualifiedApiName Exact Check or Check Set identity.
   * @param correlationId Optional caller-supplied correlation identifier.
   * @param identityLabel Label naming the identity in every rejection message.
   * @return The first rejection message, or null when the request is valid.
   */
  public static String validateRequest(
    Id recordId,
    String qualifiedApiName,
    String correlationId,
    String identityLabel
  ) {
    if (recordId == null) {
      return 'Record ID is required.';
    }
    if (String.isBlank(qualifiedApiName)) {
      return identityLabel + ' is required.';
    }
    String identity = qualifiedApiName.trim();
    if (
      identity.length() >
      RecordHealthCheckConstants.MAX_QUALIFIED_API_NAME_LENGTH
    ) {
      return identityLabel + ' must not exceed 255 characters.';
    }
    if (!Pattern.matches(IDENTITY_PATTERN, identity)) {
      return identityLabel + ' has an invalid format.';
    }
    if (
      !String.isBlank(correlationId) &&
      !isValidCorrelationId(correlationId.trim())
    ) {
      return CORRELATION_ID_MESSAGE;
    }
    return null;
  }
}
