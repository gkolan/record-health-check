/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Everything a {!rhcQuery...} token must satisfy before a Check can run.
 *
 * These rules live apart from the rest of configuration validation because they
 * all answer one question the other rules never ask: does this token address
 * something the Check's own query can actually produce? Each of them exists
 * because the alternative was a Check that validated cleanly and then rendered
 * a sentence with a hole in it, or worse, a plausible wrong number.
 */
public with sharing class RecordHealthCheckQueryTokenRules {
  /**
   * Checks every {!rhcQuery...} token in a Check against the query it addresses.
   *
   * Validation happens here, while the author is still looking at the field,
   * because none of these faults can be detected at resolution time without
   * either disclosing data the query never selected or silently inserting a
   * blank. The projection analysis fails closed: a SELECT list this framework
   * cannot fully read proves nothing about what it omitted, so a token against
   * it is refused rather than assumed valid.
   */
  public static RecordHealthCheckTokenIssue firstIssue(
    Record_Health_Check__mdt check
  ) {
    if (check == null) {
      return null;
    }
    Boolean queryCheck =
      check.EvaluationType__c == 'QUERY' ||
      check.EvaluationType__c == 'COMPARE_TWO_QUERIES';
    // The same field-to-surface table the parser rules walk, so neither
    // validator can drift about which fields a Check writes. Surfaces that
    // refuse rhcQuery outright are skipped: the parser has already reported
    // any query token on them.
    for (
      List<Object> entry : RecordHealthCheckConfigValidator.templateSurfaces(
        check
      )
    ) {
      if (
        !RecordHealthCheckTokenSurfaces.allows((String) entry[1], 'rhcQuery')
      ) {
        continue;
      }
      for (
        RecordHealthCheckToken token : RecordHealthCheckTemplateService.parse(
          (String) entry[0]
        )
      ) {
        if (token.namespaceName != 'rhcQuery' || token.shape == null) {
          continue;
        }
        RecordHealthCheckTokenIssue issue = queryTokenIssue(
          check,
          token,
          queryCheck
        );
        if (issue != null) {
          return issue;
        }
      }
    }
    return null;
  }

  /**
   * Why a Check cannot produce the rows a token addresses, or null when it can.
   *
   * A filled-in query field is not the same as a query that runs. A
   * list-membership Check takes its source value from Value to find in the list
   * (formula) and never queries the primary side, and a Check comparing against
   * a fixed value or a record formula never runs its Comparison Query. In both
   * cases the field can be left populated from earlier editing, and a token
   * trusting the field alone validated and then rendered nothing.
   */
  private static String unavailableRoleReason(
    Record_Health_Check__mdt check,
    Boolean comparison,
    String soql
  ) {
    String role = comparison ? 'Comparison Query' : 'Source Query';
    String collection = comparison ? 'comparisonRows' : 'sourceRows';
    if (String.isBlank(soql)) {
      return 'This Check has no ' +
        role +
        ', so it produces no ' +
        collection +
        '.';
    }
    if (
      !comparison &&
      check.EvaluationType__c == 'QUERY' &&
      String.isNotBlank(check.FindInListFormula__c)
    ) {
      return 'This Check takes the value under test from Value to find in ' +
        'the list (formula), so it never queries the primary side and ' +
        'produces no sourceRows. The rows it does return are comparisonRows.';
    }
    if (
      comparison &&
      check.EvaluationType__c == 'QUERY' &&
      String.isNotBlank(check.ExpectedValueSource__c) &&
      check.ExpectedValueSource__c != 'COMPARISON_QUERY' &&
      String.isBlank(check.FindInListFormula__c)
    ) {
      return 'Compare Against is "' +
        check.ExpectedValueSource__c +
        '", so this Check never runs its Comparison Query and produces no ' +
        'comparisonRows.';
    }
    return null;
  }

  private static RecordHealthCheckTokenIssue queryTokenIssue(
    Record_Health_Check__mdt check,
    RecordHealthCheckToken token,
    Boolean queryCheck
  ) {
    if (!queryCheck) {
      return new RecordHealthCheckTokenIssue(
        'TOKEN_NOT_ALLOWED_ON_SURFACE',
        token.expression,
        'Query row tokens need a Check that runs a query. This Check is a ' +
          RecordHealthCheckConstants.toLwcEvaluatorType(
            check.EvaluationType__c
          ) +
          ' Check.'
      );
    }
    RecordHealthCheckTokenShape shape = token.shape;
    Boolean comparison = shape.readsComparisonQuery();
    String soql = comparison ? check.ComparisonQuery__c : check.SourceQuery__c;
    String unavailable = unavailableRoleReason(check, comparison, soql);
    if (unavailable != null) {
      return new RecordHealthCheckTokenIssue(
        'QUERY_ROLE_NOT_AVAILABLE',
        token.expression,
        unavailable
      );
    }
    // A row count reads no column and does not depend on the order rows came
    // back in, so neither the projection nor the ordering rule applies to it.
    // Only the query it counts has to exist, which was settled above.
    if (shape.kind == RecordHealthCheckTokenShape.KIND_QUERY_ROW_COUNT) {
      // Except against a counting query, where the two meanings diverge and the
      // wrong one is the plausible one. SELECT COUNT() returns a single row
      // holding the total, so counting the rows returns 1 no matter how many
      // records matched, and "This account has 1 contacts" is a lie the author
      // has no way to notice.
      if (RecordHealthCheckSoqlTemplate.isSingleCountQuery(soql)) {
        return new RecordHealthCheckTokenIssue(
          'QUERY_ROLE_NOT_AVAILABLE',
          token.expression,
          'The ' +
            (comparison ? 'Comparison Query' : 'Source Query') +
            ' counts records rather than returning them, so counting its rows ' +
            'always gives 1. Use {!rhcResult.foundValue} for the number it ' +
            'counted, or alias the count as in SELECT COUNT(Id) total and use ' +
            '{!rhcQuery.sourceRows[0].total}.'
        );
      }
      return null;
    }
    RecordHealthCheckQueryProjection projection = RecordHealthCheckQueryProjection.of(
      soql
    );
    if (!projection.isFullyAnalyzable) {
      return new RecordHealthCheckTokenIssue(
        'QUERY_PROJECTION_NOT_ANALYZABLE',
        token.expression,
        'This framework cannot read every column of that query, so it cannot ' +
          'prove the token only reads a field the query selected. Simplify ' +
          'the SELECT list, or remove the query row token.'
      );
    }
    if (!projection.projects(shape.fieldPath)) {
      return new RecordHealthCheckTokenIssue(
        'QUERY_FIELD_NOT_SELECTED',
        token.expression,
        'Add ' +
          shape.fieldPath +
          ' to the SELECT list of the ' +
          (comparison ? 'Comparison Query' : 'Source Query') +
          ' to use this token. It currently selects: ' +
          String.join(projection.addressableNames(), ', ') +
          '.'
      );
    }
    String queryLabel = comparison ? 'Comparison Query' : 'Source Query';
    // An aggregate with no GROUP BY returns exactly one row whatever the data,
    // so index 0 is repeatable without an ORDER BY — and SOQL would reject
    // one anyway, because an aggregate cannot be ordered by an ungrouped field.
    if (projection.returnsExactlyOneRow()) {
      return shape.rowIndex == 0
        ? null
        : new RecordHealthCheckTokenIssue(
            'TOKEN_ROW_INDEX_INVALID',
            token.expression,
            'The ' +
              queryLabel +
              ' returns exactly one row, so only index 0 exists.'
          );
    }
    if (!projection.hasStableRowOrder()) {
      // Telling the author of a grouped query to add ", Id" would be advice
      // SOQL refuses, so a grouped aggregate is named for what it is instead.
      return new RecordHealthCheckTokenIssue(
        'QUERY_ORDER_NOT_DETERMINISTIC',
        token.expression,
        projection.hasGroupBy
          ? 'A grouped query returns one row per group in no guaranteed ' +
            'order, and SOQL cannot order it by Id. Read the value with an ' +
            'aggregate alias on a query that returns a single row, or drop ' +
            'the row token.'
          : 'Addressing a row by position needs a repeatable order. Add a ' +
            'stable tie-breaker such as ", Id" to the ORDER BY of the ' +
            queryLabel +
            '.'
      );
    }
    // One Result evaluation refuses the moment a second row comes back, so a
    // token addressing one is unreachable by construction: either the Check
    // fails on cardinality before the message is written, or there was only
    // ever one row. Either way index 1 is never rendered.
    if (shape.rowIndex > 0 && check.QueryResultHandling__c == 'ONE_RESULT') {
      return new RecordHealthCheckTokenIssue(
        'TOKEN_ROW_INDEX_INVALID',
        token.expression,
        'How To Interpret Query Results is "One Result", so this Check never ' +
          'has more than one row. Address index 0, or choose a multi-row ' +
          'handling mode.'
      );
    }
    Integer cap = check.MaxQueryRows__c == null
      ? RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS
      : Integer.valueOf(check.MaxQueryRows__c);
    String capSource = 'This Check returns at most ' + cap + ' rows';
    // The query's own LIMIT is the tighter ceiling whenever it is present. A
    // Check may allow 200 rows while its query asks for five.
    if (projection.outerLimit != null && projection.outerLimit < cap) {
      cap = projection.outerLimit;
      capSource =
        'The ' +
        queryLabel +
        ' ends in LIMIT ' +
        cap +
        ', so it returns at most that many rows';
    }
    if (shape.rowIndex >= cap) {
      return new RecordHealthCheckTokenIssue(
        'TOKEN_ROW_INDEX_INVALID',
        token.expression,
        capSource + ', so index ' + shape.rowIndex + ' can never exist.'
      );
    }
    RecordHealthCheckTokenIssue encrypted = encryptedFieldIssue(
      shape,
      projection,
      queryLabel,
      token
    );
    return encrypted != null
      ? encrypted
      : currencyBasisIssue(
          token,
          shape,
          projection,
          queryLabel,
          RecordHealthCheckDisplayCurrencyResolver.isMultiCurrencyOrg()
        );
  }

  /**
   * Keeps Classic encrypted values out of messages, labels, and links.
   *
   * A user without View Encrypted Data reads a masked string, so a token that
   * names one produces asterisks in a sentence or, worse, in a URL. A user with
   * the permission gets the real value copied into text that is stored on the
   * result and can travel further than the field's own protection intends.
   * Neither is a reasonable rendering, so the field is refused rather than
   * rendered one way for some readers and another way for others.
   */
  private static RecordHealthCheckTokenIssue encryptedFieldIssue(
    RecordHealthCheckTokenShape shape,
    RecordHealthCheckQueryProjection projection,
    String queryLabel,
    RecordHealthCheckToken token
  ) {
    Schema.SObjectType objectType = RecordHealthCheckDescribeCache.resolveSObjectType(
      projection.objectApiName
    );
    if (objectType == null) {
      return null;
    }
    Schema.DisplayType fieldType = new RecordHealthCheckFieldPlanner()
      .resolvedDisplayType(objectType, shape.fieldPath);
    if (fieldType != Schema.DisplayType.ENCRYPTEDSTRING) {
      return null;
    }
    return new RecordHealthCheckTokenIssue(
      RecordHealthCheckReasonCodes.FIELD_TYPE_NOT_SUPPORTED,
      token.expression,
      shape.fieldPath +
        ' on the ' +
        queryLabel +
        ' is an encrypted field. Encrypted values cannot be placed in a ' +
        'message, label, or link: readers without View Encrypted Data would ' +
        'see only mask characters, and readers with it would have the value ' +
        'copied into text that outlives the field. Reference a different field.'
    );
  }

  /**
   * True when this token will be rendered through the currency renderer.
   *
   * An explicit CURRENCY format says so outright. Auto says it only when the
   * field itself is a currency field, which is the slip worth catching: the
   * author wrote nothing about currency, and the value still renders as money
   * in whatever unit the renderer falls back to. A bare token with no format
   * attribute is plain text and never reaches the currency renderer.
   */
  private static Boolean needsCurrencyBasis(
    RecordHealthCheckToken token,
    RecordHealthCheckTokenShape shape,
    RecordHealthCheckQueryProjection projection
  ) {
    if (token.formatName == RecordHealthCheckDisplayFormat.FORMAT_CURRENCY) {
      return true;
    }
    if (token.formatName != RecordHealthCheckDisplayFormat.FORMAT_AUTO) {
      return false;
    }
    Schema.SObjectType objectType = RecordHealthCheckDescribeCache.resolveSObjectType(
      projection.objectApiName
    );
    if (objectType == null) {
      return false;
    }
    return new RecordHealthCheckFieldPlanner()
        .resolvedDisplayType(objectType, shape.fieldPath) ==
      Schema.DisplayType.CURRENCY;
  }

  /**
   * Requires a currency-formatted row value to carry its own currency.
   *
   * In a multi-currency org an amount means nothing without the unit it is
   * stated in, and the framework reads that unit from the row the value came
   * from. If the query never selected CurrencyIsoCode there is no unit to
   * read, and the amount renders in whatever currency the renderer falls back
   * to — a number that looks right and is wrong. Single-currency orgs have one
   * unit by definition, so the rule does not apply to them.
   *
   * The org's currency mode arrives as an argument rather than being read here,
   * so the policy can be exercised on both sides of that condition. An org has
   * one currency mode and cannot be asked to pretend otherwise, and a rule that
   * only runs in half the orgs it ships to is a rule nobody has read.
   */
  @TestVisible
  private static RecordHealthCheckTokenIssue currencyBasisIssue(
    RecordHealthCheckToken token,
    RecordHealthCheckTokenShape shape,
    RecordHealthCheckQueryProjection projection,
    String queryLabel,
    Boolean isMultiCurrencyOrg
  ) {
    if (isMultiCurrencyOrg != true) {
      return null;
    }
    // Salesforce converts an ungrouped aggregate to corporate currency and
    // refuses to select a bare CurrencyIsoCode beside it — "Field must be
    // grouped or aggregated". Asking for one would be advice the author cannot
    // follow. The single-row exit above already skips this rule for such a
    // query; the guard is repeated here so reordering these checks cannot
    // quietly reintroduce the demand.
    if (projection.returnsExactlyOneRow()) {
      return null;
    }
    if (!needsCurrencyBasis(token, shape, projection)) {
      return null;
    }
    // The unit lives beside the amount, so a path through a relationship needs
    // that relationship's own CurrencyIsoCode.
    Integer lastDot = shape.fieldPath.lastIndexOf('.');
    String isoPath = lastDot < 0
      ? 'CurrencyIsoCode'
      : shape.fieldPath.substring(0, lastDot + 1) + 'CurrencyIsoCode';
    if (projection.projects(isoPath)) {
      return null;
    }
    return new RecordHealthCheckTokenIssue(
      'FIXED_CURRENCY_BASIS_MISSING',
      token.expression,
      'This org uses several currencies, so a currency-formatted value needs ' +
        'the currency it is stated in. Add ' +
        isoPath +
        ' to the SELECT list of the ' +
        queryLabel +
        ', or drop format="CURRENCY".'
    );
  }
}
