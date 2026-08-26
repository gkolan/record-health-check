/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckController {
  @TestVisible
  private static RecordHealthCheckConfigService configService = new RecordHealthCheckConfigService();

  /**
   * Returns only the selected Check Set's configured run mode so the component
   * can avoid loading Check definitions for a Manual card before Run is selected.
   *
   * @param checkSetQualifiedApiName Namespace-safe name of the selected Check Set.
   * @return Run mode, Card Title, description, active Check count, and button presentation; or an empty map when blank or missing.
   * @throws AuraHandledException if shell configuration cannot be loaded safely.
   */
  @AuraEnabled
  public static Map<String, String> getCheckSetShellConfig(
    String checkSetQualifiedApiName
  ) {
    requireRunAccess();
    try {
      return configService.getCheckSetShellConfig(checkSetQualifiedApiName);
    } catch (Exception ex) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        null,
        checkSetQualifiedApiName,
        null,
        null,
        'SHELL_CONFIG_LOAD_FAILED',
        null,
        ex
      );
      throw buildAuraException(
        'LOAD_FAILED',
        'An unexpected error occurred loading the health check configuration.'
      );
    } finally {
      RecordHealthCheckLogger.flush();
    }
  }

  /**
   * Reports whether the record's object has active and/or inactive Check Sets.
   * Used when the LWC has no Check Set selected, so the setup banner can say
   * choose one, activate one, or create one.
   * Not cacheable: after an admin activates or creates a Check Set, the next
   * component load must see the fresh availability without waiting on the
   * Lightning Data Service cache.
   *
   * @param recordId Record whose object determines Check Set availability.
   * @return Active and inactive Check Set availability for the record's object.
   * @throws AuraHandledException if availability cannot be loaded safely.
   */
  @AuraEnabled
  public static RecordHealthCheckSetAvailability getCheckSetAvailabilityForRecord(
    Id recordId
  ) {
    requireRunAccess();
    if (recordId == null) {
      return new RecordHealthCheckSetAvailability();
    }
    try {
      return configService.getCheckSetAvailabilityForObject(
        RecordHealthCheckDescribeCache.objectApiName(recordId)
      );
    } catch (Exception ex) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        null,
        null,
        recordId,
        null,
        'AVAILABILITY_LOOKUP_FAILED',
        null,
        ex
      );
      throw buildAuraException(
        'LOAD_FAILED',
        'An unexpected error occurred loading health check availability.'
      );
    } finally {
      RecordHealthCheckLogger.flush();
    }
  }

  /**
   * Returns Check Set display settings and ordered check definitions.
   * Not cacheable: metadata edits to Check Sets/Checks appear on the next
   * component load without requiring a page refresh.
   * Throws AuraHandledException for all component-level failures:
   * CONFIG_NOT_FOUND, CONFIG_INACTIVE, OBJECT_MISMATCH,
   * NO_RECORD_CONTEXT, NO_ACTIVE_CHECKS, and LOAD_FAILED for any
   * unexpected (non-ConfigException) error.
   *
   * @param checkSetQualifiedApiName Exact QualifiedApiName of the Check Set.
   * @param recordId Record for which definitions will be evaluated.
   * @param runId Optional client correlation identifier.
   * @return Display settings and ordered Check definitions.
   * @throws AuraHandledException for configuration or unexpected load failures.
   */
  @AuraEnabled
  public static RecordHealthCheckDefinitionResponse getCheckDefinitions(
    String checkSetQualifiedApiName,
    Id recordId,
    String runId
  ) {
    requireRunAccess();
    // Normalize at the controller boundary (the engine also normalizes in evaluate).
    checkSetQualifiedApiName = RecordHealthCheckLogger.normalizeIdentifier(
      checkSetQualifiedApiName,
      80
    );
    runId = RecordHealthCheckLogger.normalizeIdentifier(runId, 120);
    if (String.isBlank(checkSetQualifiedApiName)) {
      throw buildAuraException(
        'CONFIG_NOT_FOUND',
        'No Check Set is selected for this Record Health Check component.'
      );
    }
    try {
      return configService.getDefinitionResponse(
        checkSetQualifiedApiName,
        recordId
      );
    } catch (RecordHealthCheckConfigService.ConfigException ex) {
      // Expected, admin-facing condition (e.g. CONFIG_NOT_FOUND) — log at DEBUG.
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.DEBUG,
        runId,
        checkSetQualifiedApiName,
        recordId,
        null,
        'CONFIG_EXCEPTION',
        new Map<String, Object>{ 'reasonCode' => ex.reasonCode },
        null
      );
      throw buildAuraException(ex.reasonCode, ex.getMessage());
    } catch (Exception ex) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        runId,
        checkSetQualifiedApiName,
        recordId,
        null,
        'CONFIG_UNEXPECTED',
        null,
        ex
      );
      // an unexpected failure here (governor limit, NPE, SOQL error) is
      // NOT a missing-config condition. Reporting CONFIG_NOT_FOUND would tell the
      // admin their Check Set does not exist when it does. Use LOAD_FAILED so the
      // LWC surfaces a generic load error (parseAuraError already treats unknown
      // codes as LOAD_FAILED); CONFIG_NOT_FOUND stays reserved for the explicit
      // not-found path raised as a ConfigException above.
      throw buildAuraException(
        'LOAD_FAILED',
        'An unexpected error occurred loading the health check configuration.'
      );
    } finally {
      // Publish the held CONFIG_UNEXPECTED error before LOAD_FAILED unwinds —
      // PublishImmediately survives the rollback the thrown exception triggers.
      RecordHealthCheckLogger.flush();
    }
  }

  /**
   * Evaluates a single check and returns one split evaluation/display item.
   * checkSetQualifiedApiName is validated server-side to confirm the Check belongs to the
   * named Check Set, preventing direct invocation of arbitrary checks.
   *
   * @param checkSetQualifiedApiName Exact QualifiedApiName of the parent Check Set.
   * @param checkQualifiedApiName Exact QualifiedApiName of the Check.
   * @param recordId Record to evaluate.
   * @param runId Optional client correlation identifier.
   * @param source Exact browser execution source.
   * @return One contained evaluation and display result.
   */
  @AuraEnabled
  public static RecordHealthCheckResultItem evaluateCheck(
    String checkSetQualifiedApiName,
    String checkQualifiedApiName,
    Id recordId,
    String runId,
    String source
  ) {
    requireRunAccess();
    checkSetQualifiedApiName = RecordHealthCheckLogger.normalizeIdentifier(
      checkSetQualifiedApiName,
      80
    );
    checkQualifiedApiName = RecordHealthCheckLogger.normalizeIdentifier(
      checkQualifiedApiName,
      80
    );
    runId = RecordHealthCheckLogger.normalizeIdentifier(runId, 120);
    try {
      if (
        String.isBlank(checkSetQualifiedApiName) ||
        String.isBlank(checkQualifiedApiName)
      ) {
        throw new RecordHealthCheckControllerException(
          'Both Check Set and Check QualifiedApiName values are required.'
        );
      }
      String effectiveSource = normalizeLwcSource(source);
      validateCheckMembership(checkSetQualifiedApiName, checkQualifiedApiName);
      if (recordId == null) {
        RecordHealthCheckEvaluationResult evaluation = new RecordHealthCheckEvaluationResult();
        evaluation.checkQualifiedApiName = checkQualifiedApiName;
        evaluation.status = RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
        evaluation.reasonCode = RecordHealthCheckConfigService.RC_NO_RECORD_CONTEXT;
        RecordHealthCheckResultDisplay display = new RecordHealthCheckResultDisplay();
        display.renderedMessage = 'A Salesforce record is required to run this health check.';
        RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
        item.evaluation = evaluation;
        item.display = display;
        return item;
      }
      RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheck(
          checkQualifiedApiName,
          recordId
        )
        .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
        .withExecutionOrigin(
          effectiveSource ==
            RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
            ? RecordHealthCheckExecutionOrigin.USER_INITIATED
            : RecordHealthCheckExecutionOrigin.RUN_ON_LOAD
        )
        .withRunId(runId);
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
      return response.results[0];
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (Exception ex) {
      // Recoverable boundary failures become a stable item. Fatal plugin side
      // effects are rethrown above so their transaction cannot be committed.
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        runId,
        checkSetQualifiedApiName,
        recordId,
        checkQualifiedApiName,
        'CONTROLLER_BOUNDARY_ERROR',
        null,
        ex
      );
      RecordHealthCheckEvaluationResult evaluation = new RecordHealthCheckEvaluationResult();
      evaluation.checkQualifiedApiName = checkQualifiedApiName;
      evaluation.recordId = recordId;
      evaluation.status = RecordHealthCheckStatus.ERROR;
      evaluation.reasonCode = 'APEX_EVALUATOR_ERROR';
      RecordHealthCheckResultDisplay display = new RecordHealthCheckResultDisplay();
      display.renderedMessage = 'An unexpected error occurred. Contact your administrator.';
      RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
      item.evaluation = evaluation;
      item.display = display;
      return item;
    } finally {
      RecordHealthCheckLogger.flush();
    }
  }

  /**
   * Publishes advisory lifecycle events after a user-initiated client run finishes.
   *
   * @param checkSetQualifiedApiName Exact QualifiedApiName of the completed Check Set.
   * @param runId Client correlation identifier for the completed run.
   * @param source Exact browser execution source.
   * @param recordId Record evaluated by the completed run.
   * @param resultsJson Client-returned result items, filtered to the record and resolved Checks.
   * @throws AuraHandledException if completion cannot be performed safely.
   */
  @AuraEnabled
  public static void completeRun(
    String checkSetQualifiedApiName,
    String runId,
    String source,
    Id recordId,
    String resultsJson
  ) {
    requireRunAccess();
    try {
      String effectiveSource = normalizeLwcSource(source);
      String effectiveCheckSetName = RecordHealthCheckLogger.normalizeIdentifier(
        checkSetQualifiedApiName,
        80
      );
      if (
        effectiveSource !=
        RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED ||
        recordId == null
      ) {
        return;
      }
      String effectiveRunId = RecordHealthCheckLogger.normalizeIdentifier(
        runId,
        120
      );
      if (String.isBlank(resultsJson) || resultsJson.length() > 1000000) {
        throw new RecordHealthCheckControllerException(
          'Completed results are required and must be at most 1 MB.'
        );
      }
      RecordHealthCheckDefinitionResponse definitions = configService.getDefinitionResponse(
        effectiveCheckSetName,
        recordId
      );
      Set<String> allowedCheckNames = new Set<String>();
      for (RecordHealthCheckDefinition definition : definitions.checks) {
        allowedCheckNames.add(definition.qualifiedApiName);
      }
      List<RecordHealthCheckResultItem> completedItems = (List<RecordHealthCheckResultItem>) JSON.deserialize(
        resultsJson,
        List<RecordHealthCheckResultItem>.class
      );
      RecordHealthCheckResponse response = completionResponse(
        effectiveRunId,
        recordId,
        allowedCheckNames,
        completedItems
      );
      RecordHealthCheckLifecyclePublisher.publishInteractiveResponse(
        response,
        effectiveCheckSetName,
        effectiveSource
      );
    } catch (Exception ex) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        runId,
        checkSetQualifiedApiName,
        recordId,
        null,
        'RUN_COMPLETION_FAILED',
        null,
        ex
      );
      throw buildAuraException(
        'RUN_COMPLETION_FAILED',
        'An unexpected error occurred completing the health check run.'
      );
    } finally {
      RecordHealthCheckLogger.flush();
    }
  }

  @TestVisible
  private static RecordHealthCheckResponse completionResponse(
    String runId,
    Id recordId,
    Set<String> allowedCheckNames,
    List<RecordHealthCheckResultItem> completedItems
  ) {
    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    response.runId = runId;
    response.recordIds.add(recordId);
    Set<String> acceptedCheckNames = new Set<String>();
    List<RecordHealthCheckResultItem> candidateItems = completedItems;
    if (candidateItems == null) {
      candidateItems = new List<RecordHealthCheckResultItem>();
    }
    Set<String> configuredCheckNames = allowedCheckNames;
    if (configuredCheckNames == null) {
      configuredCheckNames = new Set<String>();
    }
    for (RecordHealthCheckResultItem item : candidateItems) {
      String checkName = item?.evaluation?.checkQualifiedApiName;
      if (
        item?.evaluation == null ||
        item.evaluation.recordId != recordId ||
        String.isBlank(checkName) ||
        !configuredCheckNames.contains(checkName) ||
        acceptedCheckNames.contains(checkName)
      ) {
        continue;
      }
      acceptedCheckNames.add(checkName);
      response.results.add(item);
      response.summary.add(item.evaluation.status);
    }
    response.checkQualifiedApiNames.addAll(acceptedCheckNames);
    return response;
  }

  /** Validates the browser execution source without silently changing its meaning. */
  private static void requireRunAccess() {
    try {
      RecordHealthCheckAccess.requireCanRunChecks();
    } catch (RecordHealthCheckAccess.AuthorizationException error) {
      throw buildAuraException(
        'NOT_AUTHORIZED',
        'You do not have permission to run Record Health Checks.'
      );
    }
  }

  /** Validates the browser execution source without silently changing its meaning. */
  private static String normalizeLwcSource(String source) {
    if (
      source == RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED ||
      source == RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    ) {
      return source;
    }
    throw new RecordHealthCheckControllerException(
      'The execution source is not recognized.'
    );
  }

  private static void validateCheckMembership(
    String checkSetQualifiedApiName,
    String checkQualifiedApiName
  ) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced before the component is exposed.
    List<Record_Health_Check__mdt> checks = [
      SELECT Record_Health_Check_Set__r.QualifiedApiName
      FROM Record_Health_Check__mdt
      WHERE QualifiedApiName = :checkQualifiedApiName
      LIMIT 1
    ];
    if (
      checks.isEmpty() ||
      checks[0].Record_Health_Check_Set__r.QualifiedApiName !=
      checkSetQualifiedApiName
    ) {
      throw new RecordHealthCheckControllerException(
        'The selected Check does not belong to the selected Check Set.'
      );
    }
  }

  private class RecordHealthCheckControllerException extends Exception {
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  private static AuraHandledException buildAuraException(
    String reasonCode,
    String message
  ) {
    // Surface a safe message to the LWC; reasonCode is embedded for diagnostic use.
    // Raw internal details are never passed through this public boundary.
    String payload = JSON.serialize(
      new Map<String, String>{
        'reasonCode' => reasonCode,
        'message' => message
      }
    );
    // The Lightning transport uses the constructor payload while direct Apex
    // tests observe getMessage(). Keep both paths identical and structured.
    AuraHandledException ex = new AuraHandledException(payload);
    ex.setMessage(payload);
    return ex;
  }
}
