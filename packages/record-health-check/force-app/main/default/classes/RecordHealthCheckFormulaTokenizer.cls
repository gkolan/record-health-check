/**
 * Tokenizes authored Salesforce formulas without interpreting string contents as fields.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckFormulaTokenizer {
  /** Maximum lexical tokens accepted for one formula. */
  public static final Integer TOKEN_LIMIT = 4096;

  /** Returns a detached lexical result with source offsets. */
  public static Result tokenize(String formula) {
    Result result = new Result();
    if (String.isBlank(formula)) {
      return result;
    }
    Integer cursor = 0;
    while (cursor < formula.length()) {
      String character = formula.substring(cursor, cursor + 1);
      if (isWhitespace(character)) {
        cursor++;
        continue;
      }
      Token token = readToken(formula, cursor, character, result);
      Integer next = token.endOffset;
      if (result.tokens.size() == TOKEN_LIMIT) {
        result.tokens.clear();
        result.addFinding('FORMULA_COMPLEXITY_LIMIT', cursor, next);
        result.executable = false;
        return result;
      }
      result.tokens.add(token);
      cursor = next;
    }
    result.executable = result.findings.isEmpty();
    return result;
  }

  private static Token readToken(
    String formula,
    Integer cursor,
    String character,
    Result result
  ) {
    Integer next = cursor + 1;
    String kind;
    if (character == '"') {
      next = quotedEnd(formula, cursor, '"');
      kind = 'STRING';
      if (next > formula.length()) {
        next = formula.length();
        result.addFinding('INVALID_FORMULA_LITERAL', cursor, next);
      }
    } else if (character == '\'') {
      next = Math.min(quotedEnd(formula, cursor, '\''), formula.length());
      kind = 'STRING';
      result.addFinding('INVALID_FORMULA_LITERAL', cursor, next);
    } else if (isIdentifierStart(character)) {
      next = identifierEnd(formula, cursor);
      kind = identifierKind(formula, cursor, next);
    } else {
      return readNonWordToken(formula, cursor, character, result);
    }
    return new Token(kind, formula.substring(cursor, next), cursor, next);
  }

  private static String identifierKind(
    String formula,
    Integer cursor,
    Integer next
  ) {
    String word = formula.substring(cursor, next);
    Integer lookahead = next;
    while (
      lookahead < formula.length() &&
      isWhitespace(formula.substring(lookahead, lookahead + 1))
    ) {
      lookahead++;
    }
    String upper = word.toUpperCase();
    return lookahead < formula.length() &&
      formula.substring(lookahead, lookahead + 1) == '('
      ? 'FUNCTION'
      : upper == 'TRUE' ||
          upper == 'FALSE'
          ? 'BOOLEAN'
          : upper == 'NULL' ? 'NULL' : 'FIELD_PATH';
  }

  private static Token readNonWordToken(
    String formula,
    Integer cursor,
    String character,
    Result result
  ) {
    Integer next = cursor + 1;
    String kind;
    if (character == '$') {
      next = dollarGlobalEnd(formula, cursor);
      kind = 'FIELD_PATH';
    } else if (isDigit(character)) {
      next = numberEnd(formula, cursor);
      kind = 'NUMBER';
    } else if (character == '(') {
      kind = 'LPAREN';
    } else if (character == ')') {
      kind = 'RPAREN';
    } else if (character == ',') {
      kind = 'COMMA';
    } else if (isOperatorStart(character)) {
      next = operatorEnd(formula, cursor);
      kind = 'OPERATOR';
    } else {
      kind = 'OPERATOR';
      result.addFinding('INVALID_FORMULA', cursor, next);
    }
    return new Token(kind, formula.substring(cursor, next), cursor, next);
  }

  /** Returns the closing offset, or length + 1 when no unescaped closing quote exists. */
  private static Integer quotedEnd(
    String formula,
    Integer startOffset,
    String quote
  ) {
    Integer cursor = startOffset + 1;
    while (cursor < formula.length()) {
      if (formula.substring(cursor, cursor + 1) == quote) {
        Integer backslashes = 0;
        Integer previous = cursor - 1;
        while (
          previous > startOffset &&
          formula.substring(previous, previous + 1) == '\\'
        ) {
          backslashes++;
          previous--;
        }
        if (Math.mod(backslashes, 2) == 0) {
          return cursor + 1;
        }
      }
      cursor++;
    }
    return formula.length() + 1;
  }

  private static Integer identifierEnd(String formula, Integer startOffset) {
    Integer cursor = startOffset + 1;
    while (cursor < formula.length()) {
      String character = formula.substring(cursor, cursor + 1);
      if (isIdentifierPart(character) || character == '.' || character == ':') {
        cursor++;
      } else {
        break;
      }
    }
    return cursor;
  }

  private static Integer dollarGlobalEnd(String formula, Integer startOffset) {
    Integer cursor = startOffset + 1;
    while (
      cursor < formula.length() &&
      (isIdentifierPart(formula.substring(cursor, cursor + 1)) ||
      formula.substring(cursor, cursor + 1) == '.')
    ) {
      cursor++;
    }
    return cursor;
  }

  private static Integer numberEnd(String formula, Integer startOffset) {
    Integer cursor = startOffset + 1;
    Boolean decimalSeen = false;
    while (cursor < formula.length()) {
      String character = formula.substring(cursor, cursor + 1);
      if (isDigit(character)) {
        cursor++;
      } else if (character == '.' && !decimalSeen) {
        decimalSeen = true;
        cursor++;
      } else {
        break;
      }
    }
    if (
      cursor < formula.length() &&
      new Set<String>{ 'e', 'E' }
        .contains(formula.substring(cursor, cursor + 1))
    ) {
      Integer exponentEnd = cursor + 1;
      if (
        exponentEnd < formula.length() &&
        new Set<String>{ '+', '-' }
          .contains(formula.substring(exponentEnd, exponentEnd + 1))
      ) {
        exponentEnd++;
      }
      Integer exponentDigitsStart = exponentEnd;
      while (
        exponentEnd < formula.length() &&
        isDigit(formula.substring(exponentEnd, exponentEnd + 1))
      ) {
        exponentEnd++;
      }
      if (exponentEnd > exponentDigitsStart) {
        cursor = exponentEnd;
      }
    }
    return cursor;
  }

  private static Integer operatorEnd(String formula, Integer startOffset) {
    Integer next = startOffset + 1;
    if (next >= formula.length()) {
      return next;
    }
    String pair = formula.substring(startOffset, next + 1);
    return new Set<String>{ '<=', '>=', '<>', '!=', '&&', '||' }.contains(pair)
      ? next + 1
      : next;
  }

  private static Boolean isWhitespace(String character) {
    return character == ' ' ||
      character == '\t' ||
      character == '\n' ||
      character == '\r';
  }

  private static Boolean isIdentifierStart(String character) {
    return Pattern.matches('[A-Za-z_]', character);
  }

  private static Boolean isIdentifierPart(String character) {
    return Pattern.matches('[A-Za-z0-9_]', character);
  }

  private static Boolean isDigit(String character) {
    return Pattern.matches('[0-9]', character);
  }

  private static Boolean isOperatorStart(String character) {
    return new Set<String>{
        '+',
        '-',
        '*',
        '/',
        '^',
        '=',
        '<',
        '>',
        '!',
        '&',
        '|'
      }
      .contains(character);
  }

  /** One immutable lexical token positioned in the authored formula. */
  public class Token {
    public String kind { get; private set; }
    public String text { get; private set; }
    public Integer startOffset { get; private set; }
    public Integer endOffset { get; private set; }

    private Token(
      String kind,
      String text,
      Integer startOffset,
      Integer endOffset
    ) {
      this.kind = kind;
      this.text = text;
      this.startOffset = startOffset;
      this.endOffset = endOffset;
    }
  }

  /** One bounded lexical failure positioned in the authored formula. */
  public class Finding {
    public String code { get; private set; }
    public Integer startOffset { get; private set; }
    public Integer endOffset { get; private set; }

    private Finding(String code, Integer startOffset, Integer endOffset) {
      this.code = code;
      this.startOffset = startOffset;
      this.endOffset = endOffset;
    }
  }

  /** Detached tokenization result. */
  public class Result {
    public List<Token> tokens { get; private set; }
    public List<Finding> findings { get; private set; }
    public Boolean executable { get; private set; }

    private Result() {
      tokens = new List<Token>();
      findings = new List<Finding>();
      executable = true;
    }

    private void addFinding(
      String code,
      Integer startOffset,
      Integer endOffset
    ) {
      findings.add(new Finding(code, startOffset, endOffset));
    }
  }
}
