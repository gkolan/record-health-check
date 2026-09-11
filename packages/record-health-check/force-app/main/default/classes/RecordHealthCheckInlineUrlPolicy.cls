/** Strict, side-effect-free destination policy for inline presentation links. */
public class RecordHealthCheckInlineUrlPolicy {
  public static final Integer MAX_URL_LENGTH = 2000;

  /** Validates URL structure that is knowable before merge values resolve. */
  public static RecordHealthCheckTokenIssue validateAuthored(
    String hrefTemplate
  ) {
    String value = trimAscii(hrefTemplate);
    List<RecordHealthCheckToken> tokens = RecordHealthCheckTemplateParser.parse(
      value
    );
    if (tokens.size() == 1 && tokens[0].expression == value) {
      if (tokens[0].formatName != null || tokens[0].fallbackValue != null) {
        return issue(
          'INLINE_LINK_WHOLE_URL_TOKEN_ATTRIBUTES',
          'A whole-URL token cannot declare format or fallback attributes.'
        );
      }
      return null;
    }

    Integer hostEnd = authorityEnd(value);
    if (value.startsWith('https://')) {
      for (RecordHealthCheckToken token : tokens) {
        if (token.startIndex < hostEnd) {
          return issue(
            'INLINE_LINK_DYNAMIC_AUTHORITY',
            'URL tokens may appear only after the HTTPS authority.'
          );
        }
      }
    } else if (!value.startsWith('/') || value.startsWith('//')) {
      if (!tokens.isEmpty() && firstTokenBeforePath(value, tokens[0])) {
        return issue(
          'INLINE_LINK_DYNAMIC_AUTHORITY',
          'URL tokens cannot construct a scheme, host, userinfo, or port.'
        );
      }
      return issue(
        'INLINE_LINK_UNSAFE_URL',
        'Use one same-org path beginning with / or a complete HTTPS URL.'
      );
    }

    String representative = replaceTokens(value, tokens, 'value');
    return sanitizeComplete(representative) == null
      ? issue(
          'INLINE_LINK_UNSAFE_URL',
          'The inline destination does not satisfy the strict URL policy.'
        )
      : null;
  }

  /** Returns a trimmed safe complete destination, or null without echoing it. */
  public static String sanitizeComplete(String candidate) {
    if (String.isBlank(candidate)) {
      return null;
    }
    String value = trimAscii(candidate);
    if (
      value.length() > MAX_URL_LENGTH ||
      !Pattern.matches('[\\x00-\\x7F]*', value) ||
      Pattern.compile('[\\x00-\\x1F\\x7F]').matcher(value).find() ||
      Pattern.compile('\\s').matcher(value).find() ||
      value.contains('\\') ||
      !hasValidPercentEscapes(value) ||
      hasEncodedTraversal(value)
    ) {
      return null;
    }
    if (value.startsWith('/')) {
      return value.startsWith('//') ? null : value;
    }
    if (!value.startsWith('https://')) {
      return null;
    }
    Integer endIndex = authorityEnd(value);
    String authority = value.substring(8, endIndex);
    if (String.isBlank(authority) || authority.contains('@')) {
      return null;
    }
    String host = authority;
    Integer colon = authority.lastIndexOf(':');
    if (colon >= 0) {
      if (authority.substring(colon + 1) != '443') {
        return null;
      }
      host = authority.substring(0, colon);
    }
    return isValidHost(host) ? value : null;
  }

  private static Boolean firstTokenBeforePath(
    String value,
    RecordHealthCheckToken token
  ) {
    Integer slash = value.indexOf('/');
    return slash < 0 || token.startIndex <= slash;
  }

  private static Integer authorityEnd(String value) {
    Integer endIndex = value.length();
    for (String delimiter : new List<String>{ '/', '?', '#' }) {
      Integer found = value.indexOf(delimiter, 8);
      if (found >= 0 && found < endIndex) {
        endIndex = found;
      }
    }
    return endIndex;
  }

  private static String replaceTokens(
    String source,
    List<RecordHealthCheckToken> tokens,
    String replacement
  ) {
    String value = '';
    Integer cursor = 0;
    for (RecordHealthCheckToken token : tokens) {
      value += source.substring(cursor, token.startIndex) + replacement;
      cursor = token.endIndex;
    }
    return value + source.substring(cursor);
  }

  private static Boolean hasValidPercentEscapes(String value) {
    String hex = '0123456789abcdefABCDEF';
    Set<String> forbidden = new Set<String>{
      '00',
      '01',
      '02',
      '03',
      '04',
      '05',
      '06',
      '07',
      '08',
      '09',
      '0a',
      '0b',
      '0c',
      '0d',
      '0e',
      '0f',
      '10',
      '11',
      '12',
      '13',
      '14',
      '15',
      '16',
      '17',
      '18',
      '19',
      '1a',
      '1b',
      '1c',
      '1d',
      '1e',
      '1f',
      '25',
      '5c',
      '7f'
    };
    for (Integer index = 0; index < value.length(); index++) {
      if (value.substring(index, index + 1) != '%') {
        continue;
      }
      if (
        index + 2 >= value.length() ||
        !hex.contains(value.substring(index + 1, index + 2)) ||
        !hex.contains(value.substring(index + 2, index + 3))
      ) {
        return false;
      }
      if (
        forbidden.contains(value.substring(index + 1, index + 3).toLowerCase())
      ) {
        return false;
      }
      index += 2;
    }
    return true;
  }

  private static Boolean hasEncodedTraversal(String value) {
    Integer query = value.indexOf('?');
    Integer fragment = value.indexOf('#');
    Integer endIndex = value.length();
    if (query >= 0) {
      endIndex = query;
    }
    if (fragment >= 0 && fragment < endIndex) {
      endIndex = fragment;
    }
    String path = value.substring(0, endIndex)
      .toLowerCase()
      .replace('%2e', '.');
    for (String segment : path.split('/')) {
      if (segment == '.' || segment == '..') {
        return true;
      }
    }
    return false;
  }

  private static Boolean isValidHost(String host) {
    if (
      String.isBlank(host) ||
      host.length() > 253 ||
      host.endsWith('.') ||
      host.contains('..') ||
      host.contains('%') ||
      host.toLowerCase() == 'localhost'
    ) {
      return false;
    }
    List<String> labels = host.split('\\.');
    Boolean numeric = true;
    for (String label : labels) {
      if (
        label.length() > 63 ||
        !Pattern.matches('[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?', label)
      ) {
        return false;
      }
      numeric = numeric && Pattern.matches('[0-9]+', label);
    }
    if (!numeric) {
      return true;
    }
    if (labels.size() != 4) {
      return false;
    }
    for (String label : labels) {
      if (Integer.valueOf(label) > 255) {
        return false;
      }
    }
    return true;
  }

  private static String trimAscii(String value) {
    if (value == null) {
      return null;
    }
    Integer startIndex = 0;
    Integer endIndex = value.length();
    while (
      startIndex < endIndex &&
      ' \t\n\r'.contains(value.substring(startIndex, startIndex + 1))
    ) {
      startIndex++;
    }
    while (
      endIndex > startIndex &&
      ' \t\n\r'.contains(value.substring(endIndex - 1, endIndex))
    ) {
      endIndex--;
    }
    return value.substring(startIndex, endIndex);
  }

  private static RecordHealthCheckTokenIssue issue(
    String code,
    String message
  ) {
    return new RecordHealthCheckTokenIssue(code, null, message);
  }
}
