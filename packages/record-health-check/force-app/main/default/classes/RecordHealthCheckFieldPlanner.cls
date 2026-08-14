/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckFieldPlanner {
  @TestVisible
  private Boolean multiCurrencyOrganizationOverride;
  // GROUP BY / aggregate detection lives in RecordHealthCheckSoqlTemplate,
  // the single SOQL-shape authority.

  // Caps how deep a formula → formula → … chain is walked when expanding
  // calculated-field dependencies, so a misconfigured or cyclic graph can never
  // run away. The visited set already breaks true cycles; this is a hard ceiling.
  private static final Integer FORMULA_DEPENDENCY_DEPTH_CAP = 10;

  @TestVisible
  private Map<String, String> calculatedFormulaOverrideByField;
  private Set<String> inaccessibleFieldsBeingPlanned;
  private Map<String, String> unresolvedReasonCodesBeingPlanned;
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
    if (
      info.inaccessible ||
      (info.describe != null && !info.describe.isAccessible())
    ) {
      return RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE;
    }
    return info.unresolvedReasonCode;
  }

  /** Returns the terminal describe type for a resolved field path. */
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
    verdictDependenciesTruncatedBeingPlanned = false;
    Set<String> fields = new Set<String>{ 'Id' };

    // Token syntax and registry membership were validated when the check loaded;
    // collect the referenced record fields needed for message rendering.
    addMergeFields(fields, objectType, check.FailureMessage__c);
    addMergeFields(fields, objectType, check.UnableToEvaluateMessage__c);
    addMergeFields(fields, objectType, check.ApplicabilityNotMetMessage__c);
    // Remediation link fields may carry {!record.FieldName} tokens (including relationship
    // paths like {!record.Owner.ManagerId}); load their fields so the token resolves.
    addMergeFields(fields, objectType, check.ActionUrl__c);
    addMergeFields(fields, objectType, check.ActionLabel__c);
    addMergeFields(fields, objectType, check.FixMessage__c);
    addMergeFields(fields, objectType, check.SourceQuery__c);
    addMergeFields(fields, objectType, check.ComparisonQuery__c);
    addMergeFields(fields, objectType, check.ApplicabilityCountQuery__c);
    // Author wording for the Found / Expected values may reference record fields
    // alongside the computed count and value tokens. Every Evaluation Type whose
    // Found / Expected values the Framework writes can carry it.
    addMergeFields(fields, objectType, check.DisplayFoundText__c);
    addMergeFields(fields, objectType, check.DisplayExpectedText__c);

    if (check.EvaluationType__c == 'FORMULA') {
      addFormulaFields(fields, objectType, check.PassConditionFormula__c, true);
      // Optional Found / Expected single-value formulas get the SAME calculated-field
      // dependency expansion as the pass/fail formula, so a balance check whose
      // operands are formula fields can display resolved numbers instead of UNABLE.
      addFormulaFields(fields, objectType, check.DisplayFoundFormula__c, false);
      addFormulaFields(
        fields,
        objectType,
        check.DisplayExpectedFormula__c,
        false
      );
    }
    if (check.EvaluationType__c == 'QUERY') {
      // List checks read the single-value from FindInListFormula__c; RecordFormula compares to ExpectedRecordFormula__c.
      addFormulaFields(fields, objectType, check.FindInListFormula__c, true);
      addFormulaFields(
        fields,
        objectType,
        check.ExpectedRecordFormula__c,
        true
      );
    }
    // CompareTwoQueries: both sides are SOQL — merge tokens already handled above
    if (check.ApplicabilityMode__c == 'WHEN_FORMULA_TRUE') {
      addFormulaFields(fields, objectType, check.ApplicabilityFormula__c, true);
    }

    // In an org with more than one currency, an amount is shown in the record's
    // own currency, so the record has to carry it. Asked for whatever the Check's
    // Display: Value Format says, because Auto may still resolve to Currency
    // from the field's own definition. One standard field on a query that
    // already selects the Check's fields.
    fields.addAll(
      shouldSelectCurrencyField(
          multiCurrencyOrganizationOverride == null
            ? UserInfo.isMultiCurrencyOrganization()
            : multiCurrencyOrganizationOverride,
          RecordHealthCheckDescribeCache.fieldMap(objectType).keySet()
        )
        ? new Set<String>{ 'CurrencyIsoCode' }
        : new Set<String>()
    );

    FieldPlan result = new FieldPlan();
    result.selectedFields.addAll(fields);
    result.inaccessibleFields.addAll(inaccessibleFieldsBeingPlanned);
    result.unresolvedReasonCodesByField.putAll(
      unresolvedReasonCodesBeingPlanned
    );
    result.verdictDependenciesTruncated = verdictDependenciesTruncatedBeingPlanned;
    inaccessibleFieldsBeingPlanned = null;
    unresolvedReasonCodesBeingPlanned = null;
    verdictDependenciesTruncatedBeingPlanned = null;
    return result;
  }

  private Boolean shouldSelectCurrencyField(
    Boolean multiCurrencyOrganization,
    Set<String> availableFields
  ) {
    return multiCurrencyOrganization &&
      availableFields.contains('currencyisocode');
  }

  private void addMergeFields(
    Set<String> fields,
    Schema.SObjectType objectType,
    String template
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
  }

  private void addFormulaFields(
    Set<String> fields,
    Schema.SObjectType objectType,
    String formula,
    Boolean verdictAffecting
  ) {
    if (String.isBlank(formula)) {
      return;
    }
    // Walk the full dependency tree rooted at the record's own type. The visited
    // set is shared across the whole walk. Its keys include the complete path
    // from the root record, so repeated references to one calculated field are
    // deduplicated without collapsing the same field reached through two
    // different relationships.
    expandFormulaDependencies(
      fields,
      objectType,
      objectType,
      formula,
      '',
      0,
      new Set<String>(),
      verdictAffecting
    );
  }

  /** Recursively expands calculated-field operands into selectable source fields. */
  private void expandFormulaDependencies(
    Set<String> fields,
    Schema.SObjectType baseType,
    Schema.SObjectType resolveType,
    String formula,
    String pathPrefix,
    Integer depth,
    Set<String> visited,
    Boolean verdictAffecting
  ) {
    if (String.isBlank(formula)) {
      return;
    }
    for (
      RecordHealthCheckFormulaFieldScanner.FieldReference reference : RecordHealthCheckFormulaFieldScanner.scan(
        formula,
        resolveType
      )
    ) {
      String token = reference.path;
      // Add the operand to the SELECT, rooted at the record's own type so the
      // path is valid in the SOQL even when we are deep inside a cross-object
      // formula definition.
      addReadableField(fields, baseType, pathPrefix + token, reference);

      // If the operand is itself a calculated field, expand the fields ITS
      // definition references so the whole chain can be regenerated.
      CalculatedDependency dependency = calculatedDependency(
        resolveType,
        token,
        reference,
        pathPrefix
      );
      if (
        dependency != null &&
        depth < FORMULA_DEPENDENCY_DEPTH_CAP &&
        visited.add(
          pathPrefix + dependency.relationshipPrefix + dependency.visitKey
        )
      ) {
        expandFormulaDependencies(
          fields,
          baseType,
          dependency.ownerType,
          dependency.formula,
          pathPrefix + dependency.relationshipPrefix,
          depth + 1,
          visited,
          verdictAffecting
        );
      } else if (
        dependency != null &&
        depth >= FORMULA_DEPENDENCY_DEPTH_CAP &&
        verdictAffecting
      ) {
        verdictDependenciesTruncatedBeingPlanned = true;
      }
    }
  }

  private CalculatedDependency calculatedDependency(
    Schema.SObjectType resolveType,
    String token,
    RecordHealthCheckFormulaFieldScanner.FieldReference reference,
    String pathPrefix
  ) {
    FieldPathDescribe info = describeFieldPath(resolveType, token, reference);
    if (
      calculatedFormulaOverrideByField != null &&
      (calculatedFormulaOverrideByField.containsKey(pathPrefix + token) ||
      calculatedFormulaOverrideByField.containsKey(token))
    ) {
      String overrideFormula = calculatedFormulaOverrideByField.containsKey(
          pathPrefix + token
        )
        ? calculatedFormulaOverrideByField.get(pathPrefix + token)
        : calculatedFormulaOverrideByField.get(token);
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
    } else if (
      info != null &&
      (info.inaccessible || info.describe != null) &&
      inaccessibleFieldsBeingPlanned != null
    ) {
      inaccessibleFieldsBeingPlanned.add(fieldPath);
    } else if (
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

  /**
   * Resolves a (possibly relationship-qualified) field path against a starting
   * type, returning the terminal field's describe plus the owning type and the
   * relationship prefix needed to root nested dependencies back at the path.
   * Lookups are case-insensitive (a token typed as `website` or
   * `BILLINGCITY` still resolves against the lowercase Schema field map).
   * Missing schema and inaccessible schema are returned explicitly so callers
   * can keep them distinct while excluding both from the user-mode SELECT.
   */
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
      if (
        !RecordHealthCheckDescribeCache.describeField(relationshipField)
          .isAccessible()
      ) {
        FieldPathDescribe inaccessible = new FieldPathDescribe();
        inaccessible.inaccessible = true;
        return inaccessible;
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
    Schema.SObjectField terminal = getFieldCaseInsensitive(
      RecordHealthCheckDescribeCache.fieldMap(currentType),
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

  /** Resolves admin-authored field names using the native case-insensitive map. */
  private Schema.SObjectField getFieldCaseInsensitive(
    Map<String, Schema.SObjectField> fieldMap,
    String name
  ) {
    // Schema.DescribeSObjectResult.fields.getMap() is natively
    // case-insensitive. DescribeCache deliberately returns that native map;
    // replacing it with a copied map would require explicit key normalization.
    return fieldMap.get(name);
  }

  /** Selects a safe flat-SOQL target and fails closed for ambiguous polymorphism. */
  private Schema.SObjectType selectReferenceType(
    List<Schema.SObjectType> candidates,
    String nextPathPart
  ) {
    if (candidates.size() == 1) {
      return candidates[0];
    }
    // Flat SOQL exposes a polymorphic relationship through the Name entity.
    // A field present on only one concrete candidate still requires TYPEOF;
    // choosing that candidate here would emit an invalid flat SELECT.
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

  private class CalculatedDependency {
    private String formula;
    private String visitKey;
    private Schema.SObjectType ownerType;
    private String relationshipPrefix;
  }

  /** Per-Check field requirements separated by the running user's access. */
  public class FieldPlan {
    public Set<String> selectedFields = new Set<String>();
    public Set<String> inaccessibleFields = new Set<String>();
    public Map<String, String> unresolvedReasonCodesByField = new Map<String, String>();
    public Boolean verdictDependenciesTruncated = false;
  }
}
