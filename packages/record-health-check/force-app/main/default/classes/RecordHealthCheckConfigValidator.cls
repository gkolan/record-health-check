/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Shared validation helpers used at runtime and in CI; they do not change org data. */
public with sharing class RecordHealthCheckConfigValidator {
  private static Map<String, RecordHealthCheckPlugin> validatedPluginInstances = new Map<String, RecordHealthCheckPlugin>();
  public static RecordHealthCheckTokenIssue firstTemplateIssue(
    Record_Health_Check__mdt check
  ) {
    if (check == null) {
      return null;
    }
    List<List<Object>> templates = new List<List<Object>>{
      new List<Object>{
        check.FailureMessage__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        check.UnableToEvaluateMessage__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        check.ApplicabilityNotMetMessage__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        check.FixMessage__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        check.ActionLabel__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        check.DisplayFoundText__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        check.DisplayExpectedText__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        check.ActionUrl__c,
        RecordHealthCheckTemplateService.SURFACE_URL
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
    for (List<Object> entry : templates) {
      List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
        (String) entry[0],
        (String) entry[1]
      );
      if (!issues.isEmpty()) {
        return issues[0];
      }
    }
    return null;
  }

  public static Boolean isValidObjectApiName(String objectApiName) {
    return String.isNotBlank(objectApiName) &&
      RecordHealthCheckDescribeCache.containsObject(objectApiName);
  }

  public static Boolean isValidApexPlugin(String className) {
    return validateApexPlugin(className, null);
  }

  /** Validates and caches a plugin for one exact Check configuration. */
  public static Boolean isValidApexPlugin(Record_Health_Check__mdt check) {
    return check != null &&
      validateApexPlugin(check.ApexClass__c, pluginCacheKey(check));
  }

  private static Boolean validateApexPlugin(String className, String cacheKey) {
    if (String.isBlank(className)) {
      return false;
    }
    try {
      Type pluginType = RecordHealthCheckApexPluginResolver.configuredType(
        className
      );
      RecordHealthCheckPlugin instance = RecordHealthCheckPluginDispatch.instantiate(
        pluginType
      );
      if (instance == null) {
        return false;
      }
      if (cacheKey != null) {
        validatedPluginInstances.put(cacheKey, instance);
      }
      return true;
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (Exception ex) {
      return false;
    }
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

  /** Releases a validated plugin instance when later validation rejects its Check. */
  public static void discardValidatedPlugin(Record_Health_Check__mdt check) {
    if (check != null) {
      validatedPluginInstances.remove(pluginCacheKey(check));
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
