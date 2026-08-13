/**
 * Extracts selectable record-field paths from Salesforce formula expressions.
 * Keeps formula lexical concerns separate from record-query planning.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckFormulaFieldScanner {
  private static final Pattern PATTERN_DOT_PATH = Pattern.compile(
    '\\b([A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]+)+)\\b'
  );
  private static final Pattern PATTERN_WORD = Pattern.compile(
    '\\b[A-Za-z_][A-Za-z0-9_]*\\b'
  );
  private static final Pattern PATTERN_COLON_PATH = Pattern.compile(
    '\\b([A-Za-z_][A-Za-z0-9_]*):([A-Za-z_][A-Za-z0-9_]*)((?:\\.[A-Za-z_][A-Za-z0-9_]*)+)\\b'
  );
  private static final Pattern PATTERN_DOLLAR_GLOBAL = Pattern.compile(
    '\\$[A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]*)*'
  );

  /**
   * Returns record field paths in document order with duplicates removed.
   * @param formula Formula expression to scan.
   * @param resolveType SObject type against which relationship paths resolve.
   * @return Selectable dot-separated record paths.
   */
  public static List<String> scan(
    String formula,
    Schema.SObjectType resolveType
  ) {
    List<String> tokens = new List<String>();
    Set<String> seen = new Set<String>();
    String scannable = maskFormulaStringLiterals(formula);
    scannable = PATTERN_DOLLAR_GLOBAL.matcher(scannable).replaceAll(' ');

    Matcher colonMatcher = PATTERN_COLON_PATH.matcher(scannable);
    List<String> maskedParts = new List<String>();
    Integer lastEnd = 0;
    while (colonMatcher.find()) {
      maskedParts.add(scannable.substring(lastEnd, colonMatcher.start()));
      maskedParts.add(
        ''.rightPad(colonMatcher.end() - colonMatcher.start(), ' ')
      );
      lastEnd = colonMatcher.end();
      String normalizedPath = resolveColonReference(
        resolveType,
        colonMatcher.group(1),
        colonMatcher.group(2),
        colonMatcher.group(3)
      );
      if (normalizedPath != null && seen.add(normalizedPath)) {
        tokens.add(normalizedPath);
      }
    }
    maskedParts.add(scannable.substring(lastEnd));
    scannable = String.join(maskedParts, '');

    Matcher dotMatcher = PATTERN_DOT_PATH.matcher(scannable);
    while (dotMatcher.find()) {
      if (seen.add(dotMatcher.group(1))) {
        tokens.add(dotMatcher.group(1));
      }
    }
    Matcher wordMatcher = PATTERN_WORD.matcher(scannable);
    while (wordMatcher.find()) {
      String word = wordMatcher.group(0);
      if (
        !RecordHealthCheckFormulaSyntax.isSyntaxWord(word) && seen.add(word)
      ) {
        tokens.add(word);
      }
    }
    return tokens;
  }

  private static String resolveColonReference(
    Schema.SObjectType resolveType,
    String relationshipSegment,
    String typeSegment,
    String fieldPathSegment
  ) {
    Schema.SObjectField relationshipField = findRelationshipField(
      RecordHealthCheckDescribeCache.fieldMap(resolveType),
      relationshipSegment
    );
    if (
      relationshipField == null ||
      !RecordHealthCheckDescribeCache.describeField(relationshipField)
        .isAccessible()
    ) {
      return null;
    }
    for (
      Schema.SObjectType candidate : RecordHealthCheckDescribeCache.describeField(
          relationshipField
        )
        .getReferenceTo()
    ) {
      if (String.valueOf(candidate).equalsIgnoreCase(typeSegment)) {
        return relationshipSegment + fieldPathSegment;
      }
    }
    return null;
  }

  private static String maskFormulaStringLiterals(String formula) {
    List<String> masked = new List<String>();
    Boolean inQuote = false;
    for (Integer i = 0; i < formula.length(); i++) {
      String character = formula.substring(i, i + 1);
      if (character == '"' && (i == 0 || formula.substring(i - 1, i) != '\\')) {
        inQuote = !inQuote;
        masked.add('"');
      } else {
        masked.add(inQuote ? ' ' : character);
      }
    }
    return String.join(masked, '');
  }

  private static Schema.SObjectField findRelationshipField(
    Map<String, Schema.SObjectField> fieldMap,
    String relationshipName
  ) {
    for (Schema.SObjectField candidate : fieldMap.values()) {
      String candidateName = RecordHealthCheckDescribeCache.describeField(
          candidate
        )
        .getRelationshipName();
      if (
        candidateName != null &&
        candidateName.equalsIgnoreCase(relationshipName)
      ) {
        return candidate;
      }
    }
    return null;
  }
}
