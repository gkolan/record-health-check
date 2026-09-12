/** Parses the authored inline-link construct without resolving runtime data. */
public class RecordHealthCheckInlineLinkParser {
  public static final Integer MAX_LINKS = 100;

  /** One structurally valid authored link and its original source span. */
  public class Link {
    public String expression;
    public String labelTemplate;
    public String hrefTemplate;
    public Integer startIndex;
    public Integer endIndex;
    public List<Span> valueTokenSpans = new List<Span>();
  }

  /** An absolute source span retained for nested value-token offsets. */
  public class Span {
    public Integer startIndex;
    public Integer endIndex;

    public Span(Integer startIndex, Integer endIndex) {
      this.startIndex = startIndex;
      this.endIndex = endIndex;
    }
  }

  /** Detached parse result. */
  public class Result {
    public List<Link> links = new List<Link>();
    public List<RecordHealthCheckTokenIssue> issues = new List<RecordHealthCheckTokenIssue>();
  }

  /** Scans authored source exactly once from left to right. */
  public static Result scan(String source) {
    Result result = new Result();
    if (String.isBlank(source)) {
      return result;
    }
    Integer cursor = 0;
    while (cursor < source.length()) {
      Integer startIndex = source.indexOf('{!link', cursor);
      if (startIndex < 0) {
        break;
      }
      Integer afterKeyword = startIndex + 6;
      if (
        afterKeyword < source.length() &&
        !isWhitespace(source.substring(afterKeyword, afterKeyword + 1)) &&
        source.substring(afterKeyword, afterKeyword + 1) != '}'
      ) {
        cursor = afterKeyword;
        continue;
      }
      ParseAttempt attempt = parseOne(source, startIndex);
      if (attempt.issue != null) {
        result.issues.add(attempt.issue);
        cursor = Math.max(startIndex + 2, attempt.nextIndex);
      } else {
        result.links.add(attempt.link);
        cursor = attempt.link.endIndex;
      }
      if (result.links.size() > MAX_LINKS) {
        result.issues.add(
          locatedIssue(
            'INLINE_LINK_LIMIT_EXCEEDED',
            startIndex,
            cursor,
            null,
            'A display field may contain at most 100 inline links.'
          )
        );
        break;
      }
    }
    return result;
  }

  /** Replaces authored link structures with their authored label templates. */
  public static String flattenToLabels(String source, List<Link> links) {
    if (String.isBlank(source) || links == null || links.isEmpty()) {
      return source;
    }
    List<String> pieces = new List<String>();
    Integer cursor = 0;
    for (Link link : links) {
      pieces.add(source.substring(cursor, link.startIndex));
      pieces.add(link.labelTemplate);
      cursor = link.endIndex;
    }
    pieces.add(source.substring(cursor));
    return String.join(pieces, '');
  }

  /** Masks complete link spans while preserving absolute source length. */
  public static String maskLinks(String source, List<Link> links) {
    if (String.isBlank(source) || links == null || links.isEmpty()) {
      return source;
    }
    List<String> units = new List<String>();
    for (Integer index = 0; index < source.length(); index++) {
      units.add(source.substring(index, index + 1));
    }
    for (Link link : links) {
      for (Integer index = link.startIndex; index < link.endIndex; index++) {
        units[index] = ' ';
      }
    }
    return String.join(units, '');
  }

  /** True only on the explicitly link-capable authored display surfaces. */
  public static Boolean isAllowedSurface(String surface) {
    return new Set<String>{
        RecordHealthCheckTemplateService.SURFACE_DISPLAY,
        RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE,
        RecordHealthCheckTokenSurfaces.UNABLE_MESSAGE,
        RecordHealthCheckTokenSurfaces.NOT_APPLICABLE_MESSAGE,
        RecordHealthCheckTokenSurfaces.FIX_MESSAGE,
        RecordHealthCheckTokenSurfaces.DISPLAY_FOUND,
        RecordHealthCheckTokenSurfaces.DISPLAY_EXPECTED
      }
      .contains(surface);
  }

  private static ParseAttempt parseOne(String source, Integer startIndex) {
    ParseAttempt attempt = new ParseAttempt();
    ParseState state = new ParseState();
    state.cursor = startIndex + 6;
    Boolean linkClosed = false;

    while (state.cursor < source.length()) {
      state.cursor = skipWhitespace(source, state.cursor);
      if (state.cursor >= source.length()) {
        return failed(
          attempt,
          'INLINE_LINK_MALFORMED',
          startIndex,
          source.length(),
          null,
          'The inline link is incomplete; close its attributes and final brace.'
        );
      }
      if (source.substring(state.cursor, state.cursor + 1) == '}') {
        linkClosed = true;
        state.cursor++;
        break;
      }
      ParseAttempt attributeFailure = readAttribute(
        source,
        startIndex,
        attempt,
        state
      );
      if (attributeFailure != null) {
        return attributeFailure;
      }
    }

    if (!linkClosed) {
      return failed(
        attempt,
        'INLINE_LINK_MALFORMED',
        startIndex,
        source.length(),
        null,
        'The inline link is incomplete; close its attributes and final brace.'
      );
    }

    if (
      !state.attributes.containsKey('label') ||
      !state.attributes.containsKey('href')
    ) {
      return failed(
        attempt,
        'INLINE_LINK_REQUIRED_ATTRIBUTE_MISSING',
        startIndex,
        state.cursor,
        state.attributes.containsKey('label') ? 'href' : 'label',
        'Inline links require one label and one href attribute.'
      );
    }
    Link link = new Link();
    link.expression = source.substring(startIndex, state.cursor);
    link.labelTemplate = state.attributes.get('label');
    link.hrefTemplate = state.attributes.get('href');
    link.startIndex = startIndex;
    link.endIndex = state.cursor;
    link.valueTokenSpans.addAll(state.spansByAttribute.get('label'));
    link.valueTokenSpans.addAll(state.spansByAttribute.get('href'));
    attempt.link = link;
    attempt.nextIndex = state.cursor;
    return attempt;
  }

  private class ParseState {
    public Integer cursor;
    public Boolean attributeClosed;
    public List<String> valueUnits;
    public List<Span> valueSpans;
    public Map<String, String> attributes = new Map<String, String>();
    public Map<String, List<Span>> spansByAttribute = new Map<String, List<Span>>();
  }
  private static ParseAttempt readAttribute(
    String source,
    Integer startIndex,
    ParseAttempt attempt,
    ParseState state
  ) {
    Integer nameStart = state.cursor;
    while (
      state.cursor < source.length() &&
      isAttributeNameUnit(source.substring(state.cursor, state.cursor + 1))
    ) {
      state.cursor++;
    }
    if (state.cursor == nameStart) {
      return failed(
        attempt,
        'INLINE_LINK_MALFORMED',
        startIndex,
        state.cursor + 1,
        null,
        'Inline-link attributes must use lowercase name="value" syntax.'
      );
    }
    String attributeName = source.substring(nameStart, state.cursor);
    if (
      state.cursor + 1 >= source.length() ||
      source.substring(state.cursor, state.cursor + 2) != '="'
    ) {
      return failed(
        attempt,
        'INLINE_LINK_MALFORMED',
        nameStart,
        Math.min(source.length(), state.cursor + 2),
        attributeName,
        'Inline-link attributes must use lowercase name="value" syntax.'
      );
    }
    if (attributeName != 'label' && attributeName != 'href') {
      return failed(
        attempt,
        'INLINE_LINK_UNKNOWN_ATTRIBUTE',
        nameStart,
        state.cursor,
        attributeName,
        'Only the label and href attributes are supported.'
      );
    }
    if (state.attributes.containsKey(attributeName)) {
      return failed(
        attempt,
        'INLINE_LINK_DUPLICATE_ATTRIBUTE',
        nameStart,
        state.cursor,
        attributeName,
        'Each inline-link attribute may appear only once.'
      );
    }
    state.cursor += 2;
    return readAttributeValue(source, nameStart, attributeName, attempt, state);
  }
  private static ParseAttempt readAttributeValue(
    String source,
    Integer nameStart,
    String attributeName,
    ParseAttempt attempt,
    ParseState state
  ) {
    state.valueUnits = new List<String>();
    state.valueSpans = new List<Span>();
    state.attributeClosed = false;
    ParseAttempt valueFailure = readValueUnits(
      source,
      attributeName,
      attempt,
      state
    );
    if (valueFailure != null) {
      return valueFailure;
    }
    if (!state.attributeClosed) {
      return failed(
        attempt,
        'INLINE_LINK_MALFORMED',
        nameStart,
        source.length(),
        attributeName,
        'The inline-link attribute is missing its closing double quote.'
      );
    }
    state.attributes.put(attributeName, String.join(state.valueUnits, ''));
    state.spansByAttribute.put(attributeName, state.valueSpans);
    return null;
  }

  private static ParseAttempt readValueUnits(
    String source,
    String attributeName,
    ParseAttempt attempt,
    ParseState state
  ) {
    while (state.cursor < source.length()) {
      String unit = source.substring(state.cursor, state.cursor + 1);
      if (unit == '"') {
        state.attributeClosed = true;
        state.cursor++;
        break;
      }
      if (unit == '\\') {
        if (state.cursor + 1 >= source.length()) {
          break;
        }
        if (readEscapedUnit(source, attributeName, attempt, state) != null) {
          return attempt;
        }
        continue;
      }
      if (
        state.cursor + 1 < source.length() &&
        source.substring(state.cursor, state.cursor + 2) == '{!'
      ) {
        if (readNestedValue(source, attributeName, attempt, state) != null) {
          return attempt;
        }
        continue;
      }
      if (readPlainUnit(unit, attributeName, attempt, state) != null) {
        return attempt;
      }
    }
    return null;
  }
  /** Rejects isolated braces, then appends and advances one ordinary character. */
  private static ParseAttempt readPlainUnit(
    String unit,
    String attributeName,
    ParseAttempt attempt,
    ParseState state
  ) {
    if (unit == '{' || unit == '}') {
      return failed(
        attempt,
        'INLINE_LINK_NESTING_INVALID',
        state.cursor,
        state.cursor + 1,
        attributeName,
        'Braces inside a link attribute must form one complete value token.'
      );
    }
    state.valueUnits.add(unit);
    state.cursor++;
    return null;
  }
  private static ParseAttempt readEscapedUnit(
    String source,
    String attributeName,
    ParseAttempt attempt,
    ParseState state
  ) {
    String escaped = source.substring(state.cursor + 1, state.cursor + 2);
    if (escaped != '"' && escaped != '\\') {
      return failed(
        attempt,
        'INLINE_LINK_MALFORMED_ESCAPE',
        state.cursor,
        state.cursor + 2,
        attributeName,
        'Inline-link attributes escape only a quote or backslash.'
      );
    }
    state.valueUnits.add(escaped);
    state.cursor += 2;
    return null;
  }
  private static ParseAttempt readNestedValue(
    String source,
    String attributeName,
    ParseAttempt attempt,
    ParseState state
  ) {
    Integer tokenEnd = findValueTokenEnd(source, state.cursor);
    if (
      tokenEnd < 0 ||
      source.substring(
        state.cursor,
        Math.min(source.length(), state.cursor + 6)
      ) == '{!link'
    ) {
      return failed(
        attempt,
        'INLINE_LINK_NESTING_INVALID',
        state.cursor,
        tokenEnd < 0 ? source.length() : tokenEnd,
        attributeName,
        'A link may contain value tokens, but not another link or incomplete token.'
      );
    }
    state.valueUnits.add(
      RecordHealthCheckTemplateParser.unescapeAttribute(
        source.substring(state.cursor, tokenEnd)
      )
    );
    state.valueSpans.add(new Span(state.cursor, tokenEnd));
    state.cursor = tokenEnd;
    return null;
  }
  private static Integer findValueTokenEnd(String source, Integer startIndex) {
    Boolean inQuote = false;
    Boolean escaped = false;
    for (Integer cursor = startIndex + 2; cursor < source.length(); cursor++) {
      String unit = source.substring(cursor, cursor + 1);
      if (escaped) {
        escaped = false;
      } else if (unit == '\\') {
        escaped = true;
      } else if (unit == '"') {
        inQuote = !inQuote;
      } else if (unit == '}' && !inQuote) {
        return cursor + 1;
      }
    }
    return -1;
  }

  private static Integer skipWhitespace(String source, Integer cursor) {
    while (
      cursor < source.length() &&
      isWhitespace(source.substring(cursor, cursor + 1))
    ) {
      cursor++;
    }
    return cursor;
  }

  private static Boolean isWhitespace(String unit) {
    return unit == ' ' || unit == '\t' || unit == '\n' || unit == '\r';
  }

  private static Boolean isAttributeNameUnit(String unit) {
    return 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
      .contains(unit);
  }

  private static ParseAttempt failed(
    ParseAttempt attempt,
    String code,
    Integer startIndex,
    Integer endIndex,
    String attribute,
    String message
  ) {
    attempt.issue = locatedIssue(
      code,
      startIndex,
      endIndex,
      attribute,
      message
    );
    attempt.nextIndex = Math.max(startIndex + 1, endIndex);
    return attempt;
  }

  private static RecordHealthCheckTokenIssue locatedIssue(
    String code,
    Integer startIndex,
    Integer endIndex,
    String attribute,
    String message
  ) {
    RecordHealthCheckTokenIssue issue = new RecordHealthCheckTokenIssue(
      code,
      null,
      message
    );
    issue.startIndex = startIndex;
    issue.endIndex = endIndex;
    issue.attribute = attribute;
    return issue;
  }

  private class ParseAttempt {
    public Link link;
    public RecordHealthCheckTokenIssue issue;
    public Integer nextIndex;
  }
}
