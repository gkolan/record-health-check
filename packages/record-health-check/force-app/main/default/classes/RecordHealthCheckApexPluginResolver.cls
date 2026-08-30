/** Resolves one configured Apex Check implementation and its parameters. */
public with sharing class RecordHealthCheckApexPluginResolver {
  /** Returns a validated plugin instance, reusing the configuration cache. */
  public static RecordHealthCheckPlugin resolve(
    Record_Health_Check__mdt check
  ) {
    Type evaluatorType = configuredType(check.ApexClass__c);
    Object instance = RecordHealthCheckConfigValidator.takeValidatedPlugin(
      check
    );
    if (instance == null) {
      instance = instantiatePlugin(evaluatorType);
    }
    return requireCheck(instance);
  }

  /** Returns the configured JSON object, or an empty parameter map. */
  public static Map<String, Object> parameters(Record_Health_Check__mdt check) {
    if (String.isBlank(check.ApexParametersJson__c)) {
      return new Map<String, Object>();
    }
    try {
      Object parsed = JSON.deserializeUntyped(check.ApexParametersJson__c);
      if (!(parsed instanceof Map<String, Object>)) {
        throw configurationError(
          'INVALID_APEX_PARAMETERS',
          'ApexParametersJson__c must be a JSON object.'
        );
      }
      return (Map<String, Object>) parsed;
    } catch (JSONException ex) {
      throw configurationError('INVALID_APEX_PARAMETERS', ex.getMessage());
    }
  }

  public static Type configuredType(String className) {
    if (String.isBlank(className)) {
      throw configurationError(
        'APEX_CLASS_NOT_FOUND',
        'Apex Class Name is blank.'
      );
    }
    String normalized = className.trim();
    Type evaluatorType;
    if (normalized.contains('.')) {
      evaluatorType = Type.forName(
        normalized.substringBefore('.'),
        normalized.substringAfter('.')
      );
    } else {
      evaluatorType = Type.forName(normalized);
      if (evaluatorType == null) {
        // Installed-package code resolves its own namespace first. An explicit
        // empty namespace is required for subscriber-authored global plugins.
        evaluatorType = Type.forName('', normalized);
      }
    }
    if (evaluatorType == null) {
      throw configurationError(
        'APEX_CLASS_NOT_FOUND',
        'Class "' + normalized + '" was not found.'
      );
    }
    return evaluatorType;
  }

  private static Object instantiatePlugin(Type evaluatorType) {
    try {
      return RecordHealthCheckPluginDispatch.instantiate(evaluatorType);
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (Exception ex) {
      throw configurationError(
        RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED,
        ex.getMessage()
      );
    }
  }

  private static RecordHealthCheckPlugin requireCheck(Object instance) {
    if (!(instance instanceof RecordHealthCheckPlugin)) {
      throw configurationError(
        RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID,
        'The configured class does not implement RecordHealthCheckPlugin.'
      );
    }
    return (RecordHealthCheckPlugin) instance;
  }

  private static PluginConfigurationException configurationError(
    String reasonCode,
    String message
  ) {
    PluginConfigurationException error = new PluginConfigurationException(
      message
    );
    error.reasonCode = reasonCode;
    return error;
  }

  /** Stable configuration failure consumed by the Apex adapter. */
  public class PluginConfigurationException extends Exception {
    public String reasonCode;
  }
}
