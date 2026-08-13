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
  private Boolean verdictDependenciesTruncatedBeingPlanned;

  public Set<String> collectRecordFields(
    Record_Health_Check__mdt check,
    Schema.SObjectType objectType
  ) {
    return planRecordFields(check, objectType).selectedFields;
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
    result.verdictDependenciesTruncated = verdictDependenciesTruncatedBeingPlanned;
    inaccessibleFieldsBeingPlanned = null;
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
    // set is shared across the whole walk so a formula field reached by two paths
    // is only expanded once.
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

  /**
   * Adds every field a formula expression needs to the SELECT set — including the
   * transitive dependencies of any calculated (formula / roll-up) operand.
   * FormulaEval regenerates formula-field values from the in-memory SObject at
   * evaluation time, so a check like `FieldA__c > 0` — where `FieldA__c` is a
   * formula of `FieldX__c + FieldY__c` — needs FieldX__c and FieldY__c loaded
   * not just FieldA__c. Loading only the top-level name makes FormulaEval throw
   * "could not generate the requested field". This walks each referenced field's
   * own `getCalculatedFormula()` definition recursively until it reaches plain
   * source fields, for formulas of any return type (number, text, date, boolean
   * picklist) and any function — the expansion is driven by Schema, not by the
   * specific syntax used.
   * @param fields accumulating SELECT set (rooted at baseType)
   * @param baseType the record's SObjectType — the SELECT root; never changes
   * @param resolveType the type the CURRENT formula's tokens resolve against
   * (equals baseType at the top level, or a parent type when
   * recursing into a cross-object formula definition)
   * @param formula the formula text being scanned at this level
   * @param pathPrefix relationship path from baseType to resolveType, with a
   * trailing '.', or '' at the top level
   * @param depth current recursion depth (capped)
   * @param visited owner-qualified names of calculated fields already
   * expanded, to break cycles and re-convergent graphs
   */
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
        reference
      );
      if (
        dependency != null &&
        depth < FORMULA_DEPENDENCY_DEPTH_CAP &&
        visited.add(dependency.visitKey)
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
    RecordHealthCheckFormulaFieldScanner.FieldReference reference
  ) {
    if (
      calculatedFormulaOverrideByField != null &&
      calculatedFormulaOverrideByField.containsKey(token)
    ) {
      return buildCalculatedDependency(
        calculatedFormulaOverrideByField.get(token),
        resolveType,
        token,
        ''
      );
    }
    FieldPathDescribe info = describeFieldPath(resolveType, token, reference);
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
    }
  }

  /**
   * Resolves a (possibly relationship-qualified) field path against a starting
   * type, returning the terminal field's describe plus the owning type and the
   * relationship prefix needed to root nested dependencies back at the path.
   * Lookups are case-insensitive (a token typed as `website` or
   * `BILLINGCITY` still resolves against the lowercase Schema field map).
   * Returns null if any segment is missing or an intermediate relationship field
   * is inaccessible — the caller then simply skips the field.
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
        return null;
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
        return null;
      }
    }
    Schema.SObjectField terminal = getFieldCaseInsensitive(
      RecordHealthCheckDescribeCache.fieldMap(currentType),
      parts[parts.size() - 1]
    );
    if (terminal == null) {
      return null;
    }
    FieldPathDescribe out = new FieldPathDescribe();
    out.describe = RecordHealthCheckDescribeCache.describeField(terminal);
    out.ownerType = currentType;
    out.relationshipPrefix = relationshipParts.isEmpty()
      ? ''
      : String.join(relationshipParts, '.') + '.';
    return out;
  }

  /**
   * Case-insensitive field lookup against a Schema field map (whose keys are
   * lowercased), so admin-authored API names resolve regardless of typed case.
   */
  private Schema.SObjectField getFieldCaseInsensitive(
    Map<String, Schema.SObjectField> fieldMap,
    String name
  ) {
    // Schema.DescribeSObjectResult.fields.getMap() is natively
    // case-insensitive. DescribeCache deliberately returns that native map;
    // replacing it with a copied map would require explicit key normalization.
    return fieldMap.get(name);
  }

  /**
   * Picks the polymorphic candidate type whose schema actually contains the
   * next path segment. A single-candidate reference (the common, non-polymorphic
   * case) always resolves to that candidate. When two or more candidates exist
   * (genuine polymorphism, e.g. Owner: User or Group) and none of them exposes
   * the next segment, this fails closed by returning null rather than guessing
   * candidates[0] — a silent wrong-type guess can otherwise resolve to a
   * same-named-but-unrelated field on the wrong object. The caller treats null
   * exactly like any other unresolvable path: the field is skipped, which lets
   * FormulaEval surface UNABLE_TO_EVALUATE instead of a silently wrong value.
   */
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

  /** Terminal-field describe plus the context needed to root nested dependencies. */
  private class FieldPathDescribe {
    Schema.DescribeFieldResult describe;
    Schema.SObjectType ownerType;
    String relationshipPrefix;
    Boolean inaccessible = false;
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
    public Boolean verdictDependenciesTruncated = false;
  }
}
