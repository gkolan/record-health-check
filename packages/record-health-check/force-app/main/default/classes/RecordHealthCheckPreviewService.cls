/** Privileged detached-draft validation, execution preview, and readiness receipts. */
global with sharing class RecordHealthCheckPreviewService {
  /** Validates or executes one detached Check against its server-owned Check Set. */
  global static RecordHealthCheckPreviewResponse preview(
    RecordHealthCheckPreviewRequest request
  ) {
    requireAuthorization();
    if (request == null) {
      throw new PreviewException('A preview request is required.');
    }

    Record_Health_Check_Set__mdt checkSet = loadCheckSet(
      request.qualifiedSetName
    );
    Record_Health_Check__mdt draft = request.draftCheck;
    if (
      draft.Record_Health_Check_Set__c == null ||
      draft.Record_Health_Check_Set__c != checkSet.Id
    ) {
      throw new PreviewException(
        'The detached Check parent does not match the server-owned Check Set.'
      );
    }

    RecordHealthCheckScopePlanner planner = new RecordHealthCheckScopePlanner();
    RecordHealthCheckScopePipeline.SelectionContext context = planner.resolveCheckSet(
      request.qualifiedSetName
    );
    planner.validateScope(context, request.recordIds);
    List<Record_Health_Check__mdt> prerequisites = applyDraft(
      context,
      draft,
      checkSet.Id
    );

    RecordHealthCheckPreviewResponse response = baseResponse(
      request,
      draft,
      checkSet,
      prerequisites
    );
    Schema.SObjectType objectType = Schema.getGlobalDescribe()
      .get(context.objectApiName);
    Boolean resolvePlugin = request.mode == 'EXECUTE';
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckDetachedValidator()
      .validate(draft, objectType, resolvePlugin);
    addFindings(response, issues);
    planFields(response, context.checks, objectType);
    setCapabilities(response, draft, resolvePlugin);
    addPluginParameters(response, draft, resolvePlugin);
    response.validationStatus = validationStatus(response);

    if (request.mode == 'EXECUTE' && response.validationStatus != 'INVALID') {
      RecordHealthCheckRequest executionRequest = RecordHealthCheckRequest.forCheckSet(
          request.qualifiedSetName,
          request.recordIds
        )
        .withEventPublication(RecordHealthCheckEventPublication.NONE)
        .withRunId(response.runId)
        .withExecutionOrigin(RecordHealthCheckExecutionOrigin.APEX_API);
      RecordHealthCheckResponse execution = new RecordHealthCheckScopePipeline()
        .evaluateResolvedContext(executionRequest, context);
      response.results.addAll(execution.results);
    }

    response.readinessReceipt = RecordHealthCheckReadinessService.save(
      request,
      response,
      identityOf(draft),
      checkSet.QualifiedApiName
    );
    RecordHealthCheckReadinessService.decorate(
      response,
      draft,
      checkSet.QualifiedApiName
    );
    return response;
  }

  /** Deletes at most 200 expired receipts after explicit administrator confirmation. */
  global static Integer deleteExpiredReadinessReceipts(Boolean confirmed) {
    requireAuthorization();
    return RecordHealthCheckReadinessService.deleteExpired(confirmed);
  }

  private static void requireAuthorization() {
    if (!RecordHealthCheckAccess.canAdminister()) {
      throw new PreviewException(
        'Record Health Check administrator permission is required.'
      );
    }
    try {
      RecordHealthCheckAccess.requireCanRunChecks();
    } catch (RecordHealthCheckAccess.AuthorizationException denied) {
      throw new PreviewException(denied.getMessage());
    }
  }

  private static Record_Health_Check_Set__mdt loadCheckSet(
    String qualifiedName
  ) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata is server-owned package configuration and is authorized before discovery.
    List<Record_Health_Check_Set__mdt> sets = [
      SELECT
        Id,
        QualifiedApiName,
        DeveloperName,
        MasterLabel,
        CardRevealMode__c,
        CardRunMode__c,
        CardSubtitle__c,
        CardTitle__c,
        FoundExpectedDisplay__c,
        IsActive__c,
        ObjectApiName__c,
        PassedChecksDisplay__c,
        PublishErrorLogEvent__c,
        PublishUserRunEvent__c,
        RerunButtonLabel__c,
        RunButtonDisplay__c,
        RunButtonIcon__c,
        RunButtonLabel__c,
        ShowDiagnostics__c,
        SkippedChecksDisplay__c,
        StopOnSystemError__c,
        SummaryDisplay__c
      FROM Record_Health_Check_Set__mdt
      WHERE QualifiedApiName = :qualifiedName
      LIMIT 2
    ];
    return new RecordHealthCheckScopePlanner()
      .requireSingleCheckSet(sets, qualifiedName);
  }

  private static List<Record_Health_Check__mdt> applyDraft(
    RecordHealthCheckScopePipeline.SelectionContext context,
    Record_Health_Check__mdt draft,
    Id checkSetId
  ) {
    if (String.isBlank(draft.DeveloperName)) {
      throw new PreviewException(
        'The detached Check DeveloperName is required.'
      );
    }
    Map<String, Record_Health_Check__mdt> byIdentity = new Map<String, Record_Health_Check__mdt>();
    for (Record_Health_Check__mdt check : context.checks) {
      addIdentity(byIdentity, check);
    }
    // The normal Set resolver intentionally returns active Checks only. Preview
    // must still authenticate an existing inactive draft against server-owned
    // identity before replacing it in the execution context.
    for (
      Record_Health_Check__mdt existingDraft : loadDraftIdentity(
        checkSetId,
        draft.DeveloperName
      )
    ) {
      addIdentity(byIdentity, existingDraft);
    }
    enforceDraftIdentity(draft, byIdentity);

    List<Record_Health_Check__mdt> prerequisites = new List<Record_Health_Check__mdt>();
    Set<String> visited = new Set<String>();
    String prerequisiteIdentity = draft.PrerequisiteCheck__c;
    while (String.isNotBlank(prerequisiteIdentity)) {
      if (
        prerequisiteIdentity == String.valueOf(draft.Id) ||
        prerequisiteIdentity == draft.DeveloperName ||
        prerequisiteIdentity == draft.QualifiedApiName
      ) {
        throw new PreviewException(
          'The detached Check cannot depend on itself.'
        );
      }
      if (!visited.add(prerequisiteIdentity)) {
        throw new PreviewException(
          'The detached Check prerequisite graph contains a cycle.'
        );
      }
      Record_Health_Check__mdt prerequisite = byIdentity.get(
        prerequisiteIdentity
      );
      if (prerequisite == null || prerequisite.IsActive__c != true) {
        throw new PreviewException(
          'The detached Check prerequisite is missing or inactive.'
        );
      }
      prerequisites.add(prerequisite);
      prerequisiteIdentity = prerequisite.PrerequisiteCheck__c;
    }
    List<Record_Health_Check__mdt> effectiveChecks = new List<Record_Health_Check__mdt>(
      prerequisites
    );
    effectiveChecks.add(draft);
    context.checks = RHCDefinitionDependencyIdentity.orderForEvaluation(
      effectiveChecks
    );
    context.fullCheckSetSelection = false;
    return prerequisites;
  }

  private static List<Record_Health_Check__mdt> loadDraftIdentity(
    Id checkSetId,
    String developerName
  ) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata identity is server-owned configuration used to prevent a detached caller from forging an inactive Check.
    return [
      SELECT Id, DeveloperName, QualifiedApiName, NamespacePrefix, Language
      FROM Record_Health_Check__mdt
      WHERE
        Record_Health_Check_Set__c = :checkSetId
        AND DeveloperName = :developerName
      LIMIT 2
    ];
  }

  private static void addIdentity(
    Map<String, Record_Health_Check__mdt> byIdentity,
    Record_Health_Check__mdt check
  ) {
    if (check.Id != null) {
      byIdentity.put(String.valueOf(check.Id), check);
    }
    byIdentity.put(check.DeveloperName, check);
    byIdentity.put(check.QualifiedApiName, check);
  }

  private static void enforceDraftIdentity(
    Record_Health_Check__mdt draft,
    Map<String, Record_Health_Check__mdt> byIdentity
  ) {
    Record_Health_Check__mdt existing;
    if (draft.Id != null) {
      existing = byIdentity.get(String.valueOf(draft.Id));
      if (existing == null) {
        throw new PreviewException(
          'The detached Check identity does not belong to the selected Check Set.'
        );
      }
    } else if (String.isNotBlank(draft.QualifiedApiName)) {
      existing = byIdentity.get(draft.QualifiedApiName);
    } else {
      existing = byIdentity.get(draft.DeveloperName);
    }
    if (existing == null) {
      if (
        draft.Id != null ||
        String.isNotBlank(draft.QualifiedApiName) ||
        String.isNotBlank(draft.NamespacePrefix) ||
        String.isNotBlank(draft.Language)
      ) {
        throw new PreviewException(
          'A new detached Check cannot supply server-owned identity fields.'
        );
      }
      return;
    }
    if (
      draft.DeveloperName != existing.DeveloperName ||
      (String.isNotBlank(draft.QualifiedApiName) &&
      draft.QualifiedApiName != existing.QualifiedApiName) ||
      (String.isNotBlank(draft.NamespacePrefix) &&
      draft.NamespacePrefix != existing.NamespacePrefix) ||
      (String.isNotBlank(draft.Language) && draft.Language != existing.Language)
    ) {
      throw new PreviewException(
        'The detached Check cannot overwrite server-owned identity fields.'
      );
    }
  }

  private static RecordHealthCheckPreviewResponse baseResponse(
    RecordHealthCheckPreviewRequest request,
    Record_Health_Check__mdt draft,
    Record_Health_Check_Set__mdt checkSet,
    List<Record_Health_Check__mdt> prerequisites
  ) {
    RecordHealthCheckPreviewResponse response = new RecordHealthCheckPreviewResponse();
    response.runId = RecordHealthCheckScopeRuntime.newRunId();
    response.mode = request.mode;
    response.definitionFingerprint = RecordHealthCheckPreviewFingerprint.compute(
      draft,
      checkSet,
      prerequisites,
      null
    );
    return response;
  }

  private static void addFindings(
    RecordHealthCheckPreviewResponse response,
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues
  ) {
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      RecordHealthCheckPreviewFinding finding = new RecordHealthCheckPreviewFinding();
      finding.code = issue.reasonCode;
      finding.severity = issue.severity;
      finding.message = issue.message;
      finding.configurationField = issue.fieldName;
      finding.offendingToken = issue.offendingToken;
      finding.startOffset = issue.startOffset;
      finding.endOffset = issue.endOffset;
      response.findings.add(finding);
    }
  }

  private static void planFields(
    RecordHealthCheckPreviewResponse response,
    List<Record_Health_Check__mdt> checks,
    Schema.SObjectType objectType
  ) {
    Set<String> fields = new Set<String>();
    RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();
    for (Record_Health_Check__mdt check : checks) {
      fields.addAll(planner.collectRecordFields(check, objectType));
    }
    response.resolvedFields.addAll(fields);
    response.resolvedFields.sort();
  }

  private static void setCapabilities(
    RecordHealthCheckPreviewResponse response,
    Record_Health_Check__mdt draft,
    Boolean resolvePlugin
  ) {
    response.capabilities.put('configuration', 'COMPLETE');
    response.capabilities.put('fieldPlanning', 'COMPLETE');
    if (draft.EvaluationType__c == 'APEX' && !resolvePlugin) {
      response.capabilities.put('pluginSchema', 'INCOMPLETE');
      response.capabilities.put('pluginFreshness', 'INCOMPLETE');
    } else {
      response.capabilities.put('pluginSchema', 'COMPLETE');
      response.capabilities.put(
        'pluginFreshness',
        draft.EvaluationType__c == 'APEX' ? 'INCOMPLETE' : 'COMPLETE'
      );
    }
  }

  private static void addPluginParameters(
    RecordHealthCheckPreviewResponse response,
    Record_Health_Check__mdt draft,
    Boolean resolvePlugin
  ) {
    if (draft.EvaluationType__c != 'APEX' || resolvePlugin != true) {
      return;
    }
    RecordHealthCheckPluginDefinition definition = RecordHealthCheckConfigValidator.validatedDefinition(
      draft
    );
    if (definition == null) {
      return;
    }
    Map<String, Object> normalized = RecordHealthCheckConfigValidator.validatedParameters(
      draft
    );
    for (String key : definition.parameterKeys()) {
      RecordHealthCheckPluginDefinition.ParameterDefinition source = definition.parameter(
        key
      );
      RecordHealthCheckPreviewParameter target = new RecordHealthCheckPreviewParameter();
      target.key = source.key;
      target.typeName = source.typeName;
      target.defaultValue = source.defaultValue;
      target.currentValue = normalized.containsKey(key)
        ? normalized.get(key)
        : source.defaultValue;
      target.hasDefault = source.hasDefault;
      target.minValue = source.minValue;
      target.maxValue = source.maxValue;
      target.maxLength = source.maxLength;
      target.choices = source.choices == null
        ? null
        : new List<String>(source.choices);
      target.required = source.required;
      target.nullable = source.nullable;
      target.label = source.label;
      target.helpText = source.helpText;
      response.pluginParameters.add(target);
    }
  }

  private static String validationStatus(
    RecordHealthCheckPreviewResponse response
  ) {
    for (RecordHealthCheckPreviewFinding finding : response.findings) {
      if (finding.severity == 'ERROR') {
        return 'INVALID';
      }
    }
    for (String status : response.capabilities.values()) {
      if (status != 'COMPLETE') {
        return 'INCOMPLETE';
      }
    }
    return 'VALID';
  }

  private static String identityOf(Record_Health_Check__mdt draft) {
    return String.isBlank(draft.QualifiedApiName)
      ? draft.DeveloperName
      : draft.QualifiedApiName;
  }

  /** Invalid or unauthorized detached preview. */
  global class PreviewException extends Exception {
  }
}
