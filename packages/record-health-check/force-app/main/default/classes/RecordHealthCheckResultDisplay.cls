/**
 * Optional human-facing rendering derived from an Evaluation Result.
 */
global class RecordHealthCheckResultDisplay {
  @AuraEnabled
  /** Rendered outcome message. */
  global String renderedMessage;
  @AuraEnabled
  /** Rendered remediation guidance. */
  global String renderedFix;
  @AuraEnabled
  /** Locale-formatted Found value. */
  global String foundDisplayValue;
  @AuraEnabled
  /** Locale-formatted Expected value. */
  global String expectedDisplayValue;
  @AuraEnabled
  /** Display-format token used for Found. */
  global String foundDisplayFormat;
  @AuraEnabled
  /** Display-format token used for Expected. */
  global String expectedDisplayFormat;
  @AuraEnabled
  /** Currency ISO code used for Found. */
  global String foundCurrencyIsoCode;
  @AuraEnabled
  /** Currency ISO code used for Expected. */
  global String expectedCurrencyIsoCode;
  @AuraEnabled
  /** Optional remediation-link label. */
  global String actionLabel;
  @AuraEnabled
  /** Sanitized remediation URL. */
  global String actionUrl;
  @AuraEnabled
  /** Diagnostics visible only to entitled viewers. */
  global RecordHealthCheckAdminDetail adminDetail;
}
