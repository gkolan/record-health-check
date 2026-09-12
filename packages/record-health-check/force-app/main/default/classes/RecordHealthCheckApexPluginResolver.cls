/** Resolves one configured Apex Check implementation and its parameters. */
public with sharing class RecordHealthCheckApexPluginResolver {
  @TestVisible
  private static Exception configuredTypeFailureForTest;

  /** Returns a validated plugin instance, reusing the configuration cache. */
  public static RecordHealthCheckPlugin resolve(
    Record_Health_Check__mdt check
  ) {
    Type evaluatorType = configuredType(check.ApexClass__c);
    RecordHealthCheckPlugin instance = RecordHealthCheckConfigValidator.takeValidatedPlugin(
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

  /** Applies a provider definition when the resolved plugin declares one. */
  public static Map<String, Object> parameters(
    Record_Health_Check__mdt check,
    RecordHealthCheckPlugin plugin
  ) {
    return configuration(check, plugin).parameters;
  }

  /** Resolves normalized parameters and the same provider snapshot together. */
  public static PluginConfiguration configuration(
    Record_Health_Check__mdt check,
    RecordHealthCheckPlugin plugin
  ) {
    PluginConfiguration result = new PluginConfiguration();
    if (!(plugin instanceof RecordHealthCheckPluginDefinitionSource)) {
      result.parameters = parameters(check);
      return result;
    }
    try {
      RecordHealthCheckPluginDefinition definition = RecordHealthCheckPluginDispatch.define(
        plugin
      );
      result.definition = definition == null ? null : definition.snapshot();
      result.parameters = RecordHealthCheckPluginDefinitionService.normalize(
        definition,
        check.ApexParametersJson__c
      );
      return result;
    } catch (RecordHealthCheckResourcePlan.BudgetException ex) {
      throw ex;
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (RecordHealthCheckPluginDefinitionService.InvalidParametersException ex) {
      throw configurationError(
        RecordHealthCheckReasonCodes.INVALID_APEX_PARAMETERS,
        ex.getMessage(),
        ex
      );
    } catch (Exception ex) {
      throw configurationError(
        RecordHealthCheckReasonCodes.PLUGIN_DEFINITION_INVALID,
        ex.getMessage(),
        ex
      );
    }
  }

  /** One-definition-discovery result consumed by the Apex evaluator. */
  public class PluginConfiguration {
    public Map<String, Object> parameters;
    public RecordHealthCheckPluginDefinition definition;
  }

  public static Type configuredType(String className) {
    if (String.isBlank(className)) {
      throw configurationError(
        RecordHealthCheckReasonCodes.APEX_CLASS_NOT_FOUND,
        'Apex Class Name is blank.'
      );
    }
    String normalized = className.trim();
    if (
      !RecordHealthCheckConfigValidator.isValidApexClassNameSyntax(normalized)
    ) {
      throw configurationError(
        RecordHealthCheckReasonCodes.APEX_CLASS_INVALID,
        'Apex Class Name must be a class name or namespace-qualified class name.'
      );
    }
    Type evaluatorType;
    String loadFailureReason = RecordHealthCheckReasonCodes.APEX_CLASS_LOAD_FAILED;
    String loadFailureMessage = 'Apex Class Name could not be loaded.';
    try {
      if (configuredTypeFailureForTest != null) {
        throw configuredTypeFailureForTest;
      }
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
    } catch (Exception ex) {
      throw configurationError(loadFailureReason, loadFailureMessage, ex);
    }
    if (evaluatorType == null) {
      throw configurationError(
        RecordHealthCheckReasonCodes.APEX_CLASS_NOT_FOUND,
        'Class "' + normalized + '" was not found.'
      );
    }
    return evaluatorType;
  }

  private static RecordHealthCheckPlugin instantiatePlugin(Type evaluatorType) {
    try {
      return RecordHealthCheckPluginDispatch.instantiate(evaluatorType);
    } catch (RecordHealthCheckResourcePlan.BudgetException ex) {
      throw ex;
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (Exception ex) {
      throw configurationError(
        RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED,
        ex.getMessage(),
        ex
      );
    }
  }

  private static RecordHealthCheckPlugin requireCheck(
    RecordHealthCheckPlugin instance
  ) {
    if (instance == null) {
      throw configurationError(
        RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID,
        'The configured class does not implement RecordHealthCheckPlugin.'
      );
    }
    return instance;
  }

  private static PluginConfigurationException configurationError(
    String reasonCode,
    String message
  ) {
    return configurationError(reasonCode, message, null);
  }

  private static PluginConfigurationException configurationError(
    String reasonCode,
    String message,
    Exception originalException
  ) {
    PluginConfigurationException error = new PluginConfigurationException(
      message
    );
    error.reasonCode = reasonCode;
    if (originalException != null) {
      error.originalExceptionType = originalException.getTypeName();
      error.originalExceptionMessage = originalException.getMessage();
      error.originalStackTrace = originalException.getStackTraceString();
      error.originalLineNumber = originalException.getLineNumber();
    }
    return error;
  }

  /** Stable configuration failure consumed by the Apex adapter. */
  public class PluginConfigurationException extends Exception {
    public String reasonCode;
    public String originalExceptionType;
    public String originalExceptionMessage;
    public String originalStackTrace;
    public Integer originalLineNumber;
  }
}
