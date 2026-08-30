/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckMetadataValidator {
  private static final Set<String> VALID_DISPLAY_MODES = RecordHealthCheckConstants.validDisplayModes;
  private static final Set<String> VALID_TRIGGER_MODES = RecordHealthCheckConstants.validTriggerModes;
  private static final Set<String> VALID_REVEAL_MODES = RecordHealthCheckConstants.validRevealModes;
  private static final Set<String> VALID_COMPARISON_DISPLAYS = RecordHealthCheckConstants.validComparisonDisplays;
  private static final Set<String> VALID_APPLICABILITY_MODES = RecordHealthCheckConstants.validApplicabilityModes;
  private static final Set<String> VALID_CHECK_TYPES = RecordHealthCheckConstants.validCheckTypes;
  private static final Set<String> VALID_SEVERITIES = RecordHealthCheckConstants.validSeverities;
  private static final Integer FRAMEWORK_MAX_ROWS = RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS;

  // ─── Validation issue data holder ─────────────────────────────────────────

  public class ValidationIssue {
    public String severity; // ERROR, WARNING
    public String componentName; // DeveloperName of the CMT record
    public String fieldName; // field involved, null for cross-record issues
    public String message;
    public String reasonCode;

    public ValidationIssue(
      String severity,
      String componentName,
      String fieldName,
      String message,
      String reasonCode
    ) {
      this.severity = severity;
      this.componentName = componentName;
      this.fieldName = fieldName;
      this.message = message;
      this.reasonCode = reasonCode;
    }
  }

  // Valid-value sets and caps are owned by RecordHealthCheckConstants so this
  // deploy-time validator and RecordHealthCheckConfigService (runtime) can never
  // get out of sync. Local aliases keep the call sites below readable.
  // The per-type check-validation decision tree lives in RecordHealthCheckValidator;
  // this class keeps the baseline + Check Set + dependency-graph checks (inline) plus a
  // collect-all adapter (toIssue). The operator/source/null-empty value sets live with
  // those producers.
  // ─── Public API ───────────────────────────────────────────────────────────

  /**
   * Validates all Check Sets and Checks in the org, including inactive drafts.
   * Returns a list of ValidationIssues — empty list means everything is valid.
   */
  public List<ValidationIssue> validate() {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Validator intentionally reads framework Custom Metadata setup records.
    List<Record_Health_Check_Set__mdt> checkSets = [
      SELECT
        DeveloperName,
        MasterLabel,
        ObjectApiName__c,
        IsActive__c,
        CardRunMode__c,
        RunButtonDisplay__c,
        RunButtonLabel__c,
        RerunButtonLabel__c,
        RunButtonIcon__c,
        CardRevealMode__c,
        FoundExpectedDisplay__c,
        PassedChecksDisplay__c,
        SkippedChecksDisplay__c,
        SummaryDisplay__c,
        CardTitle__c,
        PublishUserRunEvent__c
      FROM Record_Health_Check_Set__mdt
    ];

    // code-analyzer-suppress-next-line ApexCRUDViolation: Validator intentionally reads framework Custom Metadata setup records.
    List<Record_Health_Check__mdt> allChecks = [
      SELECT
        DeveloperName,
        QualifiedApiName,
        MasterLabel,
        CheckTitle__c,
        EvaluationOrder__c,
        IsActive__c,
        EvaluationType__c,
        FailureSeverity__c,
        PassConditionFormula__c,
        FindInListFormula__c,
        SourceQuery__c,
        SourceQueryField__c,
        ExpectedValueSource__c,
        ExpectedFixedValue__c,
        ExpectedCurrencyIsoCode__c,
        ExpectedRecordFormula__c,
        ComparisonQuery__c,
        ComparisonQueryField__c,
        ComparisonOperator__c,
        QueryResultHandling__c,
        NoRowsResult__c,
        EmptyValueHandling__c,
        DisplayFoundText__c,
        DisplayExpectedText__c,
        FailureMessage__c,
        UnableToEvaluateMessage__c,
        ActionLabel__c,
        ActionUrl__c,
        FixMessage__c,
        ApexClass__c,
        ApexParametersJson__c,
        MaxQueryRows__c,
        PrerequisiteCheck__c,
        ApplicabilityMode__c,
        ApplicabilityFormula__c,
        ApplicabilityNotMetMessage__c,
        ApplicabilityCountQuery__c,
        ApplicabilityCountOperator__c,
        ApplicabilityCountThreshold__c,
        PublishUserResultEvent__c,
        Record_Health_Check_Set__c
      FROM Record_Health_Check__mdt
      ORDER BY
        Record_Health_Check_Set__c ASC,
        EvaluationOrder__c ASC NULLS LAST,
        DeveloperName ASC
    ];

    return validateRecords(checkSets, allChecks);
  }

  /**
   * Machine-readable entry point for setup tooling and CI.
   *
   * Deliberately not `@AuraEnabled`: this serializes the full validation
   * of every Check Set and Check — query, Apex class, and formula surfaces —
   * which is admin/setup information, not per-record data. Exposing it to the
   * LWC/Aura surface would hand that config detail to any user who can invoke
   * component Apex, with no permission gate. CI and setup tooling call this
   * public static method directly from Apex (test, anonymous, or Tooling API),
   * so no Aura exposure is needed.
   */
  public static String validateAsJson() {
    return JSON.serialize(new RecordHealthCheckMetadataValidator().validate());
  }

  @TestVisible
  private List<ValidationIssue> validateRecords(
    List<Record_Health_Check_Set__mdt> checkSets,
    List<Record_Health_Check__mdt> allChecks
  ) {
    List<ValidationIssue> issues = new List<ValidationIssue>();

    // Validate each Check Set on its own; dependency validation scopes by
    // Check Set Id below.
    for (Record_Health_Check_Set__mdt cs : checkSets) {
      issues.addAll(validateCheckSet(cs));
    }

    Set<String> hiddenAutomaticSetKeys = new Set<String>();
    for (Record_Health_Check_Set__mdt cs : checkSets) {
      if (
        cs.CardRunMode__c == 'RUN_ON_LOAD' &&
        RecordHealthCheckConstants.normalizedRunButtonDisplay(
          cs.RunButtonDisplay__c
        ) == 'HIDE'
      ) {
        hiddenAutomaticSetKeys.add(cs.DeveloperName);
        if (cs.Id != null) {
          hiddenAutomaticSetKeys.add(String.valueOf(cs.Id));
        }
      }
    }

    // Group checks by Check Set for dependency validation
    Map<String, List<Record_Health_Check__mdt>> checksByCheckSet = new Map<String, List<Record_Health_Check__mdt>>();
    for (Record_Health_Check__mdt check : allChecks) {
      String csName = String.valueOf(check.Record_Health_Check_Set__c);
      if (!checksByCheckSet.containsKey(csName)) {
        checksByCheckSet.put(csName, new List<Record_Health_Check__mdt>());
      }
      checksByCheckSet.get(csName).add(check);
      issues.addAll(validateCheck(check));
      if (
        check.PublishUserResultEvent__c == true &&
        hiddenAutomaticSetKeys.contains(csName)
      ) {
        issues.add(
          new ValidationIssue(
            'WARNING',
            check.DeveloperName,
            'PublishUserResultEvent__c',
            'Publish User Result Event is enabled, but its hidden automatic card has no in-card Run or Rerun action. Page refreshes do not publish; use a visible action or a deliberate Apex or Flow invocation.',
            'USER_RESULT_PUBLICATION_UNREACHABLE'
          )
        );
      }
    }

    // Dependency graph validation per Check Set
    for (String csName : checksByCheckSet.keySet()) {
      List<Record_Health_Check__mdt> setChecks = checksByCheckSet.get(csName);
      if (setChecks.size() > RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS) {
        issues.add(
          new ValidationIssue(
            'WARNING',
            csName,
            null,
            'The Lightning card includes only the first ' +
              RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS +
              ' active Checks; direct Apex, Flow, Batch, Queueable, and Scheduled requests reject the entire oversized Check Set.',
            'CHECK_LIMIT_EXCEEDED'
          )
        );
        Set<String> included = new Set<String>();
        for (
          Integer i = 0;
          i < RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS;
          i++
        ) {
          included.add(identityOf(setChecks[i]));
        }
        for (
          Integer i = 0;
          i < RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS;
          i++
        ) {
          Record_Health_Check__mdt includedCheck = setChecks[i];
          if (
            String.isNotBlank(includedCheck.PrerequisiteCheck__c) &&
            !included.contains(
              RHCDefinitionDependencyIdentity.resolve(includedCheck, setChecks)
            )
          ) {
            issues.add(
              new ValidationIssue(
                'WARNING',
                includedCheck.DeveloperName,
                'PrerequisiteCheck__c',
                'The dependency is outside the first-' +
                  RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS +
                  ' execution window, so this check will be skipped.',
                'DEPENDENCY_NOT_IN_RUN'
              )
            );
          }
        }
      }
      issues.addAll(RHCMetadataDependencyValidator.validate(csName, setChecks));
    }

    return issues;
  }

  // ─── Check Set validation ─────────────────────────────────────────────────

  private List<ValidationIssue> validateCheckSet(
    Record_Health_Check_Set__mdt checkSet
  ) {
    return RecordHealthCheckMetadataSetValidator.validate(checkSet);
  }

  // ─── Check validation ──────────────────────────────────────────────────────

  private List<ValidationIssue> validateCheck(Record_Health_Check__mdt check) {
    List<ValidationIssue> issues = new List<ValidationIssue>();
    RecordHealthCheckTokenIssue tokenIssue = RecordHealthCheckConfigValidator.firstTemplateIssue(
      check
    );
    if (tokenIssue != null) {
      issues.add(err(check, null, tokenIssue.message, tokenIssue.reasonCode));
    }

    if (String.isBlank(check.CheckTitle__c)) {
      issues.add(
        err(
          check,
          'CheckTitle__c',
          'Check Title is required.',
          'MISSING_REQUIRED_FIELD'
        )
      );
    }
    if (check.EvaluationOrder__c == null) {
      issues.add(
        err(
          check,
          'EvaluationOrder__c',
          'Evaluation Order is required.',
          'MISSING_REQUIRED_FIELD'
        )
      );
    }
    if (
      String.isBlank(check.FailureSeverity__c) ||
      !VALID_SEVERITIES.contains(check.FailureSeverity__c)
    ) {
      issues.add(
        err(
          check,
          'FailureSeverity__c',
          'Severity must be CRITICAL, WARNING, or INFO.',
          'INVALID_CONFIG'
        )
      );
    }
    if (String.isBlank(check.FailureMessage__c)) {
      issues.add(
        err(
          check,
          'FailureMessage__c',
          'Message When Check Fails is required.',
          'MISSING_REQUIRED_FIELD'
        )
      );
    }
    if (String.isBlank(check.EvaluationType__c)) {
      issues.add(
        err(
          check,
          'EvaluationType__c',
          'Evaluation Type is required.',
          'MISSING_REQUIRED_FIELD'
        )
      );
      return issues; // can't validate further without Check Type
    }

    if (!VALID_CHECK_TYPES.contains(check.EvaluationType__c)) {
      issues.add(
        err(
          check,
          'EvaluationType__c',
          'Evaluation Type "' +
            check.EvaluationType__c +
            '" is not recognized.',
          'INVALID_CHECK_TYPE'
        )
      );
      return issues;
    }

    // ApplicabilityMode validation (null / blank == Always, which is valid)
    if (
      String.isNotBlank(check.ApplicabilityMode__c) &&
      !VALID_APPLICABILITY_MODES.contains(check.ApplicabilityMode__c)
    ) {
      issues.add(
        err(
          check,
          'ApplicabilityMode__c',
          'ApplicabilityMode "' +
            check.ApplicabilityMode__c +
            '" is not recognized. Valid values: ALL_RECORDS, WHEN_FORMULA_TRUE, WHEN_COUNT_QUERY_MATCHES.',
          'INVALID_CONFIG'
        )
      );
    }

    // Applicability sub-field validation — parity with the runtime ConfigService
    // so a misconfigured gate is caught at deploy time, not first evaluation.
    issues.addAll(
      RecordHealthCheckMetadataIssueMapper.toIssues(
        RecordHealthCheckValidator.applicabilityFindings(check),
        check
      )
    );

    if (check.EvaluationType__c == 'FORMULA') {
      issues.addAll(
        RecordHealthCheckMetadataIssueMapper.toIssues(
          RecordHealthCheckValidator.formulaFindings(check),
          check
        )
      );
    } else if (check.EvaluationType__c == 'QUERY') {
      issues.addAll(
        RecordHealthCheckMetadataIssueMapper.toIssues(
          RecordHealthCheckValidator.queryFindings(check),
          check
        )
      );
    } else if (check.EvaluationType__c == 'APEX') {
      issues.addAll(
        RecordHealthCheckMetadataIssueMapper.toIssues(
          RecordHealthCheckValidator.apexFindings(check),
          check
        )
      );
      // Apex plugins own their typed Found and Expected values. These metadata
      // fields are therefore ignored at runtime; surface that easy-to-miss setup
      // mistake without making an otherwise valid plugin Check unrunnable.
      if (String.isNotBlank(check.DisplayFoundText__c)) {
        issues.add(
          warning(
            check,
            'DisplayFoundText__c',
            'Display: Found Text is ignored for Apex Checks. Set the Found value in the Apex plugin.',
            'APEX_DISPLAY_TEXT_IGNORED'
          )
        );
      }
      if (String.isNotBlank(check.DisplayExpectedText__c)) {
        issues.add(
          warning(
            check,
            'DisplayExpectedText__c',
            'Display: Expected Text is ignored for Apex Checks. Set the Expected value in the Apex plugin.',
            'APEX_DISPLAY_TEXT_IGNORED'
          )
        );
      }
    } else if (check.EvaluationType__c == 'COMPARE_TWO_QUERIES') {
      issues.addAll(
        RecordHealthCheckMetadataIssueMapper.toIssues(
          RecordHealthCheckValidator.compareQueriesFindings(check),
          check
        )
      );
    }

    // MaxRows, empty-value handling, and empty-result behavior are validated for all
    // check types at top level. Shared producers report the findings; toIssue maps
    // each to this class's reason code / field.
    RecordHealthCheckMetadataIssueMapper.addIssues(
      issues,
      RecordHealthCheckValidator.maxRowsFindings(check),
      check
    );
    RecordHealthCheckMetadataIssueMapper.addIssues(
      issues,
      RecordHealthCheckValidator.nullEmptyFindings(check),
      check
    );

    return issues;
  }

  private static String identityOf(Record_Health_Check__mdt check) {
    return String.isBlank(check.QualifiedApiName)
      ? check.DeveloperName
      : check.QualifiedApiName;
  }

  // ─── Dependency graph validation is delegated to RHCMetadataDependencyValidator. ───

  // ─── Convenience builder ──────────────────────────────────────────────────

  private ValidationIssue err(
    Record_Health_Check__mdt check,
    String fieldName,
    String message,
    String reasonCode
  ) {
    return new ValidationIssue(
      'ERROR',
      check.DeveloperName,
      fieldName,
      message,
      reasonCode
    );
  }

  private ValidationIssue warning(
    Record_Health_Check__mdt check,
    String fieldName,
    String message,
    String reasonCode
  ) {
    return new ValidationIssue(
      'WARNING',
      check.DeveloperName,
      fieldName,
      message,
      reasonCode
    );
  }
}
