/** Fluent, snapshot-capable definition of a subscriber plugin contract. */
global class RecordHealthCheckPluginDefinition {
  private static final Integer MAX_PARAMETERS = 50;
  private static final Integer MAX_LABEL_LENGTH = 80;
  private static final Integer MAX_HELP_LENGTH = 512;
  private static final Integer MAX_CHOICES = 50;
  private static final Integer MAX_CHOICE_LENGTH = 255;
  private static final Integer MAX_STRING_LENGTH = 4096;
  private Map<String, ParameterDefinition> parametersByKey;
  private List<String> parameterOrder;
  private Integer declaredMaxScopeSize;
  private Boolean declaredBulkSafe;
  private String declaredEstimatedCost;

  /** Package-visible immutable-by-convention parameter description. */
  public class ParameterDefinition {
    public String key;
    public String typeName;
    public Object defaultValue;
    public Boolean hasDefault = false;
    public Integer minValue;
    public Integer maxValue;
    public Integer maxLength;
    public List<String> choices;
    public Boolean required = false;
    public Boolean nullable = false;
    public String label;
    public String helpText = '';

    private ParameterDefinition copy() {
      ParameterDefinition result = new ParameterDefinition();
      result.key = key;
      result.typeName = typeName;
      result.defaultValue = defaultValue;
      result.hasDefault = hasDefault;
      result.minValue = minValue;
      result.maxValue = maxValue;
      result.maxLength = maxLength;
      result.choices = choices == null ? null : new List<String>(choices);
      result.required = required;
      result.nullable = nullable;
      result.label = label;
      result.helpText = helpText;
      return result;
    }
  }

  /** Creates an empty plugin definition. */
  global RecordHealthCheckPluginDefinition() {
    parametersByKey = new Map<String, ParameterDefinition>();
    parameterOrder = new List<String>();
  }

  /** Declares an integer parameter with inclusive bounds. */
  global RecordHealthCheckPluginDefinition integerParameter(
    String key,
    Integer defaultValue,
    Integer minValue,
    Integer maxValue
  ) {
    if (minValue != null && maxValue != null && minValue > maxValue) {
      fail('Integer minimum must not exceed its maximum.');
    }
    if (
      defaultValue != null &&
      ((minValue != null && defaultValue < minValue) ||
      (maxValue != null &&
      defaultValue > maxValue))
    ) {
      fail('Integer default must be within its declared bounds.');
    }
    ParameterDefinition parameter = add(key, 'INTEGER', defaultValue);
    parameter.minValue = minValue;
    parameter.maxValue = maxValue;
    return this;
  }

  /** Declares a parameter whose value must be one listed choice. */
  global RecordHealthCheckPluginDefinition choiceParameter(
    String key,
    String defaultValue,
    List<String> choices
  ) {
    if (choices == null || choices.isEmpty() || choices.size() > MAX_CHOICES) {
      fail('Choice parameters require between 1 and 50 choices.');
    }
    Set<String> unique = new Set<String>();
    List<String> copied = new List<String>();
    for (String choice : choices) {
      if (
        String.isBlank(choice) ||
        choice.length() > MAX_CHOICE_LENGTH ||
        unique.contains(choice)
      ) {
        fail(
          'Choices must be unique, nonblank strings of at most 255 characters.'
        );
      }
      unique.add(choice);
      copied.add(choice);
    }
    if (defaultValue != null && !unique.contains(defaultValue)) {
      fail('Choice default must be one of the declared choices.');
    }
    ParameterDefinition parameter = add(key, 'CHOICE', defaultValue);
    parameter.choices = copied;
    return this;
  }

  /** Declares a bounded string parameter. */
  global RecordHealthCheckPluginDefinition stringParameter(
    String key,
    String defaultValue,
    Integer maxLength
  ) {
    if (maxLength == null || maxLength < 1 || maxLength > MAX_STRING_LENGTH) {
      fail('String maximum length must be between 1 and 4096.');
    }
    if (defaultValue != null && defaultValue.length() > maxLength) {
      fail('String default exceeds its declared maximum length.');
    }
    ParameterDefinition parameter = add(key, 'STRING', defaultValue);
    parameter.maxLength = maxLength;
    return this;
  }

  /** Declares a boolean parameter. */
  global RecordHealthCheckPluginDefinition booleanParameter(
    String key,
    Boolean defaultValue
  ) {
    add(key, 'BOOLEAN', defaultValue);
    return this;
  }

  /** Marks an existing parameter as required or optional. */
  global RecordHealthCheckPluginDefinition required(String key, Boolean value) {
    existing(key).required = value == true;
    return this;
  }

  /** Controls whether explicit JSON null is accepted for an existing parameter. */
  global RecordHealthCheckPluginDefinition nullable(String key, Boolean value) {
    existing(key).nullable = value == true;
    return this;
  }

  /** Supplies the administrator-facing label and help text. */
  global RecordHealthCheckPluginDefinition describe(
    String key,
    String label,
    String helpText
  ) {
    if (String.isBlank(label) || label.length() > MAX_LABEL_LENGTH) {
      fail('Parameter label must be nonblank and at most 80 characters.');
    }
    if (helpText != null && helpText.length() > MAX_HELP_LENGTH) {
      fail('Parameter help text must be at most 512 characters.');
    }
    ParameterDefinition parameter = existing(key);
    parameter.label = label;
    parameter.helpText = helpText == null ? '' : helpText;
    return this;
  }

  /** Declares advisory scope capacity for the later scheduling contract. */
  global RecordHealthCheckPluginDefinition capacity(
    Integer maxScopeSize,
    Boolean bulkSafe,
    String estimatedCost
  ) {
    if (maxScopeSize != null && (maxScopeSize < 1 || maxScopeSize > 200)) {
      fail('Maximum scope size must be between 1 and 200.');
    }
    if (bulkSafe == false && maxScopeSize == null) {
      fail('A non-bulk-safe definition requires a maximum scope size.');
    }
    if (
      estimatedCost != null &&
      !new Set<String>{ 'LOW', 'MEDIUM', 'HIGH' }.contains(estimatedCost)
    ) {
      fail('Estimated cost must be LOW, MEDIUM, or HIGH.');
    }
    declaredMaxScopeSize = maxScopeSize;
    declaredBulkSafe = bulkSafe;
    declaredEstimatedCost = estimatedCost;
    return this;
  }

  /** Returns a detached copy consumed by runtime normalization. */
  public RecordHealthCheckPluginDefinition snapshot() {
    RecordHealthCheckPluginDefinition result = new RecordHealthCheckPluginDefinition();
    for (String key : parameterOrder) {
      result.parameterOrder.add(key);
      result.parametersByKey.put(key, parametersByKey.get(key).copy());
    }
    result.declaredMaxScopeSize = declaredMaxScopeSize;
    result.declaredBulkSafe = declaredBulkSafe;
    result.declaredEstimatedCost = declaredEstimatedCost;
    return result;
  }

  /** Returns ordered keys for package runtime validation. */
  public List<String> parameterKeys() {
    return new List<String>(parameterOrder);
  }

  /** Returns one detached parameter definition for package runtime validation. */
  public ParameterDefinition parameter(String key) {
    ParameterDefinition value = parametersByKey.get(key);
    return value == null ? null : value.copy();
  }

  /** Returns the declared applicable-scope cap, or null when none was declared. */
  public Integer maxScopeSize() {
    return declaredMaxScopeSize;
  }

  /** Returns the provider's bulk-safety declaration. */
  public Boolean bulkSafe() {
    return declaredBulkSafe;
  }

  /** Returns the provider's advisory LOW, MEDIUM, or HIGH cost. */
  public String estimatedCost() {
    return declaredEstimatedCost;
  }

  private ParameterDefinition add(
    String key,
    String typeName,
    Object defaultValue
  ) {
    validateKey(key);
    if (parametersByKey.containsKey(key)) {
      fail('Parameter keys must be unique.');
    }
    if (parameterOrder.size() >= MAX_PARAMETERS) {
      fail('A plugin definition may declare at most 50 parameters.');
    }
    ParameterDefinition parameter = new ParameterDefinition();
    parameter.key = key;
    parameter.label = key;
    parameter.typeName = typeName;
    parameter.defaultValue = defaultValue;
    parameter.hasDefault = defaultValue != null;
    parametersByKey.put(key, parameter);
    parameterOrder.add(key);
    return parameter;
  }

  private ParameterDefinition existing(String key) {
    ParameterDefinition result = parametersByKey.get(key);
    if (result == null) {
      fail('A parameter modifier must reference an existing key.');
    }
    return result;
  }

  private static void validateKey(String key) {
    if (
      String.isBlank(key) || !Pattern.matches('[A-Za-z][A-Za-z0-9_]{0,39}', key)
    ) {
      fail('Parameter key has an invalid format.');
    }
  }

  private static void fail(String message) {
    throw new DefinitionException(message);
  }

  /** Malformed subscriber definition. */
  global class DefinitionException extends Exception {
  }
}
