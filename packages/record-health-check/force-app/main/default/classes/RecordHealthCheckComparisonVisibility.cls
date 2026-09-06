/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Owns the per-Check comparison visibility setting
 * (ComparisonDisplayMode__c). The setting is presentation only: it decides
 * which of Found and Expected the Lightning card may render. It never changes
 * evaluation, the stored Found and Expected values, merge-token data,
 * diagnostics, events, or API results, and it is not a security control.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckComparisonVisibility {
  public static final String AUTOMATIC = 'AUTOMATIC';
  public static final String FOUND_ONLY = 'FOUND_ONLY';
  public static final String EXPECTED_ONLY = 'EXPECTED_ONLY';
  public static final String HIDDEN = 'HIDDEN';

  private static final Set<String> SUPPORTED_MODES = new Set<String>{
    AUTOMATIC,
    FOUND_ONLY,
    EXPECTED_ONLY,
    HIDDEN
  };

  /**
   * @return The supported comparison display modes.
   */
  public static Set<String> supportedModes() {
    return new Set<String>(SUPPORTED_MODES);
  }

  /**
   * Normalizes a configured value. Blank is equivalent to Automatic so metadata
   * created before this field existed keeps its current card behavior, and an
   * unrecognized value degrades to Automatic rather than hiding evidence.
   *
   * @param configuredValue Raw ComparisonDisplayMode__c value.
   * @return One supported comparison display mode.
   */
  public static String normalize(String configuredValue) {
    if (String.isBlank(configuredValue)) {
      return AUTOMATIC;
    }
    String normalized = configuredValue.trim().toUpperCase();
    return SUPPORTED_MODES.contains(normalized) ? normalized : AUTOMATIC;
  }

  /**
   * @param configuredValue Raw ComparisonDisplayMode__c value.
   * @return true when a populated value is not a supported mode.
   */
  public static Boolean isUnsupported(String configuredValue) {
    return String.isNotBlank(configuredValue) &&
      !SUPPORTED_MODES.contains(configuredValue.trim().toUpperCase());
  }

  /**
   * A Hidden Check that fails with no message, Fix Message, or Action URL
   * leaves the user with a bare failure and nothing to act on. This is an
   * authoring warning, never a reason to reject evaluation.
   *
   * @param check Check metadata under validation.
   * @return true when Hidden is configured without any explanation.
   */
  public static Boolean hidesEvidenceWithoutGuidance(
    Record_Health_Check__mdt check
  ) {
    if (normalize(check.ComparisonDisplayMode__c) != HIDDEN) {
      return false;
    }
    return String.isBlank(check.FailureMessage__c) &&
      String.isBlank(check.FixMessage__c) &&
      String.isBlank(check.ActionUrl__c);
  }
}
