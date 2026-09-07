/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** The complete allowed list for product-qualified Framework tokens. */
public class RecordHealthCheckTokenRegistry {
  public static final Set<String> NAMESPACES = new Set<String>{
    'record',
    'rhcCheck',
    'rhcSet',
    'rhcResult',
    'rhcRun',
    'rhcQuery'
  };
  public static final Set<String> CHECK_PROPERTIES = new Set<String>{
    'developerName',
    'masterLabel',
    'checkTitle',
    'checkDescription',
    'category',
    'evaluationType',
    'failureSeverity',
    'evaluationOrder'
  };
  public static final Set<String> SET_PROPERTIES = new Set<String>{
    'developerName',
    'masterLabel',
    'cardTitle',
    'cardSubtitle',
    'objectApiName'
  };
  public static final Set<String> RESULT_PROPERTIES = new Set<String>{
    'status',
    'foundValue',
    'foundValuePluralSuffix',
    'expectedValue',
    'failedRecordCount',
    'totalRecordCount',
    'reasonCode'
  };
  public static final Set<String> RUN_PROPERTIES = new Set<String>{
    'runId',
    'source',
    'startedAt',
    'completedAt',
    'durationMs'
  };

  /** The row collections a Query Check exposes, and their count properties. */
  public static final Map<String, String> QUERY_COUNT_PROPERTIES = new Map<String, String>{
    'sourceRowCount' => RecordHealthCheckTokenShape.COLLECTION_SOURCE,
    'comparisonRowCount' => RecordHealthCheckTokenShape.COLLECTION_COMPARISON
  };

  /** Highest zero-based index when the Framework returns its maximum 2,000 rows. */
  private static final Integer MAX_ROW_INDEX = 1999;

  private static final Pattern ROW_REFERENCE = Pattern.compile(
    '^(sourceRows|comparisonRows)\\[([^\\]]*)\\]\\.(.+)$'
  );
  private static final Pattern ROW_INDEX = Pattern.compile(
    '^(?:0|[1-9][0-9]*)$'
  );
  /** The resolver follows five relationships, so a path has at most six parts. */
  public static final Integer MAX_RELATIONSHIP_PARTS = 6;

  private static final Pattern FIELD_PATH = Pattern.compile(
    '^[A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]*)*$'
  );

  public static Boolean contains(String namespaceName, String property) {
    return resolve(namespaceName, property).isUsable();
  }

  /**
   * Resolves a namespace and property into what the token actually addresses.
   *
   * @param namespaceName The token's namespace, already split from the property.
   * @param property Everything after the first period in the token reference.
   * @return The resolved shape. Ask `isUsable()` before reading its parts.
   */
  public static RecordHealthCheckTokenShape resolve(
    String namespaceName,
    String property
  ) {
    if (String.isBlank(property)) {
      return RecordHealthCheckTokenShape.rejected(
        'UNKNOWN_TOKEN_PROPERTY',
        'A merge token needs a property after its namespace.'
      );
    }
    if (namespaceName == 'record') {
      return resolveRecordField(property);
    }
    if (namespaceName == 'rhcQuery') {
      return resolveQuery(property);
    }
    Boolean known =
      (namespaceName == 'rhcCheck' && CHECK_PROPERTIES.contains(property)) ||
      (namespaceName == 'rhcSet' && SET_PROPERTIES.contains(property)) ||
      (namespaceName == 'rhcResult' && RESULT_PROPERTIES.contains(property)) ||
      (namespaceName == 'rhcRun' && RUN_PROPERTIES.contains(property));
    if (!known) {
      return unknownProperty(namespaceName, property);
    }
    // These namespaces name no Salesforce field, so there is no field
    // definition for `format` to work against. Most of their properties are
    // finished display text; a few are still typed scalars the framework
    // renders itself. Neither is offered for formatting.
    return RecordHealthCheckTokenShape.property(
      RecordHealthCheckTokenShape.KIND_PROPERTY,
      false,
      null
    );
  }

  /**
   * Checks that a record field path is shaped so it can be planned and read.
   *
   * The framework cannot know every field of every object at authoring time, so
   * it does not try. What it can check is that the path is shaped like a field
   * path at all, and that it is not deeper than the resolver will follow. A
   * well-shaped nonexistent field such as DoesNotExist__c still passes here;
   * RecordHealthCheckFieldPlanner refuses it before rendering. Both shape
   * faults used to be discovered only when the Check ran, which turned an
   * author's typo into a runtime failure on a record page.
   */
  private static RecordHealthCheckTokenShape resolveRecordField(
    String property
  ) {
    if (!FIELD_PATH.matcher(property).matches()) {
      return RecordHealthCheckTokenShape.rejected(
        'UNKNOWN_TOKEN_PROPERTY',
        'A record token must name a field or relationship path, such as ' +
          'Name or Owner.Name. Received "' +
          property +
          '".'
      );
    }
    if (property.split('\\.').size() > MAX_RELATIONSHIP_PARTS) {
      return RecordHealthCheckTokenShape.rejected(
        'UNKNOWN_TOKEN_PROPERTY',
        'A record token may cross at most ' +
          (MAX_RELATIONSHIP_PARTS - 1) +
          ' relationships. Received "' +
          property +
          '".'
      );
    }
    return RecordHealthCheckTokenShape.property(
      RecordHealthCheckTokenShape.KIND_PROPERTY,
      true,
      property
    );
  }

  private static RecordHealthCheckTokenShape resolveQuery(String property) {
    String countCollection = QUERY_COUNT_PROPERTIES.get(property);
    if (countCollection != null) {
      return RecordHealthCheckTokenShape.queryCount(countCollection);
    }
    Matcher reference = ROW_REFERENCE.matcher(property);
    if (!reference.matches()) {
      return unknownProperty('rhcQuery', property);
    }
    String collection = reference.group(1);
    String rawIndex = reference.group(2).trim();
    String fieldPath = reference.group(3).trim();
    if (!ROW_INDEX.matcher(rawIndex).matches()) {
      return RecordHealthCheckTokenShape.rejected(
        'TOKEN_ROW_INDEX_INVALID',
        'Address a row with a zero-based whole number, such as ' +
          collection +
          '[0]. Received "' +
          rawIndex +
          '".'
      );
    }
    // Too long to be a row this Check could return, and too long to convert:
    // Integer.valueOf would throw System.TypeException rather than report a
    // configuration problem. Length answers the same question the cap does, so
    // it is one rule with one message.
    Integer rowIndex = rawIndex.length() >
      String.valueOf(MAX_ROW_INDEX).length()
      ? null
      : Integer.valueOf(rawIndex);
    if (rowIndex == null || rowIndex > MAX_ROW_INDEX) {
      return RecordHealthCheckTokenShape.rejected(
        'TOKEN_ROW_INDEX_INVALID',
        'A row index may not exceed ' +
          MAX_ROW_INDEX +
          ', the most rows a Check can return.'
      );
    }
    if (!FIELD_PATH.matcher(fieldPath).matches()) {
      return RecordHealthCheckTokenShape.rejected(
        'UNKNOWN_TOKEN_PROPERTY',
        'A query row token must end in a field or relationship path, such as ' +
          collection +
          '[0].Name. Received "' +
          fieldPath +
          '".'
      );
    }
    return RecordHealthCheckTokenShape.queryRow(
      collection,
      rowIndex,
      fieldPath
    );
  }

  private static RecordHealthCheckTokenShape unknownProperty(
    String namespaceName,
    String property
  ) {
    String guidance = namespaceName == 'rhcQuery'
      ? ' Use sourceRows[0].Field, comparisonRows[0].Field, sourceRowCount, or comparisonRowCount.'
      : '';
    return RecordHealthCheckTokenShape.rejected(
      'UNKNOWN_TOKEN_PROPERTY',
      'Unknown property "' +
        property +
        '" in namespace "' +
        namespaceName +
        '".' +
        guidance
    );
  }
}
