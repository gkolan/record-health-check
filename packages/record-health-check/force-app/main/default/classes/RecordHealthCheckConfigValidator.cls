/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Shared validation helpers used at runtime and in CI; they do not change org data. */
public with sharing class RecordHealthCheckConfigValidator {
  private static Map<String, RecordHealthCheckPlugin> validatedPluginInstances = new Map<String, RecordHealthCheckPlugin>();
  private static Map<String, RecordHealthCheckApexPluginResolver.PluginConfiguration> validatedPluginConfigurations = new Map<String, RecordHealthCheckApexPluginResolver.PluginConfiguration>();

  /** Structured result for one protected plugin validation attempt. */
  public class ApexPluginValidation {
    public Boolean isValid = false;
    public RecordHealthCheckPlugin instance;
    public String reasonCode;
    public String phase;
    public String configuredClassName;
    public String resolvedTypeIdentity;
    public Exception originalException;
    public RecordHealthCheckApexPluginResolver.PluginConfiguration configuration;
  }
  /**
   * Every template field on a Check, paired with the surface whose token rules
   * govern it. Declared once here because two validators walk the same fields:
   * the parser rules below, and RecordHealthCheckQueryTokenRules.
   *
   * @param check One Check's Custom Metadata record.
   * @return Entries of {template, surface}; never null.
   */
  public static List<List<Object>> templateSurfaces(
    Record_Health_Check__mdt check
  ) {
    if (check == null) {
      return new List<List<Object>>();
    }
    return new List<List<Object>>{
      new List<Object>{
        check.FailureMessage__c,
        RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE
      },
      new List<Object>{
        check.UnableToEvaluateMessage__c,
        RecordHealthCheckTokenSurfaces.UNABLE_MESSAGE
      },
      new List<Object>{
        check.ApplicabilityNotMetMessage__c,
        RecordHealthCheckTokenSurfaces.NOT_APPLICABLE_MESSAGE
      },
      new List<Object>{
        check.FixMessage__c,
        RecordHealthCheckTokenSurfaces.FIX_MESSAGE
      },
      new List<Object>{
        check.ActionLabel__c,
        RecordHealthCheckTokenSurfaces.ACTION_LABEL
      },
      new List<Object>{
        check.DisplayFoundText__c,
        RecordHealthCheckTokenSurfaces.DISPLAY_FOUND
      },
      new List<Object>{
        check.DisplayExpectedText__c,
        RecordHealthCheckTokenSurfaces.DISPLAY_EXPECTED
      },
      new List<Object>{
        check.ActionUrl__c,
        RecordHealthCheckTokenSurfaces.ACTION_URL
      },
      new List<Object>{
        check.SourceQuery__c,
        RecordHealthCheckTemplateService.SURFACE_SOQL
      },
      new List<Object>{
        check.ComparisonQuery__c,
        RecordHealthCheckTemplateService.SURFACE_SOQL
      },
      new List<Object>{
        check.ApplicabilityCountQuery__c,
        RecordHealthCheckTemplateService.SURFACE_SOQL
      }
    };
  }

  public static RecordHealthCheckTokenIssue firstTemplateIssue(
    Record_Health_Check__mdt check
  ) {
    if (check == null) {
      return null;
    }
    for (List<Object> entry : templateSurfaces(check)) {
      List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
        (String) entry[0],
        (String) entry[1]
      );
      if (!issues.isEmpty()) {
        return issues[0];
      }
    }
    return RecordHealthCheckQueryTokenRules.firstIssue(check);
  }

  public static Boolean isValidObjectApiName(String objectApiName) {
    return String.isNotBlank(objectApiName) &&
      RecordHealthCheckDescribeCache.containsObject(objectApiName);
  }

  public static Boolean isValidApexPlugin(String className) {
    return validateApexPlugin(className).isValid;
  }

  /** Validates and caches a plugin for one exact Check configuration. */
  public static Boolean isValidApexPlugin(Record_Health_Check__mdt check) {
    return validateApexPlugin(check).isValid;
  }

  /** Returns the exact result of validating one class name without caching it. */
  public static ApexPluginValidation validateApexPlugin(String className) {
    return inspectApexPlugin(className, null, null);
  }

  /** Validates and caches a typed plugin for one exact Check configuration. */
  public static ApexPluginValidation validateApexPlugin(
    Record_Health_Check__mdt check
  ) {
    if (check == null) {
      return failedPluginValidation(
        null,
        RecordHealthCheckReasonCodes.APEX_CLASS_NOT_FOUND,
        'PLUGIN_RESOLVE',
        null
      );
    }
    return inspectApexPlugin(check.ApexClass__c, pluginCacheKey(check), check);
  }

  /** Accepts only the supported simple or namespace-qualified class syntax. */
  public static Boolean isValidApexClassNameSyntax(String className) {
    return String.isNotBlank(className) &&
      Pattern.matches(
        '^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)?$',
        className.trim()
      );
  }

  private static ApexPluginValidation inspectApexPlugin(
    String className,
    String cacheKey,
    Record_Health_Check__mdt check
  ) {
    if (cacheKey != null) {
      validatedPluginInstances.remove(cacheKey);
      validatedPluginConfigurations.remove(cacheKey);
    }
    if (String.isBlank(className)) {
      return failedPluginValidation(
        className,
        RecordHealthCheckReasonCodes.APEX_CLASS_NOT_FOUND,
        'PLUGIN_RESOLVE',
        null
      );
    }
    ApexPluginValidation validation = new ApexPluginValidation();
    validation.configuredClassName = className.trim();
    Type pluginType;
    try {
      pluginType = RecordHealthCheckApexPluginResolver.configuredType(
        className
      );
      validation.resolvedTypeIdentity = String.valueOf(pluginType);
    } catch (RecordHealthCheckApexPluginResolver.PluginConfigurationException ex) {
      return failedPluginValidation(
        validation.configuredClassName,
        ex.reasonCode,
        'PLUGIN_RESOLVE',
        ex
      );
    }
    try {
      validation.instance = RecordHealthCheckPluginDispatch.instantiate(
        pluginType
      );
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (Exception ex) {
      return markPluginValidationFailed(
        validation,
        RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED,
        'PLUGIN_CONSTRUCT',
        ex
      );
    }
    if (validation.instance == null) {
      return markPluginValidationFailed(
        validation,
        RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID,
        'PLUGIN_RESOLVE',
        null
      );
    }
    if (check != null) {
      try {
        validation.configuration = RecordHealthCheckApexPluginResolver.configuration(
          check,
          validation.instance
        );
      } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
        throw ex;
      } catch (RecordHealthCheckApexPluginResolver.PluginConfigurationException ex) {
        return markPluginValidationFailed(
          validation,
          ex.reasonCode,
          ex.reasonCode ==
            RecordHealthCheckReasonCodes.PLUGIN_DEFINITION_INVALID
            ? 'PLUGIN_DEFINE'
            : 'PLUGIN_PARAMETERS',
          ex
        );
      }
    }
    validation.isValid = true;
    if (cacheKey != null) {
      validatedPluginInstances.put(cacheKey, validation.instance);
      validatedPluginConfigurations.put(cacheKey, validation.configuration);
    }
    return validation;
  }

  private static ApexPluginValidation failedPluginValidation(
    String className,
    String reasonCode,
    String phase,
    Exception originalException
  ) {
    ApexPluginValidation validation = new ApexPluginValidation();
    validation.configuredClassName = className;
    validation.reasonCode = reasonCode;
    validation.phase = phase;
    validation.originalException = originalException;
    return validation;
  }

  private static ApexPluginValidation markPluginValidationFailed(
    ApexPluginValidation validation,
    String reasonCode,
    String phase,
    Exception originalException
  ) {
    validation.reasonCode = reasonCode;
    validation.phase = phase;
    validation.originalException = originalException;
    return validation;
  }

  public static RecordHealthCheckPlugin takeValidatedPlugin(
    Record_Health_Check__mdt check
  ) {
    String cacheKey = pluginCacheKey(check);
    RecordHealthCheckPlugin instance = validatedPluginInstances.get(cacheKey);
    validatedPluginInstances.remove(cacheKey);
    if (instance == null && check != null) {
      // Test-only cache injection historically uses the class name directly.
      instance = validatedPluginInstances.get(check.ApexClass__c);
      validatedPluginInstances.remove(check.ApexClass__c);
    }
    return instance;
  }

  public static RecordHealthCheckApexPluginResolver.PluginConfiguration takeValidatedConfiguration(
    Record_Health_Check__mdt check
  ) {
    String cacheKey = pluginCacheKey(check);
    RecordHealthCheckApexPluginResolver.PluginConfiguration configuration = validatedPluginConfigurations.get(
      cacheKey
    );
    validatedPluginConfigurations.remove(cacheKey);
    return configuration;
  }

  public static Boolean validatedDefinitionWasProvided(
    Record_Health_Check__mdt check
  ) {
    return validatedPluginConfigurations.get(pluginCacheKey(check))
        ?.definition != null;
  }

  /** Returns a detached provider definition without consuming the evaluator cache. */
  public static RecordHealthCheckPluginDefinition validatedDefinition(
    Record_Health_Check__mdt check
  ) {
    RecordHealthCheckPluginDefinition definition = validatedPluginConfigurations.get(
        pluginCacheKey(check)
      )
      ?.definition;
    return definition == null ? null : definition.snapshot();
  }

  /** Returns detached normalized parameters without consuming the evaluator cache. */
  public static Map<String, Object> validatedParameters(
    Record_Health_Check__mdt check
  ) {
    Map<String, Object> parameters = validatedPluginConfigurations.get(
        pluginCacheKey(check)
      )
      ?.parameters;
    return parameters == null
      ? new Map<String, Object>()
      : new Map<String, Object>(parameters);
  }

  /** Releases a validated plugin instance when later validation rejects its Check. */
  public static void discardValidatedPlugin(Record_Health_Check__mdt check) {
    if (check != null) {
      validatedPluginInstances.remove(pluginCacheKey(check));
      validatedPluginConfigurations.remove(pluginCacheKey(check));
    }
  }

  @TestVisible
  private static void cachePluginForTest(
    String className,
    RecordHealthCheckPlugin instance
  ) {
    validatedPluginInstances.put(className, instance);
  }

  private static String pluginCacheKey(Record_Health_Check__mdt check) {
    if (check == null) {
      return null;
    }
    String identity = String.isBlank(check.QualifiedApiName)
      ? check.DeveloperName
      : check.QualifiedApiName;
    return String.valueOf(identity) +
      '|' +
      String.valueOf(check.ApexClass__c) +
      '|' +
      String.valueOf(check.ApexParametersJson__c);
  }

  public static Boolean isJsonObject(String jsonText) {
    if (String.isBlank(jsonText)) {
      return true;
    }
    try {
      Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
        jsonText
      );
      return parsed != null;
    } catch (Exception ex) {
      return false;
    }
  }
}
