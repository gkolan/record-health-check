/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** The complete allowed list for product-qualified Framework tokens. */
public class RecordHealthCheckTokenRegistry {
  public static final Set<String> NAMESPACES = new Set<String>{
    'record',
    'rhcCheck',
    'rhcSet',
    'rhcResult',
    'rhcRun'
  };
  public static final Set<String> CHECK_PROPERTIES = new Set<String>{
    'developerName',
    'masterLabel',
    'checkTitle',
    'checkDescription',
    'category',
    'evaluationType',
    'failureSeverity',
    'evaluationOrder'
  };
  public static final Set<String> SET_PROPERTIES = new Set<String>{
    'developerName',
    'masterLabel',
    'cardTitle',
    'cardSubtitle',
    'objectApiName'
  };
  public static final Set<String> RESULT_PROPERTIES = new Set<String>{
    'status',
    'foundValue',
    'foundValuePluralSuffix',
    'expectedValue',
    'failedRecordCount',
    'totalRecordCount',
    'reasonCode'
  };
  public static final Set<String> RUN_PROPERTIES = new Set<String>{
    'runId',
    'source',
    'startedAt',
    'completedAt',
    'durationMs'
  };

  public static Boolean contains(String namespaceName, String property) {
    if (namespaceName == 'record') {
      return String.isNotBlank(property);
    }
    if (namespaceName == 'rhcCheck') {
      return CHECK_PROPERTIES.contains(property);
    }
    if (namespaceName == 'rhcSet') {
      return SET_PROPERTIES.contains(property);
    }
    if (namespaceName == 'rhcResult') {
      return RESULT_PROPERTIES.contains(property);
    }
    if (namespaceName == 'rhcRun') {
      return RUN_PROPERTIES.contains(property);
    }
    return false;
  }
}
