/** Rewrites supported record-token SOQL shapes into scope-wide queries. */
public with sharing class RecordHealthCheckBulkQueryRewriter {
  private static final String CORRELATION_ALIAS = 'rhcCorrelation';
  private static final Pattern ORDER_BY = Pattern.compile(
    '(?i)\\bORDER\\s+BY\\s+([A-Za-z_][A-Za-z0-9_.]*)\\s*(ASC|DESC)?'
  );
  private static final Pattern SELECT_LIST_PATTERN = Pattern.compile(
    '(?is)^\\s*SELECT\\s+(.*?)\\s+FROM\\b'
  );

  /** Adds a field to the outer SELECT list when it is not already selected. */
  public static String injectSelectField(String soql, String fieldPath) {
    for (String selectedField : selectedFields(soql)) {
      if (selectedField.trim().equalsIgnoreCase(fieldPath)) {
        return soql;
      }
    }
    Matcher matcher = Pattern.compile('(?i)\\bSELECT\\b').matcher(soql);
    if (!matcher.find()) {
      return soql;
    }
    return soql.substring(0, matcher.end()) +
      ' ' +
      fieldPath +
      ', ' +
      soql.substring(matcher.end()).trim();
  }

  /** Aliases a leading correlation field added for AggregateResult lookup. */
  public static String aliasCorrelation(String soql, String fieldPath) {
    Matcher selectMatcher = Pattern.compile('(?i)\\bSELECT\\b').matcher(soql);
    if (!selectMatcher.find()) {
      return soql;
    }
    String afterSelect = soql.substring(selectMatcher.end()).trim();
    String injectedPrefix = fieldPath + ',';
    if (!afterSelect.startsWith(injectedPrefix)) {
      return soql;
    }
    return soql.substring(0, selectMatcher.end()) +
      ' ' +
      fieldPath +
      ' ' +
      CORRELATION_ALIAS +
      ',' +
      afterSelect.substring(injectedPrefix.length());
  }

  /** Adds an outer GROUP BY before any tail clause. */
  public static String appendGroupBy(String soql, String fieldPath) {
    Matcher tail = Pattern.compile(
        '(?i)\\b(ORDER\\s+BY|LIMIT|OFFSET|WITH\\s+(?:USER_MODE|SECURITY_ENFORCED))\\b'
      )
      .matcher(soql);
    if (!tail.find()) {
      return soql.trim() + ' GROUP BY ' + fieldPath;
    }
    return soql.substring(0, tail.start()).trim() +
      ' GROUP BY ' +
      fieldPath +
      ' ' +
      soql.substring(tail.start()).trim();
  }

  /** Rewrites ORDER BY ... LIMIT 1 as a grouped MIN/MAX aggregate. */
  public static String rewriteOrderedPickAggregate(
    String soql,
    String correlationField
  ) {
    List<String> selected = selectedFields(soql);
    String orderField = firstGroup(soql, ORDER_BY, 1);
    String direction = firstGroup(soql, ORDER_BY, 2);
    String functionName = direction != null &&
      direction.equalsIgnoreCase('DESC')
      ? 'MAX'
      : 'MIN';
    Matcher selectMatcher = SELECT_LIST_PATTERN.matcher(soql);
    if (!selectMatcher.find() || selected.size() != 1) {
      throw new RecordHealthCheckEvaluatorException(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        'An ordered aggregate pick must select exactly one field.'
      );
    }
    String replacement =
      'SELECT ' +
      correlationField +
      ' ' +
      CORRELATION_ALIAS +
      ', ' +
      functionName +
      '(' +
      orderField +
      ') ' +
      selected[0] +
      ' FROM';
    String rewritten =
      soql.substring(0, selectMatcher.start()) +
      replacement +
      soql.substring(selectMatcher.end());
    rewritten = rewritten.replaceFirst(
      '(?is)\\s+ORDER\\s+BY\\s+[A-Za-z_][A-Za-z0-9_.]*\\s*(?:ASC|DESC)?(?:\\s+NULLS\\s+(?:FIRST|LAST))?\\s+LIMIT\\s+1\\b',
      ''
    );
    return appendGroupBy(rewritten, correlationField);
  }

  /** Returns the outer SELECT expressions in source order. */
  public static List<String> selectedFields(String soql) {
    Matcher matcher = SELECT_LIST_PATTERN.matcher(soql);
    return matcher.find()
      ? matcher.group(1).split('\\s*,\\s*')
      : new List<String>();
  }

  private static String firstGroup(
    String value,
    Pattern pattern,
    Integer groupNumber
  ) {
    Matcher matcher = pattern.matcher(value);
    return matcher.find() ? matcher.group(groupNumber) : null;
  }
}
