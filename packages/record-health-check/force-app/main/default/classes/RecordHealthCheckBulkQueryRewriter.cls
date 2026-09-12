/** Rewrites supported record-token SOQL shapes into scope-wide queries. */
public with sharing class RecordHealthCheckBulkQueryRewriter {
  private static final String CORRELATION_ALIAS = 'rhcCorrelation';
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

  /** Adds a field to an existing outer GROUP BY, or creates one before the tail. */
  public static String appendGroupBy(String soql, String fieldPath) {
    Integer groupAt = outerClauseStart(soql, '\\bGROUP\\s+BY\\b');
    Integer tailAt = firstOuterTailStart(soql, groupAt >= 0);
    if (groupAt >= 0) {
      Integer groupEnd = tailAt >= 0 ? tailAt : soql.length();
      String groupClause = soql.substring(groupAt, groupEnd).trim();
      if (
        Pattern.compile('(?i)\\b(?:ROLLUP|CUBE)\\s*\\(')
          .matcher(groupClause)
          .find()
      ) {
        throw new RecordHealthCheckEvaluatorException(
          'UNSUPPORTED_BULK_QUERY_SHAPE',
          'GROUP BY ROLLUP and CUBE cannot be safely correlated to a record scope.'
        );
      }
      for (
        String groupedField : groupClause.replaceFirst(
            '(?i)^GROUP\\s+BY\\s+',
            ''
          )
          .split('\\s*,\\s*')
      ) {
        if (groupedField.trim().equalsIgnoreCase(fieldPath)) {
          return soql;
        }
      }
      return soql.substring(0, groupEnd).trim() +
        ', ' +
        fieldPath +
        (tailAt >= 0 ? ' ' + soql.substring(tailAt).trim() : '');
    }
    if (tailAt < 0) {
      return soql.trim() + ' GROUP BY ' + fieldPath;
    }
    return soql.substring(0, tailAt).trim() +
      ' GROUP BY ' +
      fieldPath +
      ' ' +
      soql.substring(tailAt).trim();
  }

  private static Integer firstOuterTailStart(
    String soql,
    Boolean includeHaving
  ) {
    Integer first = -1;
    List<String> patterns = new List<String>{
      '\\bORDER\\s+BY\\b',
      '\\bLIMIT\\b',
      '\\bOFFSET\\b'
    };
    if (includeHaving) {
      patterns.add('\\bHAVING\\b');
    }
    for (String patternValue : patterns) {
      Integer candidate = outerClauseStart(soql, patternValue);
      if (candidate >= 0 && (first < 0 || candidate < first)) {
        first = candidate;
      }
    }
    return first;
  }

  private static Integer outerClauseStart(String soql, String clausePattern) {
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(soql);
    Matcher matcher = Pattern.compile('(?i)' + clausePattern).matcher(masked);
    while (matcher.find()) {
      if (RecordHealthCheckSoqlTemplate.depthAt(masked, matcher.start()) == 0) {
        return matcher.start();
      }
    }
    return -1;
  }

  /** Returns the outer SELECT expressions in source order. */
  public static List<String> selectedFields(String soql) {
    Matcher matcher = SELECT_LIST_PATTERN.matcher(soql);
    return matcher.find()
      ? matcher.group(1).split('\\s*,\\s*')
      : new List<String>();
  }
}
