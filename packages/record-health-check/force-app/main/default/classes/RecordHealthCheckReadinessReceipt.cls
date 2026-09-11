/** Public, bounded readiness-receipt projection without record scope or values. */
global class RecordHealthCheckReadinessReceipt {
  /** SAVED, NOT_SAVED, NOT_REQUESTED, or NOT_ELIGIBLE. */
  global String receiptStatus;
  /** Created receipt identifier when saved. */
  global Id receiptId;
  /** Receipt expiry when saved. */
  global Datetime expiresAt;
  /** Fixed disclosure-safe warning when persistence fails. */
  global String warning;
}
