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
  private static Map<String, Schema.SObjectField> nameEntityFields;

  /**
   * Returns unique record field references needed by the formula.
   * @param formula Formula expression to scan.
   * @param resolveType SObject type against which relationship paths resolve.
   * @return Selectable paths and any explicit relationship types.
   */
  public static List<FieldReference> scan(
    String formula,
    Schema.SObjectType resolveType
  ) {
    List<FieldReference> tokens = new List<FieldReference>();
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
      FieldReference normalizedPath = resolveColonReference(
        resolveType,
        colonMatcher.group(1),
        colonMatcher.group(2),
        colonMatcher.group(3)
      );
      if (normalizedPath != null && seen.add(normalizedPath.path)) {
        tokens.add(normalizedPath);
      }
    }
    maskedParts.add(scannable.substring(lastEnd));
    scannable = String.join(maskedParts, '');

    Matcher dotMatcher = PATTERN_DOT_PATH.matcher(scannable);
    while (dotMatcher.find()) {
      if (seen.add(dotMatcher.group(1))) {
        tokens.add(new FieldReference(dotMatcher.group(1), null, null));
      }
    }
    Matcher wordMatcher = PATTERN_WORD.matcher(scannable);
    while (wordMatcher.find()) {
      String word = wordMatcher.group(0);
      if (
        !RecordHealthCheckFormulaSyntax.isSyntaxWord(word) && seen.add(word)
      ) {
        tokens.add(new FieldReference(word, null, null));
      }
    }
    return tokens;
  }

  private static FieldReference resolveColonReference(
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
    List<Schema.SObjectType> candidates = RecordHealthCheckDescribeCache.describeField(
        relationshipField
      )
      .getReferenceTo();
    for (Schema.SObjectType candidate : candidates) {
      if (String.valueOf(candidate).equalsIgnoreCase(typeSegment)) {
        String childPath = fieldPathSegment.substring(1);
        if (candidates.size() > 1 && !isNameEntityPath(childPath)) {
          return null;
        }
        return new FieldReference(
          relationshipSegment + fieldPathSegment,
          relationshipSegment,
          candidate
        );
      }
    }
    return null;
  }

  /**
   * Reports whether a flat child path is selectable from Salesforce's Name entity.
   * @param childPath Path below a polymorphic relationship.
   * @return True when the first segment is a field or relationship exposed by Name.
   */
  public static Boolean isNameEntityPath(String childPath) {
    if (nameEntityFields == null) {
      nameEntityFields = RecordHealthCheckDescribeCache.fieldMap(
        Schema.getGlobalDescribe().get('Name')
      );
    }
    String firstPathPart = childPath.substringBefore('.');
    return nameEntityFields.get(firstPathPart) != null ||
      findRelationshipField(nameEntityFields, firstPathPart) != null;
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

  /** A selectable path plus an explicit type supplied by colon syntax. */
  public class FieldReference {
    public String path { get; private set; }
    public String typedRelationship { get; private set; }
    public Schema.SObjectType relationshipType { get; private set; }

    private FieldReference(
      String path,
      String typedRelationship,
      Schema.SObjectType relationshipType
    ) {
      this.path = path;
      this.typedRelationship = typedRelationship;
      this.relationshipType = relationshipType;
    }
  }
}
