/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Loads and validates Check Set definitions for the runtime service.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckDefinitionLoader {
  private static final Set<String> VALID_DISPLAY_MODES = RecordHealthCheckConstants.validDisplayModes;
  private static final Set<String> VALID_SUMMARY_DISPLAYS = RecordHealthCheckConstants.validSummaryDisplays;
  private static final Set<String> VALID_TRIGGER_MODES = RecordHealthCheckConstants.validTriggerModes;
  private static final Set<String> VALID_RUN_BUTTON_DISPLAYS = RecordHealthCheckConstants.validRunButtonDisplays;
  private static final Set<String> VALID_REVEAL_MODES = RecordHealthCheckConstants.validRevealModes;
  private static final Set<String> VALID_COMPARISON_DISPLAYS = RecordHealthCheckConstants.validComparisonDisplays;
  private static final Integer FRAMEWORK_MAX_CHECKS = RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS;
  private static final String RC_CONFIG_NOT_FOUND = RecordHealthCheckConfigService.RC_CONFIG_NOT_FOUND;
  private static final String RC_CONFIG_INACTIVE = RecordHealthCheckConfigService.RC_CONFIG_INACTIVE;
  private static final String RC_INVALID_CONFIG = RecordHealthCheckConfigService.RC_INVALID_CONFIG;
  private static final String RC_OBJECT_MISMATCH = RecordHealthCheckConfigService.RC_OBJECT_MISMATCH;
  private static final String RC_NO_RECORD_CONTEXT = RecordHealthCheckConfigService.RC_NO_RECORD_CONTEXT;
  private static final String RC_NO_ACTIVE_CHECKS = RecordHealthCheckConfigService.RC_NO_ACTIVE_CHECKS;

  /**
   * Loads and validates a Check Set and its active checks.
   *
   * @param service Service that loads the selected Custom Metadata.
   * @param checkSetQualifiedApiName Exact selected Check Set identity.
   * @param recordId Record page context used to enforce the configured object.
   * @return Complete definition response within the Check limit.
   * @throws RecordHealthCheckConfigService.ConfigException for missing, inactive, mismatched, empty, or invalid configuration.
   */
  public static RecordHealthCheckDefinitionResponse getDefinitionResponse(
    RecordHealthCheckConfigService service,
    String checkSetQualifiedApiName,
    Id recordId
  ) {
    // Normalize at the service boundary so whitespace/blank is rejected before SOQL;
    // blank → CONFIG_NOT_FOUND.
    checkSetQualifiedApiName = RecordHealthCheckLogger.normalizeIdentifier(
      checkSetQualifiedApiName,
      80
    );
    if (String.isBlank(checkSetQualifiedApiName)) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'No Check Set is selected for this Record Health Check component.',
        RC_CONFIG_NOT_FOUND
      );
    }

    if (recordId == null) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'This component needs a record page context before it can run health checks.',
        RC_NO_RECORD_CONTEXT
      );
    }

    // Load Check Set
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before definitions are exposed.
    List<Record_Health_Check_Set__mdt> checkSets = [
      SELECT
        QualifiedApiName,
        DeveloperName,
        MasterLabel,
        CardTitle__c,
        CardSubtitle__c,
        ObjectApiName__c,
        IsActive__c,
        CardRunMode__c,
        RunButtonDisplay__c,
        RunButtonLabel__c,
        RerunButtonLabel__c,
        RunButtonIcon__c,
        PassedChecksDisplay__c,
        SkippedChecksDisplay__c,
        SummaryDisplay__c,
        CardRevealMode__c,
        FoundExpectedDisplay__c,
        StopOnSystemError__c,
        ShowDiagnostics__c
      FROM Record_Health_Check_Set__mdt
      WHERE QualifiedApiName = :checkSetQualifiedApiName
      LIMIT 1
    ];

    if (checkSets.isEmpty()) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Check Set "' + checkSetQualifiedApiName + '" was not found.',
        RC_CONFIG_NOT_FOUND
      );
    }

    Record_Health_Check_Set__mdt checkSet = checkSets[0];
    String resolvedDeveloperName = checkSet.DeveloperName;
    validateCheckSetForDefinition(checkSet, resolvedDeveloperName, recordId);

    // Load active checks — only the fields needed to build RecordHealthCheckDefinition.
    // Full evaluation fields are fetched per-check at evaluation time via loadCheck().
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before definitions are exposed.
    List<Record_Health_Check__mdt> allChecks = [
      SELECT
        QualifiedApiName,
        DeveloperName,
        CheckTitle__c,
        CheckDescription__c,
        Category__c,
        EvaluationOrder__c,
        PrerequisiteCheck__c
      FROM Record_Health_Check__mdt
      WHERE
        Record_Health_Check_Set__r.QualifiedApiName = :checkSetQualifiedApiName
        AND IsActive__c = TRUE
      ORDER BY EvaluationOrder__c ASC NULLS LAST, DeveloperName ASC
    ];

    validateActiveChecksForDefinition(allChecks, checkSet.QualifiedApiName);

    Integer totalAvailable = allChecks.size();
    Boolean checksOmitted = totalAvailable > FRAMEWORK_MAX_CHECKS;
    List<Record_Health_Check__mdt> checksForRun = selectChecksForRun(allChecks);
    Integer inactiveCheckCount = countInactiveChecks(checkSet.QualifiedApiName);

    // Build response
    RecordHealthCheckDefinitionResponse response = new RecordHealthCheckDefinitionResponse();
    response.checkSetQualifiedApiName = checkSet.QualifiedApiName;
    // Card Title is a required presentation contract validated above.
    response.displayTitle = definitionTitle(checkSet);
    response.displayDescription = checkSet.CardSubtitle__c;
    response.triggerMode = RecordHealthCheckConstants.toLwcTriggerMode(
      checkSet.CardRunMode__c
    );
    response.runButtonDisplay = RecordHealthCheckConstants.normalizedRunButtonDisplay(
      checkSet.RunButtonDisplay__c
    );
    response.runButtonLabel = checkSet.RunButtonLabel__c;
    response.rerunButtonLabel = checkSet.RerunButtonLabel__c;
    response.runButtonIcon = checkSet.RunButtonIcon__c;
    response.revealMode = RecordHealthCheckConstants.toLwcRevealMode(
      checkSet.CardRevealMode__c
    );
    response.successDisplayMode = RecordHealthCheckConstants.toLwcDisplayMode(
      checkSet.PassedChecksDisplay__c
    );
    response.skippedDisplayMode = RecordHealthCheckConstants.toLwcDisplayMode(
      checkSet.SkippedChecksDisplay__c
    );
    response.summaryDisplay = RecordHealthCheckConstants.normalizedSummaryDisplay(
      checkSet.SummaryDisplay__c
    );
    response.comparisonDisplay = RecordHealthCheckConstants.toLwcComparisonDisplay(
      comparisonDisplay(checkSet)
    );
    response.stopOnFirstError = checkSet.StopOnSystemError__c;
    response.showDiagnostics = canShowDiagnostics(checkSet);
    response.totalAvailableCheckCount = totalAvailable;
    response.frameworkMaxChecks = RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS;
    response.checksOmittedByLimit = checksOmitted;
    response.inactiveCheckCount = inactiveCheckCount;
    // Check names are configuration detail, so they ride along only for the
    // diagnostics audience that already sees troubleshooting fields.
    response.inactiveCheckLabels = inactiveCheckLabelsForDiagnostics(
      response.showDiagnostics,
      inactiveCheckCount,
      checkSet.QualifiedApiName
    );

    // Log WARN when active checks exceed FRAMEWORK_MAX_CHECKS, so truncation is
    // visible server-side and not only in the LWC "First 25 of N shown" badge.
    logCheckLimitExceededWhenNeeded(
      resolvedDeveloperName,
      recordId,
      totalAvailable
    );

    response.checks = new List<RecordHealthCheckDefinition>();
    Map<String, String> categoryLabels = categoryLabelsByValue();

    for (Record_Health_Check__mdt check : checksForRun) {
      RecordHealthCheckDefinition def = new RecordHealthCheckDefinition();
      def.qualifiedApiName = check.QualifiedApiName;
      def.developerName = check.DeveloperName;
      def.label = check.CheckTitle__c;
      def.description = check.CheckDescription__c;
      def.category = check.Category__c;
      def.categoryLabel = categoryLabelFor(categoryLabels, check.Category__c);
      def.priority = check.EvaluationOrder__c;
      def.dependsOnCheckDeveloperName = normalizedPrerequisite(
        check.PrerequisiteCheck__c
      );
      def.dependsOnCheckQualifiedApiName = RHCDefinitionDependencyIdentity.resolve(
        check,
        allChecks
      );
      response.checks.add(def);
    }

    return response;
  }

  private static Map<String, String> categoryLabelsByValue() {
    Map<String, String> labels = new Map<String, String>();
    for (
      Schema.PicklistEntry entry : Record_Health_Check__mdt.Category__c.getDescribe()
        .getPicklistValues()
    ) {
      labels.put(entry.getValue(), entry.getLabel());
    }
    return labels;
  }

  @TestVisible
  private static List<String> inactiveCheckLabelsForDiagnostics(
    Boolean showDiagnostics,
    Integer inactiveCheckCount,
    String checkSetQualifiedApiName
  ) {
    return showDiagnostics == true &&
      inactiveCheckCount > 0
      ? inactiveCheckLabels(checkSetQualifiedApiName)
      : new List<String>();
  }

  @TestVisible
  private static String categoryLabelFor(
    Map<String, String> categoryLabels,
    String category
  ) {
    return String.isBlank(category) ? null : categoryLabels.get(category);
  }

  @TestVisible
  private static String normalizedPrerequisite(String prerequisite) {
    return String.isNotBlank(prerequisite) ? prerequisite.trim() : null;
  }

  @TestVisible
  private static void logCheckLimitExceededWhenNeeded(
    String checkSetDeveloperName,
    Id recordId,
    Integer totalAvailable
  ) {
    if (totalAvailable > FRAMEWORK_MAX_CHECKS) {
      logCheckLimitExceeded(checkSetDeveloperName, recordId, totalAvailable);
    }
  }

  public static void logCheckLimitExceeded(
    String checkSetDeveloperName,
    Id recordId,
    Integer totalAvailable
  ) {
    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.WARN,
      null,
      checkSetDeveloperName,
      recordId,
      null,
      'CHECK_LIMIT_EXCEEDED',
      new Map<String, Object>{
        'totalAvailable' => totalAvailable,
        'maxPerRun' => FRAMEWORK_MAX_CHECKS,
        'omitted' => totalAvailable - FRAMEWORK_MAX_CHECKS
      },
      null
    );
  }

  public static void validateCheckSetForDefinition(
    Record_Health_Check_Set__mdt checkSet,
    String checkSetDeveloperName,
    Id recordId
  ) {
    if (checkSet.IsActive__c == false) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Check Set "' + checkSetDeveloperName + '" is inactive.',
        RC_CONFIG_INACTIVE
      );
    }

    if (String.isBlank(checkSet.ObjectApiName__c)) {
      // A blank Base Object misconfigures an existing Check Set; it does not mean
      // the Check Set is missing, so classify it as INVALID_CONFIG.
      throw new RecordHealthCheckConfigService.ConfigException(
        'Check Set "' +
          checkSetDeveloperName +
          '" is missing its Record Object API Name.',
        RC_INVALID_CONFIG
      );
    }
    if (
      !RecordHealthCheckConfigValidator.isValidObjectApiName(
        checkSet.ObjectApiName__c
      )
    ) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Record Object API Name "' +
          checkSet.ObjectApiName__c +
          '" on Check Set "' +
          checkSetDeveloperName +
          '" is not valid.',
        RC_INVALID_CONFIG
      );
    }

    String recordObjectType = RecordHealthCheckDescribeCache.objectApiName(
      recordId
    );
    if (
      String.isBlank(recordObjectType) ||
      !recordObjectType.equalsIgnoreCase(checkSet.ObjectApiName__c)
    ) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Check Set "' +
          checkSetDeveloperName +
          '" is for "' +
          checkSet.ObjectApiName__c +
          '", but this page is for "' +
          recordObjectType +
          '".',
        RC_OBJECT_MISMATCH
      );
    }

    if (!VALID_DISPLAY_MODES.contains(checkSet.PassedChecksDisplay__c)) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Passed Checks Display "' +
          checkSet.PassedChecksDisplay__c +
          '" is not recognized. Valid values: SHOW_EACH_CHECK, SHOW_COUNT_ONLY.',
        RC_INVALID_CONFIG
      );
    }
    if (!VALID_DISPLAY_MODES.contains(checkSet.SkippedChecksDisplay__c)) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Skipped Checks Display "' +
          checkSet.SkippedChecksDisplay__c +
          '" is not recognized. Valid values: SHOW_EACH_CHECK, SHOW_COUNT_ONLY.',
        RC_INVALID_CONFIG
      );
    }
    String summaryDisplay = RecordHealthCheckConstants.normalizedSummaryDisplay(
      checkSet.SummaryDisplay__c
    );
    if (!VALID_SUMMARY_DISPLAYS.contains(summaryDisplay)) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Summary Display "' +
          checkSet.SummaryDisplay__c +
          '" is not recognized. Valid values: TOP, BOTTOM.',
        RC_INVALID_CONFIG
      );
    }
    if (!VALID_TRIGGER_MODES.contains(checkSet.CardRunMode__c)) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'When Checks Run "' +
          checkSet.CardRunMode__c +
          '" is not recognized. Valid values: RUN_ON_LOAD, RUN_ON_REQUEST.',
        RC_INVALID_CONFIG
      );
    }
    String runButtonDisplay = RecordHealthCheckConstants.normalizedRunButtonDisplay(
      checkSet.RunButtonDisplay__c
    );
    if (!VALID_RUN_BUTTON_DISPLAYS.contains(runButtonDisplay)) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Run Button Display "' +
          checkSet.RunButtonDisplay__c +
          '" is not recognized. Valid values: LABEL_AND_ICON, LABEL_ONLY, ICON_ONLY, HIDE.',
        RC_INVALID_CONFIG
      );
    }
    if (
      checkSet.CardRunMode__c == 'RUN_ON_REQUEST' &&
      runButtonDisplay == 'HIDE'
    ) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Run Button Display cannot be Hide when When Checks Run is "When the user clicks Run". Use a visible Run Button Display or run checks when the page opens.',
        RC_INVALID_CONFIG
      );
    }
    if (!VALID_REVEAL_MODES.contains(checkSet.CardRevealMode__c)) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Reveal Mode "' +
          checkSet.CardRevealMode__c +
          '" is not recognized. Valid values: ALL_AT_ONCE, ONE_BY_ONE.',
        RC_INVALID_CONFIG
      );
    }
    if (String.isBlank(checkSet.CardTitle__c)) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Card Title is required on Check Set "' + checkSetDeveloperName + '".',
        RC_INVALID_CONFIG
      );
    }
    if (
      String.isBlank(checkSet.FoundExpectedDisplay__c) ||
      !VALID_COMPARISON_DISPLAYS.contains(checkSet.FoundExpectedDisplay__c)
    ) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Found/Expected Display "' +
          checkSet.FoundExpectedDisplay__c +
          '" is not recognized. Valid values: ON_DEMAND, FAILURES_ONLY, ALL_ROWS.',
        RC_INVALID_CONFIG
      );
    }
  }

  public static void validateActiveChecksForDefinition(
    List<Record_Health_Check__mdt> checks,
    String checkSetQualifiedApiName
  ) {
    if (checks.isEmpty()) {
      Integer inactiveCount = countInactiveChecks(checkSetQualifiedApiName);
      String detail = inactiveCount > 0
        ? ' (' + inactiveCount + ' inactive)'
        : '';
      throw new RecordHealthCheckConfigService.ConfigException(
        'Check Set "' +
          checkSetQualifiedApiName +
          '" has no active checks' +
          detail +
          '.',
        RC_NO_ACTIVE_CHECKS
      );
    }
  }

  /** Inactive Checks on the Check Set — omitted from the run, useful for admin UX. */
  public static Integer countInactiveChecks(String checkSetQualifiedApiName) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before definitions are exposed.
    return [
      SELECT COUNT()
      FROM Record_Health_Check__mdt
      WHERE
        Record_Health_Check_Set__r.QualifiedApiName = :checkSetQualifiedApiName
        AND IsActive__c = FALSE
    ];
  }

  /**
   * Display names of the inactive Checks, for the diagnostics "N Inactive"
   * tooltip. Capped at the framework check limit so a long-neglected Check Set
   * cannot make the tooltip too long; the pill still shows the exact count.
   */
  public static List<String> inactiveCheckLabels(
    String checkSetQualifiedApiName
  ) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before definitions are exposed.
    List<Record_Health_Check__mdt> inactiveChecks = [
      SELECT DeveloperName, MasterLabel, CheckTitle__c
      FROM Record_Health_Check__mdt
      WHERE
        Record_Health_Check_Set__r.QualifiedApiName = :checkSetQualifiedApiName
        AND IsActive__c = FALSE
      ORDER BY EvaluationOrder__c ASC NULLS LAST, DeveloperName ASC
      LIMIT :FRAMEWORK_MAX_CHECKS
    ];
    return inactiveCheckLabelsFrom(inactiveChecks);
  }

  public static List<String> inactiveCheckLabelsFrom(
    List<Record_Health_Check__mdt> inactiveChecks
  ) {
    List<String> labels = new List<String>();
    for (Record_Health_Check__mdt check : inactiveChecks) {
      labels.add(
        String.isNotBlank(check.CheckTitle__c)
          ? check.CheckTitle__c
          : (String.isNotBlank(check.MasterLabel)
              ? check.MasterLabel
              : check.DeveloperName)
      );
    }
    return labels;
  }

  public static String definitionTitle(Record_Health_Check_Set__mdt checkSet) {
    return checkSet.CardTitle__c;
  }

  public static String comparisonDisplay(
    Record_Health_Check_Set__mdt checkSet
  ) {
    return checkSet.FoundExpectedDisplay__c;
  }

  public static Boolean canShowDiagnostics(
    Record_Health_Check_Set__mdt checkSet
  ) {
    return checkSet.ShowDiagnostics__c == true &&
      RecordHealthCheckAccess.canViewDetails();
  }

  public static List<Record_Health_Check__mdt> selectChecksForRun(
    List<Record_Health_Check__mdt> allChecks
  ) {
    List<Record_Health_Check__mdt> checksForRun = new List<Record_Health_Check__mdt>();
    Integer checksToInclude = Math.min(FRAMEWORK_MAX_CHECKS, allChecks.size());
    for (Integer i = 0; i < checksToInclude; i++) {
      checksForRun.add(allChecks[i]);
    }
    return checksForRun;
  }
}
