/**
 * Converts one supported record-token SOQL template into one scope-wide query
 * and attributes the returned rows back to every evaluated record.
 */
public with sharing class RecordHealthCheckBulkQuerySupport {
  public static final String SELF = 'SELF';
  public static final String CHILD_DIRECT = 'CHILD_DIRECT';
  public static final String CHILD_PATH = 'CHILD_PATH';
  public static final String INDIRECT_REFERENCE = 'TOKEN_INDIRECT';
  public static final String SCOPE_INVARIANT = 'SCOPE_INVARIANT';
  public static final String ORDERED_PICK_AGGREGATE = 'ORDERED_PICK_AGGREGATE';
  public static final String ORDERED_PICK_IN_MEMORY = 'ORDERED_PICK_IN_MEMORY';
  public static final String UNCLASSIFIED = 'UNCLASSIFIED';

  private static final String CORRELATION_ALIAS = 'rhcCorrelation';
  private static final Pattern TOKEN = Pattern.compile(
    '\\{!record\\.([A-Za-z0-9_.]+)\\}'
  );
  private static final Pattern EQUALITY = Pattern.compile(
    '([A-Za-z_][A-Za-z0-9_.]*)\\s*=\\s*\\{!record\\.([A-Za-z0-9_.]+)\\}'
  );
  private static final Pattern NEGATION = Pattern.compile(
    '([A-Za-z_][A-Za-z0-9_.]*)\\s*(?:!=|<>)\\s*\\{!record\\.([A-Za-z0-9_.]+)\\}'
  );
  private static final Pattern ORDER_BY = Pattern.compile(
    '(?i)\\bORDER\\s+BY\\s+([A-Za-z_][A-Za-z0-9_.]*)\\s*(ASC|DESC)?'
  );
  private static final Pattern LIMIT_PATTERN = Pattern.compile(
    '(?i)\\bLIMIT\\s+(\\d+)'
  );
  private static final Pattern MULTI_FIELD_ORDER_BY = Pattern.compile(
    '(?is)\\bORDER\\s+BY\\s+[^;]+?,[^;]+?(?:\\bLIMIT\\b|$)'
  );

  public class Result {
    public String strategy;
    public String executedSoql;
    public Map<Id, List<SObject>> rowsByRecordId = new Map<Id, List<SObject>>();
  }

  private class Correlation {
    private String fieldPath;
    private String tokenPath;
    private Integer startIndex;
    private Integer endIndex;
  }

  /** Executes one supported template for the complete loaded-record scope. */
  public static Result execute(
    String soqlTemplate,
    Map<Id, SObject> loadedRecords,
    Integer maxRows
  ) {
    if (loadedRecords == null) {
      loadedRecords = new Map<Id, SObject>();
    }
    Result result = seeded(loadedRecords.keySet());
    if (loadedRecords.isEmpty()) {
      result.strategy = classify(soqlTemplate);
      return result;
    }

    if (String.isBlank(soqlTemplate)) {
      throw unsupportedShape('A scope-wide SOQL template must not be blank.');
    }

    Correlation correlation = findCorrelation(soqlTemplate);
    result.strategy = classify(soqlTemplate);
    Boolean limitsEachRecord = hasLimitOne(soqlTemplate);
    if (result.strategy == UNCLASSIFIED) {
      throw new RecordHealthCheckEvaluatorException(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        'The SOQL template cannot be evaluated once for a record scope.'
      );
    }
    if (countTokens(soqlTemplate) > 1) {
      throw unsupportedShape(
        'A scope-wide SOQL template may contain only one record token.'
      );
    }

    Integer rowBudget = maxRows == null ||
      maxRows <= 0
      ? RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS
      : maxRows;
    Map<String, Object> binds = new Map<String, Object>();
    Map<String, List<Id>> recordIdsByToken = new Map<String, List<Id>>();
    String scopeSoql = soqlTemplate;

    if (result.strategy != SCOPE_INVARIANT) {
      Set<Id> scopeValues = new Set<Id>();
      if (result.strategy == INDIRECT_REFERENCE) {
        for (Id recordId : loadedRecords.keySet()) {
          Object tokenValue = readPath(
            loadedRecords.get(recordId),
            correlation.tokenPath
          );
          if (tokenValue == null) {
            continue;
          }
          if (!(tokenValue instanceof Id)) {
            throw unsupportedShape(
              'Indirect scope correlation currently requires an Id-valued record token.'
            );
          }
          Id tokenId = (Id) tokenValue;
          scopeValues.add(tokenId);
          String key = String.valueOf(tokenId);
          if (!recordIdsByToken.containsKey(key)) {
            recordIdsByToken.put(key, new List<Id>());
          }
          recordIdsByToken.get(key).add(recordId);
        }
      } else {
        scopeValues.addAll(loadedRecords.keySet());
      }
      if (scopeValues.isEmpty()) {
        return result;
      }
      binds.put('rhcScopeValues', scopeValues);
      scopeSoql = replaceSpan(
        scopeSoql,
        correlation.startIndex,
        correlation.endIndex,
        correlation.fieldPath + ' IN :rhcScopeValues'
      );
      if (limitsEachRecord && result.strategy != ORDERED_PICK_AGGREGATE) {
        scopeSoql = removeLimitOne(scopeSoql);
      }

      if (result.strategy == ORDERED_PICK_AGGREGATE) {
        scopeSoql = RecordHealthCheckBulkQueryRewriter.rewriteOrderedPickAggregate(
          scopeSoql,
          correlation.fieldPath
        );
      } else {
        scopeSoql = RecordHealthCheckBulkQueryRewriter.injectSelectField(
          scopeSoql,
          correlation.fieldPath
        );
        if (RecordHealthCheckSoqlTemplate.isAggregateQuery(scopeSoql)) {
          String countField = correlation.fieldPath.equalsIgnoreCase('Id')
            ? 'CreatedDate'
            : 'Id';
          scopeSoql = scopeSoql.replaceFirst(
            '(?i)\\bCOUNT\\s*\\(\\s*\\)',
            'COUNT(' + countField + ')'
          );
          scopeSoql = RecordHealthCheckBulkQueryRewriter.aliasCorrelation(
            scopeSoql,
            correlation.fieldPath
          );
          scopeSoql = RecordHealthCheckBulkQueryRewriter.appendGroupBy(
            scopeSoql,
            correlation.fieldPath
          );
        } else if (result.strategy == ORDERED_PICK_IN_MEMORY) {
          String orderedField = firstGroup(scopeSoql, ORDER_BY, 1);
          if (String.isNotBlank(orderedField)) {
            scopeSoql = RecordHealthCheckBulkQueryRewriter.injectSelectField(
              scopeSoql,
              orderedField
            );
          }
          scopeSoql = removeLimitOne(scopeSoql);
        } else if (result.strategy == SELF) {
          scopeSoql = removeLimitOne(scopeSoql);
        }
      }
    }

    if (TOKEN.matcher(scopeSoql).find()) {
      throw unsupportedShape(
        'The scope-wide rewrite left an unresolved record token.'
      );
    }

    String prepared;
    try {
      prepared = RecordHealthCheckSoqlTemplate.prepareForExecution(
        scopeSoql,
        rowBudget + 1
      );
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
    // queryWithBinds carries the user-mode access level itself. Salesforce
    // rejects a dynamic query that also contains a WITH USER_MODE clause.
    prepared = RecordHealthCheckSoqlTemplate.removeOuterUserMode(prepared);
    result.executedSoql = prepared;

    List<SObject> rows;
    try {
      rows = Database.queryWithBinds(prepared, binds, AccessLevel.USER_MODE);
    } catch (System.QueryException ex) {
      throw new RecordHealthCheckEvaluatorException(
        RecordHealthCheckValueResolver.classifyQueryException(ex),
        ex.getMessage()
      );
    }
    if (rows.size() > rowBudget) {
      throw new RecordHealthCheckEvaluatorException(
        'SCOPE_ROW_CAP_EXCEEDED',
        'The scope-wide query returned more than ' + rowBudget + ' rows.'
      );
    }

    if (result.strategy == SCOPE_INVARIANT) {
      for (Id recordId : result.rowsByRecordId.keySet()) {
        result.rowsByRecordId.put(recordId, rows);
      }
      return result;
    }
    for (SObject row : rows) {
      Object correlationValue = row instanceof AggregateResult
        ? ((AggregateResult) row).get(CORRELATION_ALIAS)
        : readPath(row, correlation.fieldPath);
      if (correlationValue == null) {
        continue;
      }
      if (result.strategy == INDIRECT_REFERENCE) {
        List<Id> matching = recordIdsByToken.get(
          String.valueOf(correlationValue)
        );
        if (matching != null) {
          for (Id recordId : matching) {
            List<SObject> perRecord = result.rowsByRecordId.get(recordId);
            if (!limitsEachRecord || perRecord.isEmpty()) {
              perRecord.add(row);
            }
          }
        }
      } else {
        Id recordId = (Id) correlationValue;
        if (result.rowsByRecordId.containsKey(recordId)) {
          List<SObject> perRecord = result.rowsByRecordId.get(recordId);
          if (
            (result.strategy != ORDERED_PICK_IN_MEMORY && !limitsEachRecord) ||
            perRecord.isEmpty()
          ) {
            perRecord.add(row);
          }
        }
      }
    }
    return result;
  }

  /** Classifies a template using the same ordering as the repository inventory. */
  public static String classify(String soql) {
    Correlation negated = matchCorrelation(soql, NEGATION);
    if (negated != null) {
      return UNCLASSIFIED;
    }
    if (!TOKEN.matcher(soql).find()) {
      return SCOPE_INVARIANT;
    }
    Correlation correlation = matchCorrelation(soql, EQUALITY);
    if (correlation == null) {
      return UNCLASSIFIED;
    }
    Matcher limitMatcher = LIMIT_PATTERN.matcher(soql);
    Matcher order = ORDER_BY.matcher(soql);
    Boolean hasLimit = limitMatcher.find();
    Boolean hasOrder = order.find();
    if (hasLimit && hasOrder) {
      if (MULTI_FIELD_ORDER_BY.matcher(soql).find()) {
        return UNCLASSIFIED;
      }
      if (Integer.valueOf(limitMatcher.group(1)) != 1) {
        return UNCLASSIFIED;
      }
      List<String> selected = RecordHealthCheckBulkQueryRewriter.selectedFields(
        soql
      );
      return selected.size() == 1 &&
        selected[0].equalsIgnoreCase(order.group(1))
        ? ORDERED_PICK_AGGREGATE
        : ORDERED_PICK_IN_MEMORY;
    }
    if (
      correlation.tokenPath == 'Id' &&
      correlation.fieldPath.equalsIgnoreCase('Id')
    ) {
      return !hasLimit || Integer.valueOf(limitMatcher.group(1)) == 1
        ? SELF
        : UNCLASSIFIED;
    }
    // LIMIT 1 is removed from the rewritten scope query and applied while rows
    // are attributed to each record. Larger bare limits have no supported
    // per-record reduction contract and must remain rejected.
    if (hasLimit && Integer.valueOf(limitMatcher.group(1)) != 1) {
      return UNCLASSIFIED;
    }
    if (correlation.tokenPath != 'Id') {
      return INDIRECT_REFERENCE;
    }
    return correlation.fieldPath.contains('.') ? CHILD_PATH : CHILD_DIRECT;
  }

  private static Integer countTokens(String soql) {
    Integer count = 0;
    Matcher matcher = TOKEN.matcher(soql);
    while (matcher.find()) {
      count++;
    }
    return count;
  }

  private static RecordHealthCheckEvaluatorException unsupportedShape(
    String message
  ) {
    return new RecordHealthCheckEvaluatorException(
      'UNSUPPORTED_BULK_QUERY_SHAPE',
      message
    );
  }

  private static Result seeded(Set<Id> recordIds) {
    Result result = new Result();
    for (Id recordId : recordIds) {
      result.rowsByRecordId.put(recordId, new List<SObject>());
    }
    return result;
  }

  private static Correlation findCorrelation(String soql) {
    return matchCorrelation(soql, EQUALITY);
  }

  private static Correlation matchCorrelation(String soql, Pattern pattern) {
    Matcher matcher = pattern.matcher(soql);
    Correlation firstMatch;
    while (matcher.find()) {
      Correlation current = new Correlation();
      current.fieldPath = matcher.group(1);
      current.tokenPath = matcher.group(2);
      current.startIndex = matcher.start();
      current.endIndex = matcher.end();
      if (firstMatch == null) {
        firstMatch = current;
      }
      if (current.tokenPath == 'Id') {
        return current;
      }
    }
    return firstMatch;
  }

  private static String replaceSpan(
    String value,
    Integer startIndex,
    Integer endIndex,
    String replacement
  ) {
    return value.substring(0, startIndex) +
      replacement +
      value.substring(endIndex);
  }

  private static String removeLimitOne(String soql) {
    return soql.replaceFirst('(?i)\\s+LIMIT\\s+1\\b', '');
  }

  private static Boolean hasLimitOne(String soql) {
    Matcher matcher = LIMIT_PATTERN.matcher(soql);
    return matcher.find() && Integer.valueOf(matcher.group(1)) == 1;
  }

  private static String firstGroup(
    String value,
    Pattern pattern,
    Integer groupNumber
  ) {
    Matcher matcher = pattern.matcher(value);
    return matcher.find() ? matcher.group(groupNumber) : null;
  }

  private static Object readPath(SObject row, String fieldPath) {
    List<String> parts = fieldPath.split('\\.');
    SObject current = row;
    for (Integer index = 0; index < parts.size() - 1; index++) {
      current = current == null ? null : current.getSObject(parts[index]);
    }
    return current == null ? null : current.get(parts[parts.size() - 1]);
  }
}
