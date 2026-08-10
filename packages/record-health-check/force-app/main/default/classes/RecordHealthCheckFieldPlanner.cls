/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckFieldPlanner {
  @TestVisible
  private Boolean multiCurrencyOrganizationOverride;
  private static final Pattern PATTERN_DOT_PATH = Pattern.compile(
    '\\b([A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]+)+)\\b'
  );
  private static final Pattern PATTERN_WORD = Pattern.compile(
    '\\b[A-Za-z_][A-Za-z0-9_]*\\b'
  );
  // GROUP BY / aggregate detection lives in RecordHealthCheckSoqlTemplate,
  // the single SOQL-shape authority.

  // Caps how deep a formula → formula → … chain is walked when expanding
  // calculated-field dependencies, so a misconfigured or cyclic graph can never
  // run away. The visited set already breaks true cycles; this is a hard ceiling.
  private static final Integer FORMULA_DEPENDENCY_DEPTH_CAP = 10;

  @TestVisible
  private Map<String, String> calculatedFormulaOverrideByField;
  private Set<String> inaccessibleFieldsBeingPlanned;

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
      addFormulaFields(fields, objectType, check.PassConditionFormula__c);
      // Optional Found / Expected single-value formulas get the SAME calculated-field
      // dependency expansion as the pass/fail formula, so a balance check whose
      // operands are formula fields can display resolved numbers instead of UNABLE.
      addFormulaFields(fields, objectType, check.DisplayFoundFormula__c);
      addFormulaFields(fields, objectType, check.DisplayExpectedFormula__c);
    }
    if (check.EvaluationType__c == 'QUERY') {
      // List checks read the single-value from FindInListFormula__c; RecordFormula compares to ExpectedRecordFormula__c.
      addFormulaFields(fields, objectType, check.FindInListFormula__c);
      addFormulaFields(fields, objectType, check.ExpectedRecordFormula__c);
    }
    // CompareTwoQueries: both sides are SOQL — merge tokens already handled above
    if (check.ApplicabilityMode__c == 'WHEN_FORMULA_TRUE') {
      addFormulaFields(fields, objectType, check.ApplicabilityFormula__c);
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
    inaccessibleFieldsBeingPlanned = null;
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
    String formula
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
      new Set<String>()
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
    Set<String> visited
  ) {
    if (String.isBlank(formula) || depth > FORMULA_DEPENDENCY_DEPTH_CAP) {
      return;
    }

    for (String token : scanFormulaFieldTokens(formula)) {
      // Add the operand to the SELECT, rooted at the record's own type so the
      // path is valid in the SOQL even when we are deep inside a cross-object
      // formula definition.
      addReadableField(fields, baseType, pathPrefix + token);

      // If the operand is itself a calculated field, expand the fields ITS
      // definition references so the whole chain can be regenerated.
      CalculatedDependency dependency = calculatedDependency(
        resolveType,
        token
      );
      if (dependency != null && visited.add(dependency.visitKey)) {
        expandFormulaDependencies(
          fields,
          baseType,
          dependency.ownerType,
          dependency.formula,
          pathPrefix + dependency.relationshipPrefix,
          depth + 1,
          visited
        );
      }
    }
  }

  private CalculatedDependency calculatedDependency(
    Schema.SObjectType resolveType,
    String token
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
    FieldPathDescribe info = describeFieldPath(resolveType, token);
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

  /**
   * Scans a formula expression for the field references it contains, in document
   * order and de-duplicated. Relationship paths (e.g. Parent.ShippingCity) are
   * captured whole first so a word-only scan does not split them into bare names;
   * single-segment field names follow. Formula function names and literals are
   * excluded, and double-quoted string literals are masked so a value such as
   * "example.com" is never mistaken for a relationship path.
   */
  private List<String> scanFormulaFieldTokens(String formula) {
    List<String> tokens = new List<String>();
    Set<String> seen = new Set<String>();
    String scannable = maskFormulaStringLiterals(formula);

    Matcher dotMatcher = PATTERN_DOT_PATH.matcher(scannable);
    while (dotMatcher.find()) {
      String path = dotMatcher.group(1);
      if (seen.add(path)) {
        tokens.add(path);
      }
    }

    Matcher wordMatcher = PATTERN_WORD.matcher(scannable);
    while (wordMatcher.find()) {
      String word = wordMatcher.group(0);
      if (RecordHealthCheckFormulaSyntax.isSyntaxWord(word)) {
        continue;
      }
      if (seen.add(word)) {
        tokens.add(word);
      }
    }
    return tokens;
  }

  private String maskFormulaStringLiterals(String formula) {
    List<String> masked = new List<String>();
    Boolean inQuote = false;
    for (Integer i = 0; i < formula.length(); i++) {
      String ch = formula.substring(i, i + 1);
      if (ch == '"' && (i == 0 || formula.substring(i - 1, i) != '\\')) {
        inQuote = !inQuote;
        masked.add('"');
      } else {
        masked.add(inQuote ? ' ' : ch);
      }
    }
    return String.join(masked, '');
  }

  private void addReadableField(
    Set<String> fields,
    Schema.SObjectType objectType,
    String fieldPath
  ) {
    FieldPathDescribe info = describeFieldPath(objectType, fieldPath);
    if (info != null && info.describe != null && info.describe.isAccessible()) {
      fields.add(fieldPath);
    } else if (
      info != null &&
      info.describe != null &&
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
    String fieldPath
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
      if (
        relationshipField == null ||
        !RecordHealthCheckDescribeCache.describeField(relationshipField)
          .isAccessible()
      ) {
        return null;
      }
      List<Schema.SObjectType> referenceTypes = RecordHealthCheckDescribeCache.describeField(
          relationshipField
        )
        .getReferenceTo();
      relationshipParts.add(parts[i]);
      currentType = selectReferenceType(referenceTypes, parts[i + 1]);
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

  private Schema.SObjectType selectReferenceType(
    List<Schema.SObjectType> candidates,
    String nextPathPart
  ) {
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
    return candidates[0];
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
  }
}
