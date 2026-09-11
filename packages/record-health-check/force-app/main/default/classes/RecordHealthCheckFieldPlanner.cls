/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */
@SuppressWarnings('PMD.IfStmtsMustUseBraces,PMD.IfElseStmtsMustUseBraces')
public with sharing class RecordHealthCheckFieldPlanner {
  @TestVisible
  private Boolean multiCurrencyOrganizationOverride;
  private static final Integer FORMULA_DEPENDENCY_DEPTH_CAP = 10;
  @TestVisible
  private Map<String, String> calculatedFormulaOverrideByField;
  private Set<String> inaccessibleFieldsBeingPlanned;
  private Map<String, String> unresolvedReasonCodesBeingPlanned;
  private List<RecordHealthCheckFormulaPlanService.Finding> formulaFindingsBeingPlanned;
  private Boolean formulaFindingsTruncatedBeingPlanned;
  private String formulaReturnTypeBeingPlanned;
  private Boolean verdictDependenciesTruncatedBeingPlanned;
  public Set<String> collectRecordFields(
    Record_Health_Check__mdt check,
    Schema.SObjectType objectType
  ) {
    return planRecordFields(check, objectType).selectedFields;
  }
  /**
   * Resolves one configured path using the same describe rules as record planning.
   * @param objectType Root Salesforce object type.
   * @param fieldPath Field or relationship path to resolve.
   * @return Null when readable, otherwise a stable access or resolution reason.
   */
  public String resolutionReasonCode(
    Schema.SObjectType objectType,
    String fieldPath
  ) {
    FieldPathDescribe info = describeFieldPath(objectType, fieldPath, null);
    // prettier-ignore
    if (info.inaccessible || (info.describe != null && !info.describe.isAccessible())) return RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE;
    return info.unresolvedReasonCode;
  }
  public Schema.DisplayType resolvedDisplayType(
    Schema.SObjectType objectType,
    String fieldPath
  ) {
    FieldPathDescribe info = describeFieldPath(objectType, fieldPath, null);
    return info.describe == null ? null : info.describe.getType();
  }
  /**
   * Plans the selectable and inaccessible record fields for one Check.
   *
   * @param check Check whose runtime surfaces may reference record fields.
   * @param objectType Root record type selected by the owning Check Set.
   * @return Per-Check field plan used to isolate FLS failures.
   */
  public FieldPlan planRecordFields(
    Record_Health_Check__mdt check,
    Schema.SObjectType objectType
  ) {
    inaccessibleFieldsBeingPlanned = new Set<String>();
    unresolvedReasonCodesBeingPlanned = new Map<String, String>();
    formulaFindingsBeingPlanned = new List<RecordHealthCheckFormulaPlanService.Finding>();
    formulaFindingsTruncatedBeingPlanned = false;
    formulaReturnTypeBeingPlanned = check.FormulaResultType__c;
    verdictDependenciesTruncatedBeingPlanned = false;
    Set<String> fields = new Set<String>{ 'Id' };
    addMergeFields(
      fields,
      objectType,
      check.FailureMessage__c,
      'FailureMessage__c'
    );
    addMergeFields(
      fields,
      objectType,
      check.UnableToEvaluateMessage__c,
      'UnableToEvaluateMessage__c'
    );
    addMergeFields(
      fields,
      objectType,
      check.ApplicabilityNotMetMessage__c,
      'ApplicabilityNotMetMessage__c'
    );
    addMergeFields(fields, objectType, check.ActionUrl__c, 'ActionUrl__c');
    addMergeFields(fields, objectType, check.ActionLabel__c, 'ActionLabel__c');
    addMergeFields(fields, objectType, check.FixMessage__c, 'FixMessage__c');
    addMergeFields(fields, objectType, check.SourceQuery__c, 'SourceQuery__c');
    addMergeFields(
      fields,
      objectType,
      check.ComparisonQuery__c,
      'ComparisonQuery__c'
    );
    addMergeFields(
      fields,
      objectType,
      check.ApplicabilityCountQuery__c,
      'ApplicabilityCountQuery__c'
    );
    addMergeFields(
      fields,
      objectType,
      check.DisplayFoundText__c,
      'DisplayFoundText__c'
    );
    addMergeFields(
      fields,
      objectType,
      check.DisplayExpectedText__c,
      'DisplayExpectedText__c'
    );
    if (check.EvaluationType__c == 'FORMULA') {
      addFormulaFields(
        fields,
        objectType,
        check.PassConditionFormula__c,
        'PassConditionFormula__c',
        true
      );
      addFormulaFields(
        fields,
        objectType,
        check.DisplayFoundFormula__c,
        'DisplayFoundFormula__c',
        false
      );
      addFormulaFields(
        fields,
        objectType,
        check.DisplayExpectedFormula__c,
        'DisplayExpectedFormula__c',
        false
      );
    }
    if (check.EvaluationType__c == 'QUERY') {
      addFormulaFields(
        fields,
        objectType,
        check.FindInListFormula__c,
        'FindInListFormula__c',
        true
      );
      addFormulaFields(
        fields,
        objectType,
        check.ExpectedRecordFormula__c,
        'ExpectedRecordFormula__c',
        true
      );
    }
    if (check.ApplicabilityMode__c == 'WHEN_FORMULA_TRUE') {
      if (
        !RecordHealthCheckScopeResultSupport.isPersonAccountExclusionAutomaticallyMet(
          objectType,
          check.ApplicabilityFormula__c
        )
      ) {
        addFormulaFields(
          fields,
          objectType,
          check.ApplicabilityFormula__c,
          'ApplicabilityFormula__c',
          true
        );
      }
    }
    Boolean multiCurrency = multiCurrencyOrganizationOverride == null
      ? UserInfo.isMultiCurrencyOrganization()
      : multiCurrencyOrganizationOverride;
    fields.addAll(
      multiCurrency &&
        RecordHealthCheckDescribeCache.fieldMap(objectType)
          .containsKey('CurrencyIsoCode')
        ? new Set<String>{ 'CurrencyIsoCode' }
        : new Set<String>()
    );

    FieldPlan result = new FieldPlan();
    result.selectedFields.addAll(fields);
    result.inaccessibleFields.addAll(inaccessibleFieldsBeingPlanned);
    result.unresolvedReasonCodesByField.putAll(
      unresolvedReasonCodesBeingPlanned
    );
    result.formulaFindings.addAll(formulaFindingsBeingPlanned);
    result.formulaFindingsTruncated = formulaFindingsTruncatedBeingPlanned;
    result.verdictDependenciesTruncated = verdictDependenciesTruncatedBeingPlanned;
    inaccessibleFieldsBeingPlanned = null;
    unresolvedReasonCodesBeingPlanned = null;
    formulaFindingsBeingPlanned = null;
    formulaFindingsTruncatedBeingPlanned = null;
    formulaReturnTypeBeingPlanned = null;
    verdictDependenciesTruncatedBeingPlanned = null;
    return result;
  }

  private void addMergeFields(
    Set<String> fields,
    Schema.SObjectType objectType,
    String template,
    String configurationField
  ) {
    if (String.isBlank(template)) {
      return;
    }
    for (
      String fieldPath : RecordHealthCheckTemplateService.recordPaths(
        template,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      )
    ) {
      addReadableField(fields, objectType, fieldPath);
    }
    for (
      RecordHealthCheckFormulaPlanService.Finding finding : RecordHealthCheckMergeFindingService.findings(
        template,
        configurationField,
        objectType,
        this
      )
    ) {
      if (
        formulaFindingsBeingPlanned.size() >=
        RecordHealthCheckFormulaPlanService.FINDING_LIMIT
      ) {
        formulaFindingsTruncatedBeingPlanned = true;
        break;
      }
      formulaFindingsBeingPlanned.add(finding);
    }
  }
  private void addFormulaFields(
    Set<String> fields,
    Schema.SObjectType objectType,
    String formula,
    String configurationField,
    Boolean verdictAffecting
  ) {
    if (String.isBlank(formula)) {
      return;
    }
    RecordHealthCheckFormulaPlanService.FormulaPlan sharedPlan = RecordHealthCheckFormulaPlanService.plan(
      formula,
      objectType,
      configurationField,
      formulaReturnTypeBeingPlanned,
      this
    );
    fields.addAll(sharedPlan.selectedFields);
    for (
      RecordHealthCheckFormulaPlanService.Finding finding : sharedPlan.findings
    ) {
      String plannedPath = String.isBlank(finding.dependencyPath)
        ? finding.offendingToken
        : finding.dependencyPath;
      if (finding.code == RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE) {
        inaccessibleFieldsBeingPlanned.add(plannedPath);
      } else if (
        finding.code == RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED ||
        finding.code == RecordHealthCheckReasonCodes.RELATIONSHIP_NOT_RESOLVED
      ) {
        unresolvedReasonCodesBeingPlanned.put(plannedPath, finding.code);
      }
      if (
        formulaFindingsBeingPlanned.size() <
        RecordHealthCheckFormulaPlanService.FINDING_LIMIT
      ) {
        formulaFindingsBeingPlanned.add(finding);
      } else {
        formulaFindingsTruncatedBeingPlanned = true;
      }
    }
    formulaFindingsTruncatedBeingPlanned =
      formulaFindingsTruncatedBeingPlanned || sharedPlan.findingsTruncated;
    if (verdictAffecting) {
      for (
        RecordHealthCheckFormulaPlanService.Finding finding : sharedPlan.findings
      ) {
        if (
          finding.code ==
          RecordHealthCheckReasonCodes.FORMULA_DEPENDENCY_DEPTH_EXCEEDED
        ) {
          verdictDependenciesTruncatedBeingPlanned = true;
        }
      }
    }
  }

  /** Describes one calculated field for shared dependency planning. */
  public CalculatedDependency calculatedDependency(
    Schema.SObjectType resolveType,
    String token,
    RecordHealthCheckFormulaFieldScanner.FieldReference reference,
    String pathPrefix
  ) {
    FieldPathDescribe info = describeFieldPath(resolveType, token, reference);
    if (
      calculatedFormulaOverrideByField != null &&
      calculatedFormulaOverrideByField.containsKey(pathPrefix + token)
    ) {
      String overrideFormula = calculatedFormulaOverrideByField.get(
        pathPrefix + token
      );
      return buildCalculatedDependency(
        overrideFormula,
        info == null || info.describe == null ? resolveType : info.ownerType,
        info == null || info.describe == null ? token : info.describe.getName(),
        info == null || info.describe == null ? '' : info.relationshipPrefix
      );
    }
    // prettier-ignore
    if (info == null || info.describe == null || !info.describe.isCalculated() || String.isBlank(info.describe.getCalculatedFormula())) {
      return null;
    }
    // prettier-ignore
    return buildCalculatedDependency(info.describe.getCalculatedFormula(), info.ownerType, info.describe.getName(), info.relationshipPrefix);
  }

  private CalculatedDependency buildCalculatedDependency(
    String formula,
    Schema.SObjectType ownerType,
    String fieldName,
    String relationshipPrefix
  ) {
    CalculatedDependency dependency = new CalculatedDependency();
    dependency.formula = formula;
    dependency.visitKey = String.valueOf(ownerType) + '.' + fieldName;
    dependency.ownerType = ownerType;
    dependency.relationshipPrefix = relationshipPrefix;
    return dependency;
  }

  private void addReadableField(
    Set<String> fields,
    Schema.SObjectType objectType,
    String fieldPath
  ) {
    addReadableField(fields, objectType, fieldPath, null);
  }

  private void addReadableField(
    Set<String> fields,
    Schema.SObjectType objectType,
    String fieldPath,
    RecordHealthCheckFormulaFieldScanner.FieldReference reference
  ) {
    FieldPathDescribe info = describeFieldPath(
      objectType,
      fieldPath,
      reference
    );
    if (info != null && info.describe != null && info.describe.isAccessible()) {
      fields.add(fieldPath);
      // prettier-ignore
    } else {
      addInaccessibleField(inaccessibleFieldsBeingPlanned, fieldPath, info);
    }
    if (
      (info == null || (!info.inaccessible && info.describe == null)) &&
      info != null &&
      info.unresolvedReasonCode != null &&
      unresolvedReasonCodesBeingPlanned != null
    ) {
      unresolvedReasonCodesBeingPlanned.put(
        fieldPath,
        info.unresolvedReasonCode
      );
    }
  }

  private static void addInaccessibleField(
    Set<String> fields,
    String fieldPath,
    FieldPathDescribe info
  ) {
    if (
      fields != null &&
      info != null &&
      (info.inaccessible || info.describe != null)
    ) {
      fields.add(fieldPath);
    }
  }

  private FieldPathDescribe describeFieldPath(
    Schema.SObjectType objectType,
    String fieldPath,
    RecordHealthCheckFormulaFieldScanner.FieldReference reference
  ) {
    List<String> parts = fieldPath.split('\\.');
    Schema.SObjectType currentType = objectType;
    List<String> relationshipParts = new List<String>();
    for (Integer i = 0; i < parts.size() - 1; i++) {
      Map<String, Schema.SObjectField> currentFields = RecordHealthCheckDescribeCache.fieldMap(
        currentType
      );
      Schema.SObjectField relationshipField = findRelationshipField(
        currentFields,
        parts[i]
      );
      if (relationshipField == null) {
        return unresolvedPath(
          RecordHealthCheckReasonCodes.RELATIONSHIP_NOT_RESOLVED
        );
      }
      // prettier-ignore
      if (!RecordHealthCheckDescribeCache.describeField(relationshipField).isAccessible()) {
        FieldPathDescribe inaccessible = new FieldPathDescribe(); inaccessible.inaccessible = true; return inaccessible;
      }
      List<Schema.SObjectType> referenceTypes = RecordHealthCheckDescribeCache.describeField(
          relationshipField
        )
        .getReferenceTo();
      relationshipParts.add(parts[i]);
      currentType = reference != null &&
        reference.relationshipType != null &&
        parts[i].equalsIgnoreCase(reference.typedRelationship)
        ? reference.relationshipType
        : selectReferenceType(referenceTypes, parts[i + 1]);
      if (currentType == null) {
        return unresolvedPath(
          RecordHealthCheckReasonCodes.RELATIONSHIP_NOT_RESOLVED
        );
      }
    }
    Schema.SObjectField terminal = RecordHealthCheckDescribeCache.resolveField(
      currentType,
      parts[parts.size() - 1]
    );
    if (terminal == null) {
      return unresolvedPath(RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED);
    }
    FieldPathDescribe out = new FieldPathDescribe();
    out.describe = RecordHealthCheckDescribeCache.describeField(terminal);
    out.ownerType = currentType;
    out.relationshipPrefix = relationshipParts.isEmpty()
      ? ''
      : String.join(relationshipParts, '.') + '.';
    return out;
  }

  private FieldPathDescribe unresolvedPath(String reasonCode) {
    FieldPathDescribe unresolved = new FieldPathDescribe();
    unresolved.unresolvedReasonCode = reasonCode;
    return unresolved;
  }

  private Schema.SObjectType selectReferenceType(
    List<Schema.SObjectType> candidates,
    String nextPathPart
  ) {
    if (candidates.size() == 1) {
      return candidates[0];
    }
    if (!RecordHealthCheckFormulaFieldScanner.isNameEntityPath(nextPathPart)) {
      return null;
    }
    for (Schema.SObjectType candidate : candidates) {
      Map<String, Schema.SObjectField> fields = RecordHealthCheckDescribeCache.fieldMap(
        candidate
      );
      if (fields.get(nextPathPart) != null) {
        return candidate;
      }
      if (findRelationshipField(fields, nextPathPart) != null) {
        return candidate;
      }
    }
    return null;
  }

  /**
   * Finds the field whose relationship name matches `relName` (case-insensitive)
   * e.g. `Parent` → the ParentId lookup, `Account__r` → the Account__c lookup.
   */
  private Schema.SObjectField findRelationshipField(
    Map<String, Schema.SObjectField> fieldMap,
    String relName
  ) {
    for (Schema.SObjectField candidate : fieldMap.values()) {
      Schema.DescribeFieldResult description = RecordHealthCheckDescribeCache.describeField(
        candidate
      );
      if (
        description.getRelationshipName() != null &&
        description.getRelationshipName().equalsIgnoreCase(relName)
      ) {
        return candidate;
      }
    }
    return null;
  }

  private class FieldPathDescribe {
    Schema.DescribeFieldResult describe;
    Schema.SObjectType ownerType;
    String relationshipPrefix;
    Boolean inaccessible = false;
    String unresolvedReasonCode;
  }

  public class CalculatedDependency {
    public String formula { get; private set; }
    public String visitKey { get; private set; }
    public Schema.SObjectType ownerType { get; private set; }
    public String relationshipPrefix { get; private set; }
  }

  /** Per-Check field requirements separated by the running user's access. */
  public class FieldPlan {
    public Set<String> selectedFields = new Set<String>();
    public Set<String> inaccessibleFields = new Set<String>();
    public Map<String, String> unresolvedReasonCodesByField = new Map<String, String>();
    public List<RecordHealthCheckFormulaPlanService.Finding> formulaFindings = new List<RecordHealthCheckFormulaPlanService.Finding>();
    public Boolean formulaFindingsTruncated = false;
    public Boolean verdictDependenciesTruncated = false;
  }
}
