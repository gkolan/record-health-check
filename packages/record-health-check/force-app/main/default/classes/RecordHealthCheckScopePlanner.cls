/** Resolves scope selections and enforces request budgets. */
public with sharing class RecordHealthCheckScopePlanner {
  private static final Integer FORMULA_CALL_BUDGET = RecordHealthCheckFormulaEvaluator.FORMULA_CALL_BUDGET;

  public RecordHealthCheckScopePipeline.SelectionContext resolveSelection(
    RecordHealthCheckSelection selection
  ) {
    if (selection == null) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'A qualified selection is required.'
      );
    }
    if (String.isNotBlank(selection.checkQualifiedApiName)) {
      return resolveCheck(selection.checkQualifiedApiName);
    }
    return resolveCheckSet(selection.checkSetQualifiedApiName);
  }

  public RecordHealthCheckScopePipeline.SelectionContext resolveCheck(
    String qualifiedApiName
  ) {
    List<Record_Health_Check__mdt> checks = queryChecks(
      'QualifiedApiName = :qualifiedApiName',
      qualifiedApiName
    );
    if (checks.isEmpty()) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'Check "' + qualifiedApiName + '" was not found.'
      );
    }
    RecordHealthCheckScopePipeline.SelectionContext context = contextFromCheck(
      checks[0]
    );
    context.checks.add(checks[0]);
    return context;
  }

  public RecordHealthCheckScopePipeline.SelectionContext resolveCheckSet(
    String qualifiedApiName
  ) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata is framework configuration; the selected business records are loaded separately WITH USER_MODE.
    List<Record_Health_Check_Set__mdt> sets = [
      SELECT
        QualifiedApiName,
        DeveloperName,
        IsActive__c,
        ObjectApiName__c,
        ShowDiagnostics__c
      FROM Record_Health_Check_Set__mdt
      WHERE QualifiedApiName = :qualifiedApiName
      LIMIT 2
    ];
    Record_Health_Check_Set__mdt checkSet = requireSingleCheckSet(
      sets,
      qualifiedApiName
    );
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.checkSetQualifiedApiName = checkSet.QualifiedApiName;
    context.checkSetDeveloperName = checkSet.DeveloperName;
    context.checkSetActive = checkSet.IsActive__c;
    context.objectApiName = checkSet.ObjectApiName__c;
    context.showDiagnostics = checkSet.ShowDiagnostics__c == true;
    context.checks = queryChecks(
      'Record_Health_Check_Set__r.QualifiedApiName = :qualifiedApiName AND IsActive__c = TRUE',
      qualifiedApiName
    );
    return context;
  }

  public Record_Health_Check_Set__mdt requireSingleCheckSet(
    List<Record_Health_Check_Set__mdt> checkSets,
    String qualifiedApiName
  ) {
    if (checkSets.isEmpty()) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'Check Set "' + qualifiedApiName + '" was not found.'
      );
    }
    if (checkSets.size() > 1) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'Check Set "' + qualifiedApiName + '" is ambiguous.'
      );
    }
    return checkSets[0];
  }

  public List<Record_Health_Check__mdt> queryChecks(
    String predicate,
    String qualifiedApiName
  ) {
    List<String> checkFields = new List<String>();
    for (
      Schema.SObjectField field : Schema.SObjectType.Record_Health_Check__mdt.fields
        .getMap()
        .values()
    ) {
      checkFields.add(
        RecordHealthCheckDescribeCache.describeField(field).getName()
      );
    }
    checkFields.sort();
    String query =
      'SELECT ' +
      String.join(checkFields, ', ') +
      ', Record_Health_Check_Set__r.QualifiedApiName, ' +
      'Record_Health_Check_Set__r.DeveloperName, Record_Health_Check_Set__r.IsActive__c, ' +
      'Record_Health_Check_Set__r.ObjectApiName__c, Record_Health_Check_Set__r.ShowDiagnostics__c ' +
      'FROM Record_Health_Check__mdt WHERE ' +
      predicate +
      ' ORDER BY EvaluationOrder__c ASC NULLS LAST, DeveloperName ASC LIMIT ' +
      String.valueOf(RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS + 1);
    List<Record_Health_Check__mdt> checks = Database.queryWithBinds(
      query,
      new Map<String, Object>{ 'qualifiedApiName' => qualifiedApiName },
      AccessLevel.USER_MODE
    );
    enforceCheckLimit(checks);
    return checks;
  }

  public void enforceCheckLimit(List<Record_Health_Check__mdt> checks) {
    if (checks.size() > RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'FRAMEWORK_MAX_CHECKS_EXCEEDED: suppliedCount=' +
          checks.size() +
          ', ceiling=' +
          RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS
      );
    }
  }

  public RecordHealthCheckScopePipeline.SelectionContext contextFromCheck(
    Record_Health_Check__mdt check
  ) {
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    SObject parent = check.getSObject('Record_Health_Check_Set__r');
    if (parent == null) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'The selected Check has no owning Check Set.'
      );
    }
    context.checkSetQualifiedApiName = (String) parent.get('QualifiedApiName');
    context.checkSetDeveloperName = (String) parent.get('DeveloperName');
    context.checkSetActive = parent.get('IsActive__c') == true;
    context.objectApiName = (String) parent.get('ObjectApiName__c');
    context.showDiagnostics = parent.get('ShowDiagnostics__c') == true;
    return context;
  }

  public void validateScope(
    RecordHealthCheckScopePipeline.SelectionContext context,
    List<Id> recordIds
  ) {
    if (context == null || String.isBlank(context.objectApiName)) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'INVALID_OBJECT_API_NAME: the selected Check Set must name a valid object.'
      );
    }
    if (!RecordHealthCheckDescribeCache.containsObject(context.objectApiName)) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'INVALID_OBJECT_API_NAME: object "' +
          context.objectApiName +
          '" does not exist.'
      );
    }
    if (!context.checkSetActive) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'The selected Check Set is inactive.'
      );
    }
    for (Id recordId : recordIds) {
      if (recordId == null) {
        continue;
      }
      String actualObject = RecordHealthCheckDescribeCache.objectApiName(
        recordId
      );
      if (
        String.isBlank(actualObject) ||
        !context.objectApiName.equalsIgnoreCase(actualObject)
      ) {
        throw new RecordHealthCheckScopePipeline.ScopePipelineException(
          'The selected Check Set is for ' +
            context.objectApiName +
            ', not ' +
            actualObject +
            '.'
        );
      }
    }
  }

  public void enforceFormulaBudget(
    List<Record_Health_Check__mdt> checks,
    Integer recordCount
  ) {
    Integer plannedCalls = 0;
    for (Record_Health_Check__mdt check : checks) {
      if (check.ApplicabilityMode__c == 'WHEN_FORMULA_TRUE') {
        plannedCalls += recordCount;
      }
      if (check.EvaluationType__c == 'FORMULA') {
        plannedCalls += recordCount;
        plannedCalls += plannedDisplayFormulaCalls(
          check.DisplayFoundFormula__c,
          check.FormulaResultType__c,
          recordCount
        );
        plannedCalls += plannedDisplayFormulaCalls(
          check.DisplayExpectedFormula__c,
          check.FormulaResultType__c,
          recordCount
        );
      } else if (check.EvaluationType__c == 'QUERY') {
        plannedCalls += plannedDisplayFormulaCalls(
          check.FindInListFormula__c,
          check.FormulaResultType__c,
          recordCount
        );
        plannedCalls += plannedDisplayFormulaCalls(
          check.ExpectedRecordFormula__c,
          check.FormulaResultType__c,
          recordCount
        );
      }
    }
    Integer callsUsed = RecordHealthCheckFormulaEvaluator.callsUsed();
    Integer remainingCalls = Math.max(0, FORMULA_CALL_BUDGET - callsUsed);
    if (plannedCalls > remainingCalls) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'This request plans ' +
          plannedCalls +
          ' FormulaEval calls, but only ' +
          remainingCalls +
          ' remain in the safe transaction budget (' +
          callsUsed +
          ' already used). ' +
          'Reduce the record scope or selected Formula Checks.'
      );
    }
  }

  public void enforcePluginSavepointBudget(
    List<Record_Health_Check__mdt> checks
  ) {
    Integer requiredDmlStatements = 0;
    for (Record_Health_Check__mdt check : checks) {
      if (check.EvaluationType__c == 'APEX') {
        // Validation constructs the plugin under one savepoint; dispatch runs
        // it under a second. Both count against the DML statement limit.
        requiredDmlStatements += 2;
      }
    }
    Integer remainingDmlStatements =
      Limits.getLimitDmlStatements() - Limits.getDmlStatements();
    if (requiredDmlStatements > remainingDmlStatements) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'PLUGIN_SAVEPOINT_BUDGET_EXCEEDED: required=' +
          requiredDmlStatements +
          ', remaining=' +
          remainingDmlStatements
      );
    }
  }

  /** Reserves transaction-wide query, DML/publication, and heap capacity. */
  public void enforceTransactionBudget(
    List<Record_Health_Check__mdt> checks,
    Integer recordCount,
    RecordHealthCheckEventPublication publication
  ) {
    Integer requiredQueries = recordCount > 0 ? 1 : 0;
    Integer requiredDml = 0;
    for (Record_Health_Check__mdt check : checks) {
      if (check.ApplicabilityMode__c == 'WHEN_COUNT_QUERY_MATCHES') {
        requiredQueries++;
      }
      if (check.EvaluationType__c == 'QUERY') {
        requiredQueries++;
        if (check.ExpectedValueSource__c == 'COMPARISON_QUERY') {
          requiredQueries++;
        }
      } else if (check.EvaluationType__c == 'COMPARE_TWO_QUERIES') {
        requiredQueries += 2;
      } else if (check.EvaluationType__c == 'APEX') {
        requiredDml += 2;
      }
    }
    if (
      publication != null &&
      publication != RecordHealthCheckEventPublication.NONE
    ) {
      requiredDml += ceilingDivide(recordCount * checks.size(), 100);
      requiredDml += ceilingDivide(recordCount, 100);
    }
    Integer remainingQueries = Limits.getLimitQueries() - Limits.getQueries();
    Integer remainingDml =
      Limits.getLimitDmlStatements() - Limits.getDmlStatements();
    if (requiredQueries > remainingQueries || requiredDml > remainingDml) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'TRANSACTION_BUDGET_EXCEEDED: queriesRequired=' +
          requiredQueries +
          ', queriesRemaining=' +
          remainingQueries +
          ', dmlRequired=' +
          requiredDml +
          ', dmlRemaining=' +
          remainingDml
      );
    }
    Integer projectedHeap = recordCount * checks.size() * 768;
    Integer remainingHeap = Limits.getLimitHeapSize() - Limits.getHeapSize();
    if (projectedHeap > remainingHeap) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'HEAP_BUDGET_EXCEEDED: projected=' +
          projectedHeap +
          ', remaining=' +
          remainingHeap
      );
    }
  }

  private Integer ceilingDivide(Integer value, Integer divisor) {
    return value == 0 ? 0 : ((value - 1) / divisor) + 1;
  }

  public Integer plannedDisplayFormulaCalls(
    String expression,
    String declaredType,
    Integer recordCount
  ) {
    if (String.isBlank(expression) || recordCount == 0) {
      return 0;
    }
    return String.isBlank(declaredType) || declaredType == 'AUTO'
      ? recordCount + 7
      : recordCount;
  }
}
