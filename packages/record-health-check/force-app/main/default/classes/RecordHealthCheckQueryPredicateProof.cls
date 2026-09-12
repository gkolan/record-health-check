/** Proves a singleton literal constraint from an outer SOQL WHERE expression. */
public with sharing class RecordHealthCheckQueryPredicateProof {
  private static final Pattern FIELD_PATH = Pattern.compile(
    '^[A-Za-z_][A-Za-z0-9_.]*$'
  );
  private static final Pattern CLAUSE = Pattern.compile(
    '(?i)\\b(?:WHERE|GROUP\\s+BY|ORDER\\s+BY|HAVING|LIMIT|OFFSET|WITH|FOR)\\b'
  );

  private RecordHealthCheckQueryPredicateProof() {
    throw new IllegalArgumentException('Static utility class.');
  }

  public static String requiredLiteral(String soql, String fieldPath) {
    if (
      String.isBlank(soql) ||
      String.isBlank(fieldPath) ||
      !FIELD_PATH.matcher(fieldPath.trim()).matches()
    ) {
      return null;
    }
    String predicate = outerWhere(soql);
    if (predicate == null) {
      return null;
    }
    Set<String> required = requiredValues(predicate, fieldPath.trim());
    return required.size() == 1 ? new List<String>(required)[0] : null;
  }

  private static String outerWhere(String soql) {
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(soql);
    Matcher clauses = CLAUSE.matcher(masked);
    Integer start;
    while (clauses.find()) {
      if (RecordHealthCheckSoqlTemplate.depthAt(masked, clauses.start()) != 0) {
        continue;
      }
      if (start == null && clauses.group().equalsIgnoreCase('WHERE')) {
        start = clauses.end();
      } else if (start != null) {
        return soql.substring(start, clauses.start());
      }
    }
    return start == null ? null : soql.substring(start);
  }

  private static Set<String> requiredValues(
    String expression,
    String fieldPath
  ) {
    expression = stripWrappingParentheses(expression.trim());
    List<String> alternatives = splitAtDepthZero(expression, 'OR');
    if (alternatives.size() > 1) {
      Set<String> common;
      for (String alternative : alternatives) {
        Set<String> values = requiredValues(alternative, fieldPath);
        if (common == null) {
          common = values;
        } else {
          Set<String> intersection = new Set<String>();
          for (String value : common) {
            if (values.contains(value)) {
              intersection.add(value);
            }
          }
          common = intersection;
        }
      }
      return common;
    }
    List<String> conjuncts = splitAtDepthZero(expression, 'AND');
    if (conjuncts.size() > 1) {
      Set<String> required = new Set<String>();
      for (String conjunct : conjuncts) {
        required.addAll(requiredValues(conjunct, fieldPath));
        if (required.size() > 1) {
          return new Set<String>();
        }
      }
      return required;
    }
    if (Pattern.compile('(?i)^NOT\\b').matcher(expression).find()) {
      return new Set<String>();
    }
    Matcher equality = Pattern.compile(
        '(?i)^' + fieldPath.replace('.', '\\.') + '\\s*=\\s*\'([A-Z]{3})\'$'
      )
      .matcher(expression.trim());
    return equality.matches()
      ? new Set<String>{ equality.group(1).toUpperCase() }
      : new Set<String>();
  }

  private static List<String> splitAtDepthZero(
    String expression,
    String operatorName
  ) {
    List<String> parts = new List<String>();
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(
      expression
    );
    Matcher operators = Pattern.compile('(?i)\\b' + operatorName + '\\b')
      .matcher(masked);
    Integer start = 0;
    while (operators.find()) {
      if (
        RecordHealthCheckSoqlTemplate.depthAt(masked, operators.start()) == 0
      ) {
        parts.add(expression.substring(start, operators.start()).trim());
        start = operators.end();
      }
    }
    parts.add(expression.substring(start).trim());
    return parts;
  }

  private static String stripWrappingParentheses(String expression) {
    while (expression.startsWith('(') && expression.endsWith(')')) {
      Integer depth = 0;
      Boolean coversAll = true;
      String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(
        expression
      );
      for (Integer index = 0; index < masked.length(); index++) {
        String character = masked.substring(index, index + 1);
        if (character == '(') {
          depth++;
        } else if (character == ')') {
          depth--;
          if (depth == 0 && index < masked.length() - 1) {
            coversAll = false;
            break;
          }
        }
      }
      if (!coversAll || depth != 0) {
        break;
      }
      expression = expression.substring(1, expression.length() - 1).trim();
    }
    return expression;
  }
}
