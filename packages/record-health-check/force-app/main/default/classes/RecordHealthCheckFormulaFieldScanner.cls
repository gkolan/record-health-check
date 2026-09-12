/**
 * Extracts selectable record-field paths from Salesforce formula expressions.
 * Keeps formula lexical concerns separate from record-query planning.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckFormulaFieldScanner {
  private static final Pattern PATTERN_COLON_PATH = Pattern.compile(
    '\\b([A-Za-z_][A-Za-z0-9_]*):([A-Za-z_][A-Za-z0-9_]*)((?:\\.[A-Za-z_][A-Za-z0-9_]*)+)\\b'
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
    for (
      RecordHealthCheckFormulaTokenizer.Token token : RecordHealthCheckFormulaTokenizer.tokenize(
          formula
        )
        .tokens
    ) {
      if (token.kind != 'FIELD_PATH' || token.text.startsWith('$')) {
        continue;
      }
      FieldReference reference;
      Matcher colonMatcher = PATTERN_COLON_PATH.matcher(token.text);
      if (colonMatcher.matches()) {
        reference = resolveColonReference(
          resolveType,
          colonMatcher.group(1),
          colonMatcher.group(2),
          colonMatcher.group(3)
        );
      } else {
        reference = new FieldReference(token.text, null, null);
      }
      if (reference != null && seen.add(reference.path)) {
        tokens.add(reference);
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
    if (relationshipField == null) {
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
