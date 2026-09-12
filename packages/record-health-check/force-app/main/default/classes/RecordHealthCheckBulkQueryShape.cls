/** Parses the correlation clause of a scope-safe record-token SOQL template. */
public abstract with sharing class RecordHealthCheckBulkQueryShape {
  private static final Pattern OUTER_CLAUSE = Pattern.compile(
    '(?i)\\bWHERE\\b|\\b(?:GROUP\\s+BY|ORDER\\s+BY|HAVING|LIMIT|OFFSET|WITH|FOR)\\b'
  );
  private static final Pattern DIRECT_EQUALITY = Pattern.compile(
    '(?is)^([A-Za-z_][A-Za-z0-9_.]*)\\s*=\\s*\\{!record\\.([A-Za-z0-9_.]+)(?:\\s+[^{}]*?)?\\}$'
  );

  /** Correlation field, token, fallback, and source replacement span. */
  public class Correlation {
    public String fieldPath;
    public String tokenPath;
    public String fallbackValue;
    public Integer startIndex;
    public Integer endIndex;
  }

  private class Segment {
    private String value;
    private Integer startIndex;
  }

  /** Returns the number of parsed record tokens, including literal token text. */
  public static Integer countTokens(String soql) {
    Integer count = 0;
    for (RecordHealthCheckToken token : recordTokens(soql)) {
      if (token.namespaceName == 'record') {
        count++;
      }
    }
    return count;
  }

  /** Returns the number of record tokens outside quoted string literals. */
  public static Integer countExecutableTokens(String soql) {
    if (String.isBlank(soql)) {
      return 0;
    }
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(soql);
    Integer count = 0;
    for (RecordHealthCheckToken token : recordTokens(soql)) {
      if (
        token.namespaceName == 'record' &&
        token.startIndex < masked.length() &&
        masked.substring(token.startIndex, token.startIndex + 1) == '{'
      ) {
        count++;
      }
    }
    return count;
  }

  /** Finds the sole equality correlation when it is an outer direct conjunct. */
  public static Correlation directCorrelation(String soql) {
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(soql);
    Segment whereExpression = outerWhereExpression(masked);
    if (whereExpression == null) {
      return null;
    }
    Segment unwrapped = stripWrappingParentheses(whereExpression);
    for (Segment conjunct : splitTopLevelAnd(unwrapped)) {
      Segment candidate = stripWrappingParentheses(conjunct);
      Matcher equality = DIRECT_EQUALITY.matcher(candidate.value);
      if (!equality.matches()) {
        continue;
      }
      Integer tokenStart = candidate.startIndex + equality.start(2) - 9;
      for (RecordHealthCheckToken token : recordTokens(soql)) {
        if (token.namespaceName == 'record' && token.startIndex == tokenStart) {
          Correlation correlation = new Correlation();
          correlation.fieldPath = equality.group(1);
          correlation.tokenPath = token.propertyPath;
          correlation.fallbackValue = token.fallbackValue;
          correlation.startIndex = candidate.startIndex + equality.start(1);
          correlation.endIndex = token.endIndex;
          return correlation;
        }
      }
    }
    return null;
  }

  private static Segment outerWhereExpression(String masked) {
    Matcher clauses = OUTER_CLAUSE.matcher(masked);
    Integer startIndex;
    while (clauses.find()) {
      if (RecordHealthCheckSoqlTemplate.depthAt(masked, clauses.start()) != 0) {
        continue;
      }
      if (startIndex == null && clauses.group().equalsIgnoreCase('WHERE')) {
        startIndex = clauses.end();
      } else if (startIndex != null) {
        return segment(masked, startIndex, clauses.start());
      }
    }
    return startIndex == null
      ? null
      : segment(masked, startIndex, masked.length());
  }

  private static List<Segment> splitTopLevelAnd(Segment source) {
    List<Segment> parts = new List<Segment>();
    Matcher conjunctions = Pattern.compile('(?i)\\bAND\\b')
      .matcher(source.value);
    Integer partStart = 0;
    while (conjunctions.find()) {
      if (
        RecordHealthCheckSoqlTemplate.depthAt(
          source.value,
          conjunctions.start()
        ) == 0
      ) {
        parts.add(
          segment(
            source.value,
            partStart,
            conjunctions.start(),
            source.startIndex
          )
        );
        partStart = conjunctions.end();
      }
    }
    parts.add(
      segment(source.value, partStart, source.value.length(), source.startIndex)
    );
    return parts;
  }

  private static Segment stripWrappingParentheses(Segment source) {
    Segment current = trimSegment(source);
    while (
      current.value.startsWith('(') &&
      current.value.endsWith(')') &&
      wrappingPairCoversAll(current.value)
    ) {
      current = trimSegment(
        segment(
          current.value,
          1,
          current.value.length() - 1,
          current.startIndex
        )
      );
    }
    return current;
  }

  private static Boolean wrappingPairCoversAll(String value) {
    Integer depth = 0;
    for (Integer index = 0; index < value.length(); index++) {
      String character = value.substring(index, index + 1);
      if (character == '(') {
        depth++;
      } else if (character == ')') {
        depth--;
        if (depth == 0 && index != value.length() - 1) {
          return false;
        }
      }
      if (depth < 0) {
        return false;
      }
    }
    return depth == 0;
  }

  private static Segment trimSegment(Segment source) {
    Integer start = 0;
    Integer endIndex = source.value.length();
    while (
      start < endIndex &&
      String.isBlank(source.value.substring(start, start + 1))
    ) {
      start++;
    }
    while (
      endIndex > start &&
      String.isBlank(source.value.substring(endIndex - 1, endIndex))
    ) {
      endIndex--;
    }
    return segment(source.value, start, endIndex, source.startIndex);
  }

  private static Segment segment(
    String value,
    Integer start,
    Integer endIndex
  ) {
    return segment(value, start, endIndex, 0);
  }

  private static Segment segment(
    String value,
    Integer start,
    Integer endIndex,
    Integer baseOffset
  ) {
    Segment result = new Segment();
    result.value = value.substring(start, endIndex);
    result.startIndex = baseOffset + start;
    return result;
  }

  private static List<RecordHealthCheckToken> recordTokens(String soql) {
    return String.isBlank(soql)
      ? new List<RecordHealthCheckToken>()
      : RecordHealthCheckTemplateService.parse(soql);
  }
}
