/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Resolves namespaced template tokens from their runtime merge context.
 * SPDX-License-Identifier: Apache-2.0
 */
public class RecordHealthCheckTemplateValueResolver {
  public static Object valueFor(
    RecordHealthCheckToken token,
    RecordHealthCheckMergeContext context
  ) {
    if (context == null) {
      unavailable(token, 'Merge context is unavailable.');
    }
    if (token.namespaceName == 'record') {
      if (context.record == null) {
        unavailable(token, 'The record is not available.');
      }
      return resolveFieldPath(context.record, token.propertyPath);
    }
    if (token.namespaceName == 'rhcCheck') {
      if (context.check == null) {
        unavailable(token, 'Check metadata is not available.');
      }
      return checkValue(context.check, token.propertyPath);
    }
    if (token.namespaceName == 'rhcSet') {
      if (context.checkSet == null) {
        unavailable(token, 'Check Set metadata is not available.');
      }
      return setValue(context.checkSet, token.propertyPath);
    }
    if (token.namespaceName == 'rhcResult') {
      if (!context.resultFinalized || context.result == null) {
        unavailable(token, 'The result is not finalized.');
      }
      return resultValue(context, token.propertyPath);
    }
    if (token.namespaceName == 'rhcRun') {
      if (context.run == null) {
        unavailable(token, 'The run context is not available.');
      }
      return runValue(context.run, token.propertyPath);
    }
    unavailable(token, 'The token namespace is not supported.');
    return null;
  }

  public static Object resolveFieldPath(SObject record, String fieldPath) {
    List<String> parts = fieldPath.split('\\.');
    if (parts.size() > 6) {
      unavailable(
        new RecordHealthCheckToken(
          '{!record.' + fieldPath + '}',
          'record',
          fieldPath,
          0,
          0
        ),
        'Record relationship depth exceeds five.'
      );
    }
    SObject current = record;
    for (Integer i = 0; i < parts.size() - 1; i++) {
      current = current.getSObject(parts[i]);
      if (current == null) {
        return null;
      }
    }
    return current.get(parts[parts.size() - 1]);
  }

  public static Object checkValue(
    Record_Health_Check__mdt check,
    String property
  ) {
    if (property == 'developerName') {
      return check.DeveloperName;
    }
    if (property == 'masterLabel') {
      return check.MasterLabel;
    }
    if (property == 'checkTitle') {
      return check.CheckTitle__c;
    }
    if (property == 'checkDescription') {
      return check.CheckDescription__c;
    }
    if (property == 'category') {
      return displayLabel(String.valueOf(dynamicGet(check, 'Category__c')));
    }
    if (property == 'evaluationType') {
      return displayLabel(String.valueOf(check.EvaluationType__c));
    }
    if (property == 'failureSeverity') {
      return displayLabel(String.valueOf(check.FailureSeverity__c));
    }
    if (property == 'evaluationOrder') {
      return check.EvaluationOrder__c;
    }
    return null;
  }

  public static Object setValue(SObject checkSet, String property) {
    if (property == 'developerName') {
      return dynamicGet(checkSet, 'DeveloperName');
    }
    if (property == 'masterLabel') {
      return dynamicGet(checkSet, 'MasterLabel');
    }
    if (property == 'cardTitle') {
      return dynamicGet(checkSet, 'CardTitle__c');
    }
    if (property == 'cardSubtitle') {
      return dynamicGet(checkSet, 'CardSubtitle__c');
    }
    if (property == 'objectApiName') {
      return dynamicGet(checkSet, 'ObjectApiName__c');
    }
    return null;
  }

  public static Object resultValue(
    RecordHealthCheckMergeContext context,
    String property
  ) {
    if (property == 'status') {
      return context.result.status;
    }
    if (property == 'foundValue') {
      return context.result.actualValue;
    }
    if (property == 'foundValuePluralSuffix') {
      if (context.failedRecordCount != null) {
        return context.failedRecordCount == 1 ? '' : 's';
      }
      return RecordHealthCheckDisplayFormat.isDisplayedNumberOne(
          context.result.actualValue
        )
        ? ''
        : 's';
    }
    if (property == 'expectedValue') {
      return context.result.expectedValue;
    }
    if (property == 'failedRecordCount') {
      return context.failedRecordCount;
    }
    if (property == 'totalRecordCount') {
      return context.totalRecordCount;
    }
    if (property == 'reasonCode') {
      return context.result.reasonCode;
    }
    return null;
  }

  public static Object runValue(
    RecordHealthCheckRunContext run,
    String property
  ) {
    if (property == 'runId') {
      return run.runId;
    }
    if (property == 'source') {
      return run.source;
    }
    if (property == 'startedAt') {
      return run.startedAt;
    }
    if (property == 'completedAt') {
      return run.completedAt;
    }
    if (property == 'durationMs') {
      return run.durationMs;
    }
    return null;
  }

  public static Object dynamicGet(SObject source, String fieldName) {
    try {
      return source.get(fieldName);
    } catch (Exception ex) {
      return null;
    }
  }

  private static void unavailable(
    RecordHealthCheckToken token,
    String message
  ) {
    RecordHealthCheckTemplateService.TemplateException ex = new RecordHealthCheckTemplateService.TemplateException(
      message + ' Token: ' + token.expression
    );
    ex.reasonCode = 'TOKEN_NOT_AVAILABLE_IN_PHASE';
    ex.token = token.expression;
    throw ex;
  }

  private static String displayLabel(String stored) {
    if (String.isBlank(stored) || stored == 'null') {
      return '';
    }
    List<String> words = stored.toLowerCase().replace('_', ' ').split(' ');
    List<String> labels = new List<String>();
    for (String word : words) {
      if (String.isNotBlank(word)) {
        labels.add(word.left(1).toUpperCase() + word.substring(1));
      }
    }
    return String.join(labels, ' ');
  }
}
