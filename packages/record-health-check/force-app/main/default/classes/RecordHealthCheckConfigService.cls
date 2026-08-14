/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckConfigService {
  // ─── Reason codes ──────────────────────────────────────────

  public static final String RC_CONFIG_NOT_FOUND = 'CONFIG_NOT_FOUND';
  public static final String RC_CONFIG_INACTIVE = 'CONFIG_INACTIVE';
  public static final String RC_OBJECT_MISMATCH = 'OBJECT_MISMATCH';
  public static final String RC_NO_RECORD_CONTEXT = 'NO_RECORD_CONTEXT';
  public static final String RC_NO_ACTIVE_CHECKS = 'NO_ACTIVE_CHECKS';
  public static final String RC_NO_ACTIVE_CHECK_SETS = 'NO_ACTIVE_CHECK_SETS';
  public static final String RC_INACTIVE_CHECK_SETS_ONLY = 'INACTIVE_CHECK_SETS_ONLY';
  public static final String RC_CHECK_NOT_FOUND = 'CHECK_NOT_FOUND';
  public static final String RC_CHECK_INACTIVE = 'CHECK_INACTIVE';
  public static final String RC_UNABLE_TO_EVALUATE = 'UNABLE_TO_EVALUATE';
  public static final String RC_INVALID_CONFIG = 'INVALID_CONFIG';

  // Valid-value sets and caps are owned by RecordHealthCheckConstants so this
  // runtime validator and RecordHealthCheckMetadataValidator (deploy-time) can
  // never get out of sync. Local aliases keep the call sites below readable.
  // The per-type check-validation decision tree lives in RecordHealthCheckValidator;
  // this class keeps only the baseline checks below (inline) plus a first-fail adapter
  // (toResult). The operator/source/null-empty value sets live with those producers.
  private static final Set<String> VALID_DISPLAY_MODES = RecordHealthCheckConstants.validDisplayModes;
  private static final Set<String> VALID_TRIGGER_MODES = RecordHealthCheckConstants.validTriggerModes;
  private static final Set<String> VALID_REVEAL_MODES = RecordHealthCheckConstants.validRevealModes;
  private static final Set<String> VALID_COMPARISON_DISPLAYS = RecordHealthCheckConstants.validComparisonDisplays;
  private static final Set<String> VALID_APPLICABILITY_MODES = RecordHealthCheckConstants.validApplicabilityModes;
  private static final Set<String> VALID_CHECK_TYPES = RecordHealthCheckConstants.validCheckTypes;
  private static final Set<String> VALID_SEVERITIES = RecordHealthCheckConstants.validSeverities;

  private static final Integer FRAMEWORK_MAX_CHECKS = RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS;
  private static final Integer FRAMEWORK_MAX_ROWS = RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS;

  // ─── Component-level exception ────────────────────────────────────────────

  public class ConfigException extends Exception {
    public String reasonCode;
    public ConfigException(String message, String reasonCode) {
      this(message);
      this.reasonCode = reasonCode;
    }
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  /** Finds the parent Check Set for a Check API name. */
  public String findCheckSetDeveloperName(String checkDeveloperName) {
    checkDeveloperName = RecordHealthCheckLogger.normalizeIdentifier(
      checkDeveloperName,
      80
    );
    if (String.isBlank(checkDeveloperName)) {
      return null;
    }
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced before check evaluation.
    List<Record_Health_Check__mdt> checks = [
      SELECT Record_Health_Check_Set__r.DeveloperName
      FROM Record_Health_Check__mdt
      WHERE DeveloperName = :checkDeveloperName
      LIMIT 1
    ];
    return checks.isEmpty()
      ? null
      : checks[0].Record_Health_Check_Set__r.DeveloperName;
  }

  /**
   * Reports whether any Check Sets target the given object API name.
   * Used when the LWC has no Check Set selected, so the setup banner can say
   * choose one, activate one, or create one.
   */
  public RecordHealthCheckSetAvailability getCheckSetAvailabilityForObject(
    String objectApiName
  ) {
    RecordHealthCheckSetAvailability availability = new RecordHealthCheckSetAvailability();
    if (String.isBlank(objectApiName)) {
      return availability;
    }
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before definitions are exposed.
    for (Record_Health_Check_Set__mdt checkSet : [
      SELECT ObjectApiName__c, IsActive__c
      FROM Record_Health_Check_Set__mdt
    ]) {
      if (!objectApiName.equalsIgnoreCase(checkSet.ObjectApiName__c)) {
        continue;
      }
      if (checkSet.IsActive__c == true) {
        availability.hasActive = true;
      } else {
        availability.hasInactive = true;
      }
      if (availability.hasActive && availability.hasInactive) {
        break;
      }
    }
    return availability;
  }

  /** Loads and validates a Check Set and its active checks. */
  public RecordHealthCheckDefinitionResponse getDefinitionResponse(
    String checkSetDeveloperName,
    Id recordId
  ) {
    return RecordHealthCheckDefinitionLoader.getDefinitionResponse(
      this,
      checkSetDeveloperName,
      recordId
    );
  }

  /**
   * Validates a single check's metadata configuration for runtime evaluation.
   * Returns a UNABLE_TO_EVALUATE RecordHealthCheckInternalResult if the check is invalid
   * or null if the check is valid and may proceed to the evaluator.
   */
  public RecordHealthCheckInternalResult validateCheckForEvaluation(
    Record_Health_Check__mdt check
  ) {
    RecordHealthCheckTokenIssue templateIssue = RecordHealthCheckConfigValidator.firstTemplateIssue(
      check
    );
    if (templateIssue != null) {
      return buildUnableResult(check, RC_INVALID_CONFIG, templateIssue.message);
    }
    if (
      String.isBlank(check.CheckTitle__c) || check.EvaluationOrder__c == null
    ) {
      return buildUnableResult(
        check,
        RC_INVALID_CONFIG,
        'Check Title and Evaluation Order are required on every check.'
      );
    }
    if (String.isBlank(check.FailureMessage__c)) {
      return buildUnableResult(
        check,
        RC_INVALID_CONFIG,
        'Message When Check Fails is required on every check.'
      );
    }
    // Unknown check type
    if (!VALID_CHECK_TYPES.contains(check.EvaluationType__c)) {
      return buildUnableResult(
        check,
        'INVALID_CHECK_TYPE',
        'Evaluation Type "' + check.EvaluationType__c + '" is not recognized.'
      );
    }

    // Severity required
    if (
      String.isBlank(check.FailureSeverity__c) ||
      !VALID_SEVERITIES.contains(check.FailureSeverity__c)
    ) {
      return buildUnableResult(
        check,
        RC_INVALID_CONFIG,
        'Severity must be CRITICAL, WARNING, or INFO.'
      );
    }

    // ApplicabilityMode validation (null / blank == Always, which is valid)
    if (
      String.isNotBlank(check.ApplicabilityMode__c) &&
      !VALID_APPLICABILITY_MODES.contains(check.ApplicabilityMode__c)
    ) {
      return buildUnableResult(
        check,
        'INVALID_CONFIG',
        'ApplicabilityMode "' +
          check.ApplicabilityMode__c +
          '" is not recognized. Valid values: ALL_RECORDS, WHEN_FORMULA_TRUE, WHEN_COUNT_QUERY_MATCHES.'
      );
    }

    // Applicability sub-field validation — surface a misconfigured gate here as a
    // clear config error rather than letting the engine reach it at evaluation time.
    RecordHealthCheckInternalResult applicabilityIssue = validateApplicability(
      check
    );
    if (applicabilityIssue != null) {
      return applicabilityIssue;
    }

    // Per-type required-field validation
    if (check.EvaluationType__c == 'FORMULA') {
      return validateFormulaCheck(check);
    } else if (check.EvaluationType__c == 'QUERY') {
      return validateQueryCheck(check);
    } else if (check.EvaluationType__c == 'APEX') {
      return validateApexCheck(check);
    }
    // Baseline validation above rejects unknown types, so the only remaining
    // supported type is COMPARE_TWO_QUERIES.
    return validateCompareQueriesCheck(check);
  }

  /**
   * Loads an active Check scoped to the named Check Set.
   * Returns null when the check is missing, inactive, or belongs to a different set.
   */
  public Record_Health_Check__mdt loadCheck(
    String checkDeveloperName,
    String checkSetDeveloperName
  ) {
    return loadCheck(checkDeveloperName, checkSetDeveloperName, true);
  }

  /**
   * Loads a Check scoped to the named Check Set. When requireActive is false,
   * inactive Checks are returned so callers can distinguish CHECK_INACTIVE from
   * CHECK_NOT_FOUND.
   */
  public Record_Health_Check__mdt loadCheck(
    String checkDeveloperName,
    String checkSetDeveloperName,
    Boolean requireActive
  ) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before check evaluation.
    List<Record_Health_Check__mdt> checks = [
      SELECT
        DeveloperName,
        MasterLabel,
        CheckTitle__c,
        CheckDescription__c,
        EvaluationOrder__c,
        IsActive__c,
        EvaluationType__c,
        FailureSeverity__c,
        PassConditionFormula__c,
        DisplayFoundFormula__c,
        DisplayExpectedFormula__c,
        FindInListFormula__c,
        FormulaResultType__c,
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
        DisplayValueFormat__c,
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
        Record_Health_Check_Set__c,
        Record_Health_Check_Set__r.DeveloperName,
        Record_Health_Check_Set__r.MasterLabel,
        Record_Health_Check_Set__r.CardTitle__c,
        Record_Health_Check_Set__r.CardSubtitle__c,
        Record_Health_Check_Set__r.IsActive__c,
        Record_Health_Check_Set__r.ObjectApiName__c,
        Record_Health_Check_Set__r.ShowDiagnostics__c
      FROM Record_Health_Check__mdt
      WHERE
        DeveloperName = :checkDeveloperName
        AND Record_Health_Check_Set__r.DeveloperName = :checkSetDeveloperName
      LIMIT 1
    ];
    if (checks.isEmpty()) {
      return null;
    }
    Record_Health_Check__mdt check = checks[0];
    if (requireActive == true && check.IsActive__c != true) {
      return null;
    }
    return check;
  }

  // ─── Per-type validation — first-fail adapter over RecordHealthCheckValidator ───
  // The per-type decision tree lives in RecordHealthCheckValidator; these wrappers take
  // the FIRST finding (first-fail order) and map it via toResult. MaxRows and null/empty-behavior
  // are appended only for Query / CompareTwoQueries.

  /**
   * Validates the ApplicabilityMode check (Formula / SOQL sub-fields). Returns null when the
   * check is valid (or mode is Always/blank).
   */
  private RecordHealthCheckInternalResult validateApplicability(
    Record_Health_Check__mdt check
  ) {
    return firstResult(
      RecordHealthCheckValidator.applicabilityFindings(check),
      check
    );
  }

  private RecordHealthCheckInternalResult validateFormulaCheck(
    Record_Health_Check__mdt check
  ) {
    return firstResult(
      RecordHealthCheckValidator.formulaFindings(check),
      check
    );
  }

  private RecordHealthCheckInternalResult validateQueryCheck(
    Record_Health_Check__mdt check
  ) {
    List<RecordHealthCheckValidator.Finding> findings = RecordHealthCheckValidator.queryFindings(
      check
    );
    findings.addAll(RecordHealthCheckValidator.maxRowsFindings(check));
    findings.addAll(RecordHealthCheckValidator.nullEmptyFindings(check));
    return firstResult(findings, check);
  }

  private RecordHealthCheckInternalResult validateApexCheck(
    Record_Health_Check__mdt check
  ) {
    return firstResult(RecordHealthCheckValidator.apexFindings(check), check);
  }

  private RecordHealthCheckInternalResult validateCompareQueriesCheck(
    Record_Health_Check__mdt check
  ) {
    List<RecordHealthCheckValidator.Finding> findings = RecordHealthCheckValidator.compareQueriesFindings(
      check
    );
    findings.addAll(RecordHealthCheckValidator.maxRowsFindings(check));
    findings.addAll(RecordHealthCheckValidator.nullEmptyFindings(check));
    return firstResult(findings, check);
  }

  private RecordHealthCheckInternalResult firstResult(
    List<RecordHealthCheckValidator.Finding> findings,
    Record_Health_Check__mdt check
  ) {
    return RecordHealthCheckConfigFindingMapper.firstResult(findings, check);
  }

  private RecordHealthCheckInternalResult buildUnableResult(
    Record_Health_Check__mdt check,
    String reasonCode,
    String detail
  ) {
    return RecordHealthCheckConfigFindingMapper.buildUnableResult(
      check,
      reasonCode,
      detail
    );
  }
}
