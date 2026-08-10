/**
 * Identifies Salesforce formula-language words that are syntax rather than
 * record field references.
 */
public with sharing class RecordHealthCheckFormulaSyntax {
  private static final Set<String> SYNTAX_WORDS = new Set<String>{
    'ABS',
    'AND',
    'BEGINS',
    'BLANKVALUE',
    'BR',
    'CASE',
    'CEILING',
    'CONTAINS',
    'CURRENCYRATE',
    'DATE',
    'DATETIMEVALUE',
    'DATEVALUE',
    'DAY',
    'EXP',
    'FALSE',
    'FIND',
    'FLOOR',
    'HTMLENCODE',
    'HOUR',
    'HYPERLINK',
    'IF',
    'IMAGE',
    'INCLUDES',
    'ISBLANK',
    'ISNULL',
    'ISPICKVAL',
    'JSENCODE',
    'JSINHTMLENCODE',
    'LEFT',
    'LEN',
    'LN',
    'LOG',
    'LOWER',
    'MAX',
    'MID',
    'MIN',
    'MOD',
    'MONTH',
    'NOT',
    'NOW',
    'NULL',
    'NULLVALUE',
    'OR',
    'PI',
    'POWER',
    'REGEX',
    'RIGHT',
    'ROUND',
    'SQRT',
    'SUBSTITUTE',
    'TEXT',
    'TODAY',
    'TRIM',
    'TRUE',
    'UPPER',
    'URLENCODE',
    'VALUE',
    'WEEKDAY',
    'YEAR'
  };

  /**
   * Reports whether a formula token is a recognized function or literal.
   *
   * @param word Formula token to classify; matching is case-insensitive.
   * @return True when the token belongs to formula syntax rather than a field.
   */
  public static Boolean isSyntaxWord(String word) {
    return String.isNotBlank(word) && SYNTAX_WORDS.contains(word.toUpperCase());
  }
}
