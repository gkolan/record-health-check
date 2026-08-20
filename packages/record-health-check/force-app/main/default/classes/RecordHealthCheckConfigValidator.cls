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
      validatedPluginInstances.put(className, instance);
      return true;
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (Exception ex) {
      return false;
    }
  }

  public static RecordHealthCheckPlugin takeValidatedPlugin(String className) {
    RecordHealthCheckPlugin instance = validatedPluginInstances.get(className);
    validatedPluginInstances.remove(className);
    return instance;
  }

  /** Releases a validated plugin instance when later validation rejects its Check. */
  public static void discardValidatedPlugin(String className) {
    if (String.isNotBlank(className)) {
      validatedPluginInstances.remove(className);
    }
  }

  @TestVisible
  private static void cachePluginForTest(
    String className,
    RecordHealthCheckPlugin instance
  ) {
    validatedPluginInstances.put(className, instance);
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
