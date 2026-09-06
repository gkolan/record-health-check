/** Parses and validates namespaced Record Health Check merge tokens. */
public class RecordHealthCheckTemplateParser {
  private static final Integer MAX_TOKENS = 100;
  private static final Pattern TOKEN_PATTERN = Pattern.compile(
    '\\{!([^{}]+)\\}'
  );
  private static final Pattern ATTRIBUTE_PATTERN = Pattern.compile(
    '\\s+([A-Za-z][A-Za-z0-9]*)="((?:\\\\.|[^"\\\\])*)"'
  );

  public static List<RecordHealthCheckToken> parse(String template) {
    List<RecordHealthCheckToken> tokens = new List<RecordHealthCheckToken>();
    if (String.isBlank(template)) {
      return tokens;
    }
    Matcher matcher = TOKEN_PATTERN.matcher(template);
    while (matcher.find()) {
      String body = matcher.group(1).trim();
      Integer firstSpace = firstWhitespaceIndex(body);
      String reference = firstSpace < 0 ? body : body.substring(0, firstSpace);
      String attributes = firstSpace < 0 ? '' : body.substring(firstSpace);
      Integer dot = reference.indexOf('.');
      String namespaceName = dot > 0 ? reference.substring(0, dot) : null;
      String property = dot > 0 &&
        dot < reference.length() - 1
        ? reference.substring(dot + 1)
        : null;
      RecordHealthCheckToken token = new RecordHealthCheckToken(
        matcher.group(0),
        namespaceName,
        property,
        null,
        matcher.start(),
        matcher.end()
      );
      if (reference.contains('|')) {
        token.attributeError = 'Pipe fallback syntax is not supported. Use fallback="...".';
      } else if (String.isNotBlank(attributes)) {
        Matcher attributeMatcher = ATTRIBUTE_PATTERN.matcher(attributes);
        Integer cursor = 0;
        Set<String> seen = new Set<String>();
        while (attributeMatcher.find()) {
          if (attributeMatcher.start() != cursor) {
            token.attributeError = 'Token attributes must use name="value" syntax.';
            break;
          }
          String name = attributeMatcher.group(1);
          String value = unescapeAttribute(attributeMatcher.group(2));
          if (seen.contains(name)) {
            token.attributeError = 'Duplicate token attribute "' + name + '".';
            break;
          }
          seen.add(name);
          if (name == 'format') {
            token.formatName = value;
          } else if (name == 'fallback') {
            token.fallbackValue = value;
          } else {
            token.attributeError = 'Unknown token attribute "' + name + '".';
            break;
          }
          cursor = attributeMatcher.end();
        }
        if (token.attributeError == null && cursor != attributes.length()) {
          token.attributeError = 'Token attributes must use name="value" syntax.';
        }
      }
      if (
        token.namespaceName != null &&
        RecordHealthCheckTokenRegistry.NAMESPACES.contains(token.namespaceName)
      ) {
        token.shape = RecordHealthCheckTokenRegistry.resolve(
          token.namespaceName,
          token.propertyPath
        );
      }
      tokens.add(token);
    }
    return tokens;
  }

  public static String unescapeAttribute(String value) {
    return value.replace('\\"', '"').replace('\\\\', '\\');
  }

  public static Integer firstWhitespaceIndex(String value) {
    for (Integer i = 0; i < value.length(); i++) {
      String unit = value.substring(i, i + 1);
      if (unit == ' ' || unit == '\t' || unit == '\n' || unit == '\r') {
        return i;
      }
    }
    return -1;
  }

  public static List<RecordHealthCheckTokenIssue> validate(
    String template,
    String surface
  ) {
    List<RecordHealthCheckTokenIssue> issues = new List<RecordHealthCheckTokenIssue>();
    if (String.isBlank(template)) {
      return issues;
    }
    List<RecordHealthCheckToken> tokens = parse(template);
    if (containsStrayBrace(template, tokens)) {
      issues.add(
        issue(
          'MALFORMED_TOKEN',
          null,
          'Curly braces are reserved for complete merge tokens and cannot appear outside one.'
        )
      );
      return issues;
    }
    if (tokens.size() > MAX_TOKENS) {
      issues.add(
        issue(
          'TOKEN_LIMIT_EXCEEDED',
          null,
          'A template may contain at most 100 tokens.'
        )
      );
    }
    for (RecordHealthCheckToken token : tokens) {
      if (token.attributeError != null) {
        issues.add(
          issue('MALFORMED_TOKEN', token.expression, token.attributeError)
        );
      } else if (token.namespaceName == null || token.propertyPath == null) {
        issues.add(
          issue(
            'TOKEN_NAMESPACE_REQUIRED',
            token.expression,
            'Flat merge tokens are not supported. Use {!record.' +
              token.expression.substring(2, token.expression.length() - 1) +
              '}.'
          )
        );
      } else if (
        !RecordHealthCheckTokenRegistry.NAMESPACES.contains(token.namespaceName)
      ) {
        issues.add(
          issue(
            'UNSUPPORTED_TOKEN_NAMESPACE',
            token.expression,
            unsupportedNamespaceMessage(token.namespaceName)
          )
        );
      } else if (!token.shape.isUsable()) {
        // Parsing resolves a shape for every known namespace, so by here the
        // shape exists and carries its own reason and message.
        issues.add(
          issue(token.shape.reasonCode, token.expression, token.shape.message)
        );
      } else if (
        !RecordHealthCheckTokenSurfaces.allows(surface, token.namespaceName)
      ) {
        issues.add(
          issue(
            'TOKEN_NOT_ALLOWED_ON_SURFACE',
            token.expression,
            notAllowedMessage(surface, token.namespaceName)
          )
        );
      } else if (
        token.formatName != null &&
        !RecordHealthCheckTokenSurfaces.allowsFormat(surface)
      ) {
        issues.add(
          issue(
            'TOKEN_FORMAT_NOT_ALLOWED',
            token.expression,
            'The format attribute is allowed only in display templates.'
          )
        );
      } else if (token.formatName != null && !token.shape.isTypedField) {
        issues.add(
          issue(
            'TOKEN_FORMAT_NOT_ALLOWED',
            token.expression,
            'The format attribute is allowed only on tokens that name a ' +
            'Salesforce field, which is record fields and query row fields.'
          )
        );
      } else if (
        token.formatName != null &&
        !RecordHealthCheckDisplayFormat.isFormatApiName(token.formatName)
      ) {
        issues.add(
          issue(
            'UNKNOWN_TOKEN_FORMAT',
            token.expression,
            'Unknown format API name "' +
              token.formatName +
              '". Use an uppercase API name.'
          )
        );
      }
    }
    return issues;
  }

  /**
   * Names the supported alternative when the namespace looks like an attempt
   * to index a namespace that is not a collection.
   */
  private static String unsupportedNamespaceMessage(String namespaceName) {
    Boolean looksIndexed =
      namespaceName.endsWith(']') && namespaceName.contains('[');
    String base = 'Unsupported token namespace "' + namespaceName + '".';
    if (!looksIndexed) {
      return base;
    }
    return base +
      ' A Check has one result, not a list of results. To read a row the ' +
      'Check queried, use {!rhcQuery.sourceRows[1].Field}.';
  }

  private static String notAllowedMessage(
    String surface,
    String namespaceName
  ) {
    if (surface == RecordHealthCheckTemplateService.SURFACE_SOQL) {
      return 'Only record tokens are allowed in SOQL templates. A query ' +
        'cannot reference values that exist only after it runs.';
    }
    if (namespaceName == 'rhcQuery') {
      return 'Query row tokens are not available here, because the Check\'s ' +
        'queries have not produced rows at this point.';
    }
    if (namespaceName == 'rhcResult') {
      return 'Result tokens are not allowed in URL templates.';
    }
    return 'Tokens from the "' +
      namespaceName +
      '" namespace are not allowed on this surface.';
  }

  public static Boolean containsStrayBrace(
    String template,
    List<RecordHealthCheckToken> tokens
  ) {
    Integer cursor = 0;
    for (RecordHealthCheckToken token : tokens) {
      String outsideToken = template.substring(cursor, token.startIndex);
      if (outsideToken.contains('{') || outsideToken.contains('}')) {
        return true;
      }
      cursor = token.endIndex;
    }
    String trailingText = template.substring(cursor);
    return trailingText.contains('{') || trailingText.contains('}');
  }

  public static RecordHealthCheckTokenIssue issue(
    String code,
    String token,
    String message
  ) {
    return new RecordHealthCheckTokenIssue(code, token, message);
  }

  public static Set<String> recordPaths(String template, String surface) {
    assertValid(template, surface);
    Set<String> paths = new Set<String>();
    for (RecordHealthCheckToken token : parse(template)) {
      if (token.namespaceName == 'record') {
        paths.add(token.propertyPath);
      }
    }
    return paths;
  }

  public static void assertValid(String template, String surface) {
    List<RecordHealthCheckTokenIssue> issues = validate(template, surface);
    if (!issues.isEmpty()) {
      RecordHealthCheckTemplateService.TemplateException ex = new RecordHealthCheckTemplateService.TemplateException(
        issues[0].message
      );
      ex.reasonCode = issues[0].reasonCode;
      ex.token = issues[0].token;
      throw ex;
    }
  }
}
