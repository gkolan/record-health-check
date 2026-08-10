@IsTest
private class RecordHealthCheckFormulaSyntaxTest {
  @IsTest
  static void recognizesSyntaxWordsCaseInsensitively() {
    Test.startTest();
    Boolean upperCaseFunction = RecordHealthCheckFormulaSyntax.isSyntaxWord(
      'IF'
    );
    Boolean lowerCaseLiteral = RecordHealthCheckFormulaSyntax.isSyntaxWord(
      'true'
    );
    Test.stopTest();

    Assert.isTrue(upperCaseFunction, 'Formula functions should be recognized.');
    Assert.isTrue(
      lowerCaseLiteral,
      'Formula literals should be recognized without case sensitivity.'
    );
  }

  @IsTest
  static void rejectsFieldsAndBlankTokens() {
    Test.startTest();
    Boolean field = RecordHealthCheckFormulaSyntax.isSyntaxWord('Amount');
    Boolean blank = RecordHealthCheckFormulaSyntax.isSyntaxWord(' ');
    Boolean missing = RecordHealthCheckFormulaSyntax.isSyntaxWord(null);
    Test.stopTest();

    Assert.isFalse(
      field,
      'A field API name must remain available to the planner.'
    );
    Assert.isFalse(blank, 'A blank token is not formula syntax.');
    Assert.isFalse(missing, 'A null token is not formula syntax.');
  }
}
