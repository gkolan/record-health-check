/** Discovers plugin definitions and normalizes their configured JSON values. */
public with sharing class RecordHealthCheckPluginDefinitionService {
  /** Returns a detached normalized map governed by the supplied definition. */
  public static Map<String, Object> normalize(
    RecordHealthCheckPluginDefinition definition,
    String parametersJson
  ) {
    if (definition == null) {
      throw new DefinitionFailureException(
        'The plugin returned no definition.'
      );
    }
    RecordHealthCheckPluginDefinition stable = definition.snapshot();
    String source = String.isBlank(parametersJson) ? '{}' : parametersJson;
    rejectDuplicateKeys(source);

    Object parsed;
    try {
      parsed = JSON.deserializeUntyped(source);
    } catch (JSONException ex) {
      throw invalid('Apex parameters must be valid JSON.');
    }
    if (!(parsed instanceof Map<String, Object>)) {
      throw invalid('Apex parameters must be a JSON object.');
    }
    Map<String, Object> supplied = (Map<String, Object>) parsed;
    Map<String, Object> normalized = new Map<String, Object>();

    for (String suppliedKey : supplied.keySet()) {
      if (stable.parameter(suppliedKey) == null) {
        throw invalid('Apex parameters contain an unknown key.');
      }
    }
    normalizeDeclaredParameters(stable, supplied, normalized);
    return normalized;
  }

  private static void normalizeDeclaredParameters(
    RecordHealthCheckPluginDefinition stable,
    Map<String, Object> supplied,
    Map<String, Object> normalized
  ) {
    for (String key : stable.parameterKeys()) {
      RecordHealthCheckPluginDefinition.ParameterDefinition parameter = stable.parameter(
        key
      );
      if (!supplied.containsKey(key)) {
        if (parameter.hasDefault) {
          normalized.put(key, copyScalar(parameter.defaultValue));
        } else if (parameter.required) {
          throw invalid('A required Apex parameter is missing.');
        }
        continue;
      }
      Object value = supplied.get(key);
      if (value == null) {
        if (!parameter.nullable) {
          throw invalid('An Apex parameter does not allow null.');
        }
        normalized.put(key, null);
        continue;
      }
      normalized.put(key, normalizeValue(parameter, value));
    }
  }

  private static Object normalizeValue(
    RecordHealthCheckPluginDefinition.ParameterDefinition parameter,
    Object value
  ) {
    if (parameter.typeName == 'INTEGER') {
      return normalizeInteger(parameter, value);
    }
    if (parameter.typeName == 'BOOLEAN') {
      if (!(value instanceof Boolean)) {
        throw invalid('An Apex parameter has the wrong type.');
      }
      return value;
    }
    if (!(value instanceof String)) {
      throw invalid('An Apex parameter has the wrong type.');
    }
    String stringValue = (String) value;
    if (parameter.typeName == 'CHOICE') {
      if (!parameter.choices.contains(stringValue)) {
        throw invalid('An Apex parameter is not an allowed choice.');
      }
    } else if (
      parameter.typeName == 'STRING' &&
      stringValue.length() > parameter.maxLength
    ) {
      throw invalid('An Apex parameter exceeds its declared maximum length.');
    }
    return stringValue;
  }

  private static Integer normalizeInteger(
    RecordHealthCheckPluginDefinition.ParameterDefinition parameter,
    Object value
  ) {
    Decimal numeric;
    if (
      value instanceof Integer ||
      value instanceof Long ||
      value instanceof Decimal
    ) {
      numeric = Decimal.valueOf(String.valueOf(value));
    } else {
      throw invalid('An Apex parameter has the wrong type.');
    }
    if (numeric.scale() > 0 && numeric.stripTrailingZeros().scale() > 0) {
      throw invalid('An integer Apex parameter must be integral.');
    }
    Integer integerValue;
    try {
      integerValue = Integer.valueOf(String.valueOf(numeric.setScale(0)));
    } catch (Exception ex) {
      throw invalid(
        'An integer Apex parameter is outside the supported range.'
      );
    }
    if (
      (parameter.minValue != null && integerValue < parameter.minValue) ||
      (parameter.maxValue != null &&
      integerValue > parameter.maxValue)
    ) {
      throw invalid(
        'An integer Apex parameter is outside its declared bounds.'
      );
    }
    return integerValue;
  }

  private static void rejectDuplicateKeys(String source) {
    try {
      JSONParser parser = JSON.createParser(source);
      Set<String> rootKeys = new Set<String>();
      Integer depth = 0;
      while (parser.nextToken() != null) {
        JSONToken token = parser.getCurrentToken();
        if (token == JSONToken.START_OBJECT || token == JSONToken.START_ARRAY) {
          depth++;
        } else if (
          token == JSONToken.END_OBJECT ||
          token == JSONToken.END_ARRAY
        ) {
          depth--;
        } else if (token == JSONToken.FIELD_NAME && depth == 1) {
          String key = parser.getText();
          if (rootKeys.contains(key)) {
            throw invalid('Apex parameter keys must be unique.');
          }
          rootKeys.add(key);
        }
      }
    } catch (InvalidParametersException ex) {
      throw ex;
    } catch (JSONException ex) {
      throw invalid('Apex parameters must be valid JSON.');
    }
  }

  private static Object copyScalar(Object value) {
    return value;
  }

  private static InvalidParametersException invalid(String message) {
    return new InvalidParametersException(message);
  }

  /** Definition discovery or schema failure. */
  public class DefinitionFailureException extends Exception {
  }

  /** Deterministic supplied-parameter failure. */
  public class InvalidParametersException extends Exception {
  }
}
