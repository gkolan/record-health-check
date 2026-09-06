/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * What one merge token turned out to be, resolved once.
 *
 * The registry used to answer a yes-or-no question about a namespace and a
 * property name, which was enough while every property was a flat word. A query
 * row token carries a collection, a position, and a field path, and four
 * different consumers need those three parts. Parsing the property string again
 * in each of them is how they drift, so the parse happens here and everyone
 * downstream reads typed fields.
 *
 * An unusable token is described rather than thrown: the caller decides whether
 * a bad token is an authoring finding or a runtime configuration error.
 */
public class RecordHealthCheckTokenShape {
  /**
   * A named value read straight off the record, the Check, the Set, the result,
   * or the run. These behave alike once resolved — `fieldPath` and
   * `isTypedField` carry the differences that matter — so they share one kind
   * rather than splitting into one constant per namespace that nothing reads.
   */
  public static final String KIND_PROPERTY = 'PROPERTY';
  public static final String KIND_QUERY_ROW_FIELD = 'QUERY_ROW_FIELD';
  public static final String KIND_QUERY_ROW_COUNT = 'QUERY_ROW_COUNT';

  public static final String COLLECTION_SOURCE = 'sourceRows';
  public static final String COLLECTION_COMPARISON = 'comparisonRows';

  /** One of the KIND_ constants, or null when the token is unusable. */
  public String kind;

  /** `sourceRows` or `comparisonRows` for query tokens; otherwise null. */
  public String collection;

  /** One-based row position for a query row token; otherwise null. */
  public Integer rowIndex;

  /**
   * The terminal field or relationship path a query row token reads, or the
   * record field path for a record token. Null for fixed metadata properties.
   */
  public String fieldPath;

  /**
   * True when the token names a Salesforce field whose definition the framework
   * can look up, which is what `format` needs in order to mean anything: record
   * fields and query row fields.
   *
   * It is false everywhere else as a deliberate policy, not because no type
   * survives. Most metadata, result, and run properties are finished display
   * text by the time a template reads them, but a few — `evaluationOrder`,
   * `failedRecordCount`, `startedAt`, `durationMs` — are still typed scalars.
   * The framework renders those itself and does not offer `format` on them,
   * because there is no field definition behind them to format against.
   */
  public Boolean isTypedField = false;

  /** Stable code describing why the token is unusable, or null. */
  public String reasonCode;

  /** Author-facing explanation naming the change to make, or null. */
  public String message;

  /** True when the token resolved into something a consumer can read. */
  public Boolean isUsable() {
    return reasonCode == null && kind != null;
  }

  /** True when this token reads a row of the Check's comparison query. */
  public Boolean readsComparisonQuery() {
    return COLLECTION_COMPARISON.equals(collection);
  }

  /** Builds an unusable shape carrying the reason and the fix. */
  public static RecordHealthCheckTokenShape rejected(
    String reasonCode,
    String message
  ) {
    RecordHealthCheckTokenShape shape = new RecordHealthCheckTokenShape();
    shape.reasonCode = reasonCode;
    shape.message = message;
    return shape;
  }

  /** Builds a shape for a namespace whose properties are a fixed list. */
  public static RecordHealthCheckTokenShape property(
    String kind,
    Boolean isTypedField,
    String fieldPath
  ) {
    RecordHealthCheckTokenShape shape = new RecordHealthCheckTokenShape();
    shape.kind = kind;
    shape.isTypedField = isTypedField;
    shape.fieldPath = fieldPath;
    return shape;
  }

  /** Builds a shape for one addressed row of one of the Check's queries. */
  public static RecordHealthCheckTokenShape queryRow(
    String collection,
    Integer rowIndex,
    String fieldPath
  ) {
    RecordHealthCheckTokenShape shape = new RecordHealthCheckTokenShape();
    shape.kind = KIND_QUERY_ROW_FIELD;
    shape.collection = collection;
    shape.rowIndex = rowIndex;
    shape.fieldPath = fieldPath;
    shape.isTypedField = true;
    return shape;
  }

  /** Builds a shape for the returned-row count of one of the Check's queries. */
  public static RecordHealthCheckTokenShape queryCount(String collection) {
    RecordHealthCheckTokenShape shape = new RecordHealthCheckTokenShape();
    shape.kind = KIND_QUERY_ROW_COUNT;
    shape.collection = collection;
    return shape;
  }
}
