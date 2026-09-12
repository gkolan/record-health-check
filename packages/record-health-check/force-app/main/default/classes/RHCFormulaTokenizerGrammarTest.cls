/** Extended lexical grammar and correction regressions for formula planning. */
@IsTest
private class RHCFormulaTokenizerGrammarTest {
  @IsTest
  static void exponentNumbersNeverBecomeFields() {
    Test.startTest();
    RecordHealthCheckFormulaTokenizer.Result result = RecordHealthCheckFormulaTokenizer.tokenize(
      '-1.5e-2 + 6E+3'
    );
    Test.stopTest();

    Assert.areEqual(
      new List<String>{ 'OPERATOR', 'NUMBER', 'OPERATOR', 'NUMBER' },
      kinds(result.tokens),
      'Unary signs stay operators while complete decimal exponents stay numeric tokens.'
    );
    Assert.areEqual(
      new List<String>{ '-', '1.5e-2', '+', '6E+3' },
      texts(result.tokens),
      'Exponent text and source spelling must remain intact.'
    );
  }

  @IsTest
  static void allNamedFunctionCandidatesStayFunctions() {
    List<String> names = new List<String>{
      'ISNUMBER',
      'PRIORVALUE',
      'CASESAFEID',
      'ADDMONTHS',
      'SPLIT',
      'VLOOKUP',
      'ISCHANGED',
      'FUTUREFUNC'
    };
    List<String> calls = new List<String>();
    for (String name : names) {
      calls.add(name + ' (Name)');
    }

    Test.startTest();
    RecordHealthCheckFormulaTokenizer.Result result = RecordHealthCheckFormulaTokenizer.tokenize(
      String.join(calls, ' + ')
    );
    Test.stopTest();

    Set<String> functionTokens = new Set<String>();
    Set<String> fieldTokens = new Set<String>();
    for (RecordHealthCheckFormulaTokenizer.Token token : result.tokens) {
      if (token.kind == 'FUNCTION') {
        functionTokens.add(token.text);
      } else if (token.kind == 'FIELD_PATH') {
        fieldTokens.add(token.text);
      }
    }
    Assert.areEqual(
      new Set<String>(names),
      functionTokens,
      'Support is independent of lexical function classification.'
    );
    Assert.areEqual(
      new Set<String>{ 'Name' },
      fieldTokens,
      'Only the bare field argument may be a field token.'
    );
  }

  @IsTest
  static void oddAndEvenBackslashesCloseAtTheCorrectQuote() {
    String quote = '"';
    String slash = '\\';
    String odd = quote + 'A' + slash + quote + 'B' + quote + ' + Website';
    String even = quote + 'A' + slash + slash + quote + ' + Website';

    Test.startTest();
    RecordHealthCheckFormulaTokenizer.Result oddResult = RecordHealthCheckFormulaTokenizer.tokenize(
      odd
    );
    RecordHealthCheckFormulaTokenizer.Result evenResult = RecordHealthCheckFormulaTokenizer.tokenize(
      even
    );
    Test.stopTest();

    Assert.isTrue(
      oddResult.findings.isEmpty(),
      'One backslash escapes the quote inside the string.'
    );
    Assert.isTrue(
      evenResult.findings.isEmpty(),
      'Two backslashes leave the following quote as the delimiter.'
    );
    Assert.areEqual(
      'Website',
      oddResult.tokens[2].text,
      'Scanning resumes after the odd-escape string.'
    );
    Assert.areEqual(
      'Website',
      evenResult.tokens[2].text,
      'Scanning resumes after the even-escape string.'
    );
  }

  @IsTest
  static void correctedDraftClearsLexicalFailureImmediately() {
    Test.startTest();
    RecordHealthCheckFormulaPlanService.FormulaPlan rejected = RecordHealthCheckFormulaPlanService.plan(
      'ISPICKVAL(Industry, \'Approved\')',
      Account.SObjectType,
      'ApplicabilityFormula__c'
    );
    RecordHealthCheckFormulaPlanService.FormulaPlan corrected = RecordHealthCheckFormulaPlanService.plan(
      'ISPICKVAL(Industry, "Approved")',
      Account.SObjectType,
      'ApplicabilityFormula__c'
    );
    Test.stopTest();

    Assert.areEqual(
      'INVALID_FORMULA_LITERAL',
      rejected.findings[0].code,
      'The malformed draft is rejected.'
    );
    Assert.isTrue(
      corrected.findings.isEmpty(),
      'Correcting only the quotes must clear the finding without a cache reset.'
    );
    Assert.areEqual(
      new List<String>{ 'Industry' },
      corrected.selectedFields,
      'The corrected plan selects Industry once.'
    );
  }

  @IsTest
  static void loneOpeningQuoteIsNotExecutable() {
    assertUnclosedLiteral('"');
  }

  @IsTest
  static void escapedFinalQuoteIsNotAClosingDelimiter() {
    assertUnclosedLiteral('"A' + '\\' + '"');
  }

  @IsTest
  static void missingFinalQuoteKeepsBoundedOffsets() {
    assertUnclosedLiteral('"A');
    assertUnclosedLiteral('\'A');
  }

  @IsTest
  static void closedEmptyAndEvenEscapeStringsRemainExecutable() {
    for (String formula : new List<String>{ '""', '"A' + '\\' + '\\' + '"' }) {
      RecordHealthCheckFormulaTokenizer.Result result = RecordHealthCheckFormulaTokenizer.tokenize(
        formula
      );
      Assert.isTrue(
        result.executable,
        'A real closing delimiter must remain executable.'
      );
      Assert.isTrue(
        result.findings.isEmpty(),
        'Valid string boundaries must not produce findings.'
      );
      Assert.areEqual(
        formula,
        result.tokens[0].text,
        'The complete literal spelling must be retained.'
      );
    }
  }

  @IsTest
  static void unclosedLiteralPlanningRedactsItsContents() {
    String formula = '"sensitive literal' + '\\' + '"';
    RecordHealthCheckFormulaPlanService.FormulaPlan plan = RecordHealthCheckFormulaPlanService.plan(
      formula,
      Account.SObjectType,
      'PassConditionFormula__c'
    );
    Assert.areEqual(
      'INVALID_FORMULA_LITERAL',
      plan.findings[0].code,
      'Planning must retain the lexical failure code.'
    );
    Assert.areEqual(
      '[redacted literal]',
      plan.findings[0].offendingToken,
      'Malformed literal text must not appear in the finding.'
    );
  }

  private static void assertUnclosedLiteral(String formula) {
    RecordHealthCheckFormulaTokenizer.Result result = RecordHealthCheckFormulaTokenizer.tokenize(
      formula
    );
    Assert.isFalse(
      result.executable,
      'An unterminated string must not be executable.'
    );
    Assert.areEqual(
      1,
      result.findings.size(),
      'An unterminated string must produce one lexical finding.'
    );
    Assert.areEqual(
      'INVALID_FORMULA_LITERAL',
      result.findings[0].code,
      'The finding must identify the malformed literal.'
    );
    Assert.areEqual(
      0,
      result.findings[0].startOffset,
      'The finding starts at the opening quote.'
    );
    Assert.areEqual(
      formula.length(),
      result.findings[0].endOffset,
      'The finding covers the entire unterminated literal.'
    );
  }

  private static List<String> kinds(
    List<RecordHealthCheckFormulaTokenizer.Token> tokens
  ) {
    List<String> result = new List<String>();
    for (RecordHealthCheckFormulaTokenizer.Token token : tokens) {
      result.add(token.kind);
    }
    return result;
  }

  private static List<String> texts(
    List<RecordHealthCheckFormulaTokenizer.Token> tokens
  ) {
    List<String> result = new List<String>();
    for (RecordHealthCheckFormulaTokenizer.Token token : tokens) {
      result.add(token.text);
    }
    return result;
  }
}
