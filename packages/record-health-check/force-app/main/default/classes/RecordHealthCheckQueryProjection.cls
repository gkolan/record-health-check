/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * The one description of what a Check's SOQL actually returns.
 *
 * RecordHealthCheckQueryTokenRules reads it to decide whether a query row
 * token addresses something the query actually returns. That consumer carries
 * a security obligation — a row addressed by position must be the row the
 * executor returns — so the SELECT list is split here, once, rather than by
 * each caller's own pattern.
 *
 * The analysis fails closed. Anything this class cannot resolve into named,
 * addressable columns leaves `isFullyAnalyzable` false, and a caller that needs
 * to prove a field was selected must refuse rather than assume.
 */
public with sharing class RecordHealthCheckQueryProjection {
  private static final Pattern SIMPLE_PATH = Pattern.compile(
    '^[A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]*)*$'
  );
  private static final Pattern ALIAS_NAME = Pattern.compile(
    '^[A-Za-z_][A-Za-z0-9_]*$'
  );
  private static final Pattern AGGREGATE_EXPRESSION = Pattern.compile(
    '(?is)^(COUNT|COUNT_DISTINCT|SUM|AVG|MIN|MAX)\\s*\\(\\s*' +
    '([A-Za-z_][A-Za-z0-9_.]*)?\\s*\\)$'
  );
  private static final Pattern LIMIT_CLAUSE = Pattern.compile(
    '(?i)\\bLIMIT\\s+([0-9]{1,9})\\b'
  );
  private static final Pattern GROUP_BY_CLAUSE = Pattern.compile(
    '(?i)\\bGROUP\\s+BY\\b'
  );
  private static final Pattern ORDER_BY_CLAUSE = Pattern.compile(
    '(?i)\\bORDER\\s+BY\\b'
  );
  private static final Pattern ORDER_BY_TERMINATOR = Pattern.compile(
    '(?i)\\b(?:LIMIT|OFFSET|FOR\\s+(?:VIEW|REFERENCE|UPDATE)|UPDATE\\s+' +
    '(?:TRACKING|VIEWSTAT))\\b'
  );
  private static final Pattern ORDER_KEY = Pattern.compile(
    '(?is)^([A-Za-z_][A-Za-z0-9_.]*)(?:\\s+(?:ASC|DESC))?' +
    '(?:\\s+NULLS\\s+(?:FIRST|LAST))?$'
  );

  /** The query's root object, or null when it could not be read. */
  public String objectApiName;

  /** Scalar paths the outer SELECT projects, in source order. */
  public List<String> selectedPaths = new List<String>();

  /** Explicit aliases the outer SELECT declares, in source order. */
  public List<String> aliases = new List<String>();

  /**
   * Depth-zero ORDER BY field paths, in source order. Direction and null
   * handling are not kept: the only question asked of an order here is whether
   * it can tie, and that depends on which fields it names, not how it sorts.
   */
  public List<String> orderPaths = new List<String>();

  /** True when the query groups or projects an aggregate function. */
  public Boolean isAggregate = false;

  /**
   * True when the outer query has a GROUP BY.
   *
   * It separates the two kinds of aggregate query, which behave very
   * differently when a row is addressed by position: an aggregate with no
   * GROUP BY returns exactly one row, while a grouped one returns a row per
   * group whose order has to be established like any other multi-row query.
   */
  public Boolean hasGroupBy = false;

  /**
   * The outer LIMIT, or null when the query has none. It is the real ceiling on
   * how many rows a token can address: a Check may allow 200 rows while its
   * query asks for 5.
   */
  public Integer outerLimit;

  /**
   * True only when every projected expression resolved into an addressable
   * name. False forbids any conclusion about what the query did not select.
   */
  public Boolean isFullyAnalyzable = true;

  /** True when an invalid outer SELECT item or ORDER BY defeated analysis. */
  public Boolean hasInvalidOuterShape = false;

  private final Set<String> selectedKeys = new Set<String>();
  private final Set<String> aliasKeys = new Set<String>();

  private static final Map<String, RecordHealthCheckQueryProjection> CACHE = new Map<String, RecordHealthCheckQueryProjection>();

  /**
   * Analyzes one administrator-authored query, once per transaction.
   *
   * The result is cached because token validation resolves field paths through
   * the describe cache, and a Check may address many tokens against the same
   * query.
   *
   * @param soql Administrator-authored SOQL, before execution rewriting.
   * @return The projection. Never null; check `isFullyAnalyzable` before
   *         concluding that an absent path was not selected.
   */
  public static RecordHealthCheckQueryProjection of(String soql) {
    String key = soql == null ? '' : soql;
    RecordHealthCheckQueryProjection cached = CACHE.get(key);
    if (cached == null) {
      cached = analyze(key);
      CACHE.put(key, cached);
    }
    return cached;
  }

  /**
   * True when the query projects an addressable column under this name, either
   * as a selected path or as an explicit alias.
   */
  public Boolean projects(String name) {
    if (String.isBlank(name)) {
      return false;
    }
    String key = name.toLowerCase();
    return selectedKeys.contains(key) || aliasKeys.contains(key);
  }

  /**
   * True when repeating the query returns rows in the same order every time.
   *
   * Salesforce does not promise an order without ORDER BY, and it does not
   * promise one between rows that tie on every named key. A row addressed by
   * position is only meaningful when neither gap exists, so this requires an
   * ORDER BY that names Id: Id is unique, so no two rows can tie once it
   * participates.
   */
  public Boolean hasStableRowOrder() {
    for (String path : orderPaths) {
      if (path.equalsIgnoreCase('Id')) {
        return true;
      }
    }
    return false;
  }

  /** True when the outer query declares an ORDER BY the analyzer can read. */
  public Boolean hasExplicitRowOrder() {
    return !orderPaths.isEmpty();
  }

  /**
   * True when an Id correlation proves the query can return at most one row
   * for the record being evaluated. Positional index zero is unambiguous for
   * this shape even when the author does not add an ORDER BY.
   */
  public Boolean returnsAtMostOneRowPerRecord(String soql) {
    RecordHealthCheckBulkQueryShape.Correlation correlation = RecordHealthCheckBulkQueryShape.directCorrelation(
      soql
    );
    return correlation != null &&
      correlation.tokenPath.equalsIgnoreCase('Id') &&
      correlation.fieldPath.equalsIgnoreCase('Id');
  }

  /** Every name a merge token may address on a row of this query. */
  public List<String> addressableNames() {
    List<String> names = new List<String>(selectedPaths);
    names.addAll(aliases);
    return names;
  }

  private static RecordHealthCheckQueryProjection analyze(String soql) {
    RecordHealthCheckQueryProjection projection = new RecordHealthCheckQueryProjection();
    if (String.isBlank(soql)) {
      projection.isFullyAnalyzable = false;
      return projection;
    }
    projection.objectApiName = RecordHealthCheckSoqlTemplate.rootObject(soql);
    projection.isAggregate = RecordHealthCheckSoqlTemplate.isAggregateQuery(
      soql
    );
    String selectList = RecordHealthCheckSoqlTemplate.outerSelectList(soql);
    if (projection.objectApiName == null || String.isBlank(selectList)) {
      projection.isFullyAnalyzable = false;
      return projection;
    }
    for (String expression : splitTopLevel(selectList)) {
      projection.absorb(expression.trim());
    }
    projection.hasGroupBy = hasDepthZeroClause(soql, GROUP_BY_CLAUSE);
    projection.outerLimit = depthZeroNumber(soql, LIMIT_CLAUSE);
    projection.readOrderPaths(soql);
    return projection;
  }

  private void absorb(String expression) {
    if (String.isBlank(expression)) {
      reject();
      return;
    }
    List<String> words = splitOnFirstGap(expression);
    String head = words[0];
    String tail = words.size() > 1 ? words[1] : null;

    // A relationship subquery is a valid but opaque outer projection. It does
    // not make independently selected scalar fields unreadable.
    if (
      expression.startsWith('(') &&
      Pattern.compile('(?is)^\\(\\s*SELECT\\b').matcher(expression).find()
    ) {
      isFullyAnalyzable = false;
      return;
    }

    Matcher aggregate = AGGREGATE_EXPRESSION.matcher(head);
    if (aggregate.matches()) {
      // An unaliased aggregate is returned as expr0, expr1, and so on. Those
      // names shift when the SELECT list changes, so the Framework never lets a
      // token address one; the author declares an alias instead.
      if (tail == null) {
        return;
      }
      addAlias(tail);
      return;
    }
    absorbScalarPath(head, tail);
  }

  private void absorbScalarPath(String head, String tail) {
    if (!SIMPLE_PATH.matcher(head).matches()) {
      reject();
      return;
    }
    if (tail == null) {
      addSelectedPath(head);
      return;
    }
    // A grouped query may alias a plain field. The alias is then the only name
    // the AggregateResult answers to, so the path itself is not addressable.
    if (isAggregate) {
      addAlias(tail);
      return;
    }
    reject();
  }

  private void addSelectedPath(String path) {
    if (selectedKeys.add(path.toLowerCase())) {
      selectedPaths.add(path);
    }
  }

  private void addAlias(String alias) {
    if (!ALIAS_NAME.matcher(alias).matches()) {
      reject();
      return;
    }
    if (aliasKeys.add(alias.toLowerCase())) {
      aliases.add(alias);
    }
  }

  /** Records that some part of the query defeated analysis. */
  private void reject() {
    isFullyAnalyzable = false;
    hasInvalidOuterShape = true;
  }

  private void readOrderPaths(String soql) {
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(soql);
    Integer start = -1;
    Matcher clause = ORDER_BY_CLAUSE.matcher(masked);
    while (clause.find()) {
      if (RecordHealthCheckSoqlTemplate.depthAt(masked, clause.start()) == 0) {
        start = clause.end();
        break;
      }
    }
    if (start < 0) {
      return;
    }
    Integer stop = masked.length();
    Matcher terminator = ORDER_BY_TERMINATOR.matcher(masked);
    while (terminator.find()) {
      if (
        terminator.start() >= start &&
        RecordHealthCheckSoqlTemplate.depthAt(masked, terminator.start()) == 0
      ) {
        stop = terminator.start();
        break;
      }
    }
    for (String part : splitTopLevel(soql.substring(start, stop))) {
      Matcher key = ORDER_KEY.matcher(part.trim());
      if (!key.matches()) {
        // An order the Framework cannot read cannot be called stable, and an
        // unreadable key must never look like no key at all.
        orderPaths.clear();
        reject();
        return;
      }
      orderPaths.add(key.group(1));
    }
  }

  /**
   * Returns exactly one row, whatever the data, so index 0 is repeatable
   * without an ORDER BY. SOQL rejects ordering an aggregate by an ungrouped
   * field, so requiring one here would be advice no author could follow.
   */
  public Boolean returnsExactlyOneRow() {
    return isAggregate && !hasGroupBy;
  }

  private static Integer depthZeroNumber(String soql, Pattern clause) {
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(soql);
    Matcher matcher = clause.matcher(masked);
    while (matcher.find()) {
      if (RecordHealthCheckSoqlTemplate.depthAt(masked, matcher.start()) == 0) {
        return Integer.valueOf(matcher.group(1));
      }
    }
    return null;
  }

  private static Boolean hasDepthZeroClause(String soql, Pattern clause) {
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(soql);
    Matcher matcher = clause.matcher(masked);
    while (matcher.find()) {
      if (RecordHealthCheckSoqlTemplate.depthAt(masked, matcher.start()) == 0) {
        return true;
      }
    }
    return false;
  }

  /** Splits on commas that sit outside parentheses and string literals. */
  private static List<String> splitTopLevel(String value) {
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(value);
    List<String> parts = new List<String>();
    Integer depth = 0;
    Integer cursor = 0;
    for (Integer i = 0; i < masked.length(); i++) {
      String unit = masked.substring(i, i + 1);
      if (unit == '(') {
        depth++;
      } else if (unit == ')') {
        depth--;
      } else if (unit == ',' && depth == 0) {
        parts.add(value.substring(cursor, i));
        cursor = i + 1;
      }
    }
    parts.add(value.substring(cursor));
    return parts;
  }

  /**
   * Splits `MAX(CreatedDate) latest` into its expression and its alias.
   * Returns one element when the expression carries no trailing word, and
   * three-word input returns the whole string so the caller rejects it.
   */
  private static List<String> splitOnFirstGap(String expression) {
    String collapsed = expression.trim();
    Integer depth = 0;
    Integer gap = -1;
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(collapsed);
    for (Integer i = 0; i < masked.length(); i++) {
      String unit = masked.substring(i, i + 1);
      if (unit == '(') {
        depth++;
      } else if (unit == ')') {
        depth--;
      } else if (depth == 0 && isGap(unit)) {
        gap = i;
        break;
      }
    }
    if (gap < 0) {
      return new List<String>{ collapsed };
    }
    String tail = collapsed.substring(gap).trim();
    if (tail.contains(' ') || tail.contains('\t') || tail.contains('\n')) {
      return new List<String>{ collapsed };
    }
    return new List<String>{ collapsed.substring(0, gap), tail };
  }

  private static Boolean isGap(String unit) {
    return unit == ' ' || unit == '\t' || unit == '\n' || unit == '\r';
  }
}
