/** Serializable administrator control description for one plugin parameter. */
global class RecordHealthCheckPreviewParameter {
  /** Stable JSON parameter key. */
  global String key;
  /** INTEGER, CHOICE, STRING, or BOOLEAN. */
  global String typeName;
  /** Provider-declared default, when present. */
  global Object defaultValue;
  /** Normalized value used by the current preview. */
  global Object currentValue;
  /** Whether the provider declared a default. */
  global Boolean hasDefault;
  /** Inclusive integer minimum. */
  global Integer minValue;
  /** Inclusive integer maximum. */
  global Integer maxValue;
  /** Maximum string length. */
  global Integer maxLength;
  /** Case-sensitive choice values. */
  global List<String> choices;
  /** Whether omission is invalid when no default exists. */
  global Boolean required;
  /** Whether an explicit JSON null is accepted. */
  global Boolean nullable;
  /** Administrator-facing field label. */
  global String label;
  /** Administrator-facing field help. */
  global String helpText;
}
