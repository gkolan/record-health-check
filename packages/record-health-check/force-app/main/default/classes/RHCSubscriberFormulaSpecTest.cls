/**
 * Regression-first acceptance tests for subscriber formula tokenization.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCSubscriberFormulaSpecTest {
  @IsTest
  static void literalIsNotAField() {
    Test.startTest();
    List<RecordHealthCheckFormulaFieldScanner.FieldReference> references = RecordHealthCheckFormulaFieldScanner.scan(
      'ISPICKVAL(Industry, \'Banking\')',
      Account.SObjectType
    );
    Test.stopTest();

    Assert.areEqual(
      new Set<String>{ 'Industry' },
      pathsOf(references),
      'A single-quoted invalid formula literal must not expose its contents as a field reference.'
    );
  }

  @IsTest
  static void futureFunctionIsNotAField() {
    Test.startTest();
    List<RecordHealthCheckFormulaFieldScanner.FieldReference> references = RecordHealthCheckFormulaFieldScanner.scan(
      'FUTUREFUNC(NumberOfEmployees)',
      Account.SObjectType
    );
    Test.stopTest();

    Assert.areEqual(
      new Set<String>{ 'NumberOfEmployees' },
      pathsOf(references),
      'Any identifier followed by an opening parenthesis is a function token, not a field reference.'
    );
  }

  @IsTest
  static void escapedQuoteOffsets() {
    String formula = 'IF(Name = "A\\\"B", Website, "fallback")';

    Test.startTest();
    RecordHealthCheckFormulaTokenizer.Result result = RecordHealthCheckFormulaTokenizer.tokenize(
      formula
    );
    Test.stopTest();

    RecordHealthCheckFormulaTokenizer.Token website = tokenNamed(
      result.tokens,
      'Website'
    );
    Assert.isTrue(
      result.findings.isEmpty(),
      'Escaped quotes must remain valid.'
    );
    Assert.areEqual(
      'FIELD_PATH',
      website.kind,
      'The field following the escaped string must be classified independently.'
    );
    Assert.areEqual(
      'Website',
      formula.substring(website.startOffset, website.endOffset),
      'Token offsets must slice the original authored formula exactly.'
    );
  }

  @IsTest
  static void tokenCapBoundary() {
    String belowLimit = repeatedNumbers(
      RecordHealthCheckFormulaTokenizer.TOKEN_LIMIT - 1
    );
    String atLimit = repeatedNumbers(
      RecordHealthCheckFormulaTokenizer.TOKEN_LIMIT
    );
    String aboveLimit = repeatedNumbers(
      RecordHealthCheckFormulaTokenizer.TOKEN_LIMIT + 1
    );

    Test.startTest();
    RecordHealthCheckFormulaTokenizer.Result below = RecordHealthCheckFormulaTokenizer.tokenize(
      belowLimit
    );
    RecordHealthCheckFormulaTokenizer.Result accepted = RecordHealthCheckFormulaTokenizer.tokenize(
      atLimit
    );
    RecordHealthCheckFormulaTokenizer.Result rejected = RecordHealthCheckFormulaTokenizer.tokenize(
      aboveLimit
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckFormulaTokenizer.TOKEN_LIMIT - 1,
      below.tokens.size(),
      'Exactly 4095 tokens must remain executable.'
    );
    Assert.areEqual(
      RecordHealthCheckFormulaTokenizer.TOKEN_LIMIT,
      accepted.tokens.size(),
      'Exactly 4096 tokens must be retained.'
    );
    Assert.isTrue(
      accepted.findings.isEmpty(),
      'The configured token limit must not report overflow.'
    );
    Assert.areEqual(
      0,
      rejected.tokens.size(),
      'A formula above the token limit must not expose a partial executable plan.'
    );
    Assert.areEqual(
      'FORMULA_COMPLEXITY_LIMIT',
      rejected.findings[0].code,
      'Token 4097 must produce the stable complexity finding.'
    );
  }

  @IsTest
  static void unsupportedIsCapabilityDriven() {
    RejectingCompiler compiler = new RejectingCompiler();
    RecordHealthCheckFormulaPlanService.compilerOverride = compiler;
    try {
      Test.startTest();
      RecordHealthCheckFormulaPlanService.FormulaPlan plan = RecordHealthCheckFormulaPlanService.plan(
        'ISCHANGED(Name)',
        Account.SObjectType,
        'PassConditionFormula__c'
      );
      Test.stopTest();

      Assert.areEqual(
        1,
        compiler.calls,
        'A lexically and structurally valid formula must reach compile-only validation once.'
      );
      Assert.areEqual(
        'FORMULA_FUNCTION_NOT_SUPPORTED',
        plan.findings[0].code,
        'Unsupported-function classification must come from compiler capability evidence.'
      );
      Assert.areEqual(
        'ISCHANGED',
        plan.findings[0].offendingToken,
        'The compiler finding must identify the function token.'
      );
    } finally {
      RecordHealthCheckFormulaPlanService.compilerOverride = null;
    }
  }

  @IsTest
  static void declaredReturnTypeReachesCompiler() {
    CapturingCompiler compiler = new CapturingCompiler();
    RecordHealthCheckFormulaPlanService.compilerOverride = compiler;
    try {
      Test.startTest();
      RecordHealthCheckFormulaPlanService.plan(
        'Name',
        Account.SObjectType,
        'DisplayFoundFormula__c',
        'TEXT'
      );
      Test.stopTest();

      Assert.areEqual(
        'TEXT',
        compiler.declaredReturnType,
        'The shared planner must compile against the administrator-declared return type.'
      );
    } finally {
      RecordHealthCheckFormulaPlanService.compilerOverride = null;
    }
  }

  @IsTest
  static void classifiesEveryLexicalKind() {
    String formula = 'FUTURE (Account.Owner.Name, true, NULL, -5.1) <> false';

    Test.startTest();
    RecordHealthCheckFormulaTokenizer.Result result = RecordHealthCheckFormulaTokenizer.tokenize(
      formula
    );
    Test.stopTest();

    Assert.areEqual(
      new List<String>{
        'FUNCTION',
        'LPAREN',
        'FIELD_PATH',
        'COMMA',
        'BOOLEAN',
        'COMMA',
        'NULL',
        'COMMA',
        'OPERATOR',
        'NUMBER',
        'RPAREN',
        'OPERATOR',
        'BOOLEAN'
      },
      kindsOf(result.tokens),
      'The scanner must distinguish every supported lexical token kind.'
    );
  }

  @IsTest
  static void invalidQuotingDoesNotLeakLiteralContents() {
    Test.startTest();
    RecordHealthCheckFormulaTokenizer.Result singleQuoted = RecordHealthCheckFormulaTokenizer.tokenize(
      '\'SecretField__c\' & Name'
    );
    RecordHealthCheckFormulaTokenizer.Result unterminated = RecordHealthCheckFormulaTokenizer.tokenize(
      'Name = "SecretField__c'
    );
    RecordHealthCheckFormulaTokenizer.Result curlyQuoted = RecordHealthCheckFormulaTokenizer.tokenize(
      'Name = “SecretField__c”'
    );
    Test.stopTest();

    Assert.areEqual(
      'INVALID_FORMULA_LITERAL',
      singleQuoted.findings[0].code,
      'Single-quoted formula text must be rejected as one literal.'
    );
    Assert.areEqual(
      new Set<String>{ 'Name' },
      fieldTokens(singleQuoted.tokens),
      'Rejected single-quoted contents must not be scanned as fields.'
    );
    Assert.areEqual(
      'INVALID_FORMULA_LITERAL',
      unterminated.findings[0].code,
      'An unterminated double quote must span to end of input.'
    );
    Assert.areEqual(
      'INVALID_FORMULA',
      curlyQuoted.findings[0].code,
      'Curly quotes must be rejected as formula syntax.'
    );
  }

  @IsTest
  static void validationRuntimeParity() {
    String formula = 'NoSuchField__c + NoSuchField__c';
    Test.startTest();
    for (String configurationField : formulaSurfaces()) {
      Map<String, Object> values = new Map<String, Object>{
        'EvaluationType__c' => configurationField == 'FindInListFormula__c' ||
          configurationField == 'ExpectedRecordFormula__c'
          ? 'QUERY'
          : 'FORMULA',
        'PassConditionFormula__c' => 'TRUE'
      };
      values.put(configurationField, formula);
      if (configurationField == 'ApplicabilityFormula__c') {
        values.put('ApplicabilityMode__c', 'WHEN_FORMULA_TRUE');
      }
      RecordHealthCheckFormulaPlanService.FormulaPlan validationPlan = RecordHealthCheckFormulaPlanService.plan(
        formula,
        Account.SObjectType,
        configurationField
      );
      RecordHealthCheckFieldPlanner.FieldPlan runtimePlan = new RecordHealthCheckFieldPlanner()
        .planRecordFields(
          RecordHealthCheckTestDataFactory.check(values),
          Account.SObjectType
        );
      Assert.areEqual(
        findingTuples(validationPlan.findings),
        findingTuples(runtimePlan.formulaFindings),
        configurationField +
        ' must retain identical field, token, offset, and reason tuples in both callers.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void sharedPlanSortsFieldsAndRetainsUnresolvedOccurrence() {
    String formula = 'Website = Name && NoSuchField__c = 1';

    Test.startTest();
    RecordHealthCheckFormulaPlanService.FormulaPlan plan = RecordHealthCheckFormulaPlanService.plan(
      formula,
      Account.SObjectType,
      'PassConditionFormula__c'
    );
    Test.stopTest();

    Assert.areEqual(
      new List<String>{ 'Name', 'Website' },
      plan.selectedFields,
      'Resolved fields must be deduplicated and sorted lexically.'
    );
    Assert.areEqual(
      1,
      plan.findings.size(),
      'The unresolved occurrence must produce one detailed finding.'
    );
    Assert.areEqual(
      'NoSuchField__c',
      formula.substring(
        plan.findings[0].startOffset,
        plan.findings[0].endOffset
      ),
      'Finding offsets must point into the original source.'
    );
  }

  @IsTest
  static void findingCapBoundary() {
    List<String> fields = new List<String>();
    for (Integer index = 0; index < 101; index++) {
      fields.add('Missing' + index + '__c');
    }

    Test.startTest();
    RecordHealthCheckFormulaPlanService.FormulaPlan plan = RecordHealthCheckFormulaPlanService.plan(
      String.join(fields, ' + '),
      Account.SObjectType,
      'PassConditionFormula__c'
    );
    Test.stopTest();

    Assert.areEqual(
      100,
      plan.findings.size(),
      'One formula plan must retain at most 100 findings.'
    );
    Assert.isTrue(
      plan.findingsTruncated,
      'The detached plan must disclose omitted findings.'
    );
  }

  @IsTest
  static void dependencyOrigin() {
    RecordHealthCheckFieldPlanner resolver = new RecordHealthCheckFieldPlanner();
    resolver.calculatedFormulaOverrideByField = new Map<String, String>{
      'ExpectedRevenue' => 'MissingRelationship.Leaf__c'
    };

    Test.startTest();
    RecordHealthCheckFormulaPlanService.FormulaPlan plan = RecordHealthCheckFormulaPlanService.plan(
      'ExpectedRevenue > 0',
      Opportunity.SObjectType,
      'PassConditionFormula__c',
      'BOOLEAN',
      resolver
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      plan.findings.size(),
      'A missing calculated-field dependency must be retained by the shared plan.'
    );
    Assert.areEqual(
      'ExpectedRevenue',
      plan.findings[0].offendingToken,
      'Dependency diagnostics must retain the original authored field token.'
    );
    Assert.areEqual(
      'MissingRelationship.Leaf__c',
      plan.findings[0].dependencyPath,
      'Dependency diagnostics must separately identify the expanded failing path.'
    );
  }

  @IsTest
  static void lexicalFailureHasNoPartialExecutableFields() {
    Test.startTest();
    RecordHealthCheckFormulaPlanService.FormulaPlan plan = RecordHealthCheckFormulaPlanService.plan(
      'Name = \'SecretField__c\'',
      Account.SObjectType,
      'ApplicabilityFormula__c'
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      plan.selectedFields.size(),
      'A lexically invalid formula must not expose a partial executable field plan.'
    );
    Assert.areEqual(
      '[redacted literal]',
      plan.findings[0].offendingToken,
      'Invalid literal contents must be redacted in the shared finding.'
    );
  }

  @IsTest
  static void blankPlanIsDetachedAndEmpty() {
    Test.startTest();
    RecordHealthCheckFormulaPlanService.FormulaPlan plan = RecordHealthCheckFormulaPlanService.plan(
      null,
      null,
      'PassConditionFormula__c'
    );
    Test.stopTest();

    Assert.areEqual(0, plan.tokens.size(), 'A null formula has no tokens.');
    Assert.areEqual(
      0,
      plan.selectedFields.size(),
      'A null formula has no selected fields.'
    );
    Assert.areEqual(0, plan.findings.size(), 'A null formula has no findings.');
  }

  @IsTest
  static void metadataValidationUsesSharedPlan() {
    Id setId = RecordHealthCheckTestDataFactory.syntheticId(
      Record_Health_Check_Set__mdt.SObjectType,
      901
    );
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'Id' => setId,
        'DeveloperName' => 'RHC_SP_Formula',
        'ObjectApiName__c' => 'Account',
        'CardTitle__c' => 'Formula planning'
      }
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'RHC_SP_Formula_Website',
        'CheckTitle__c' => 'Website formula',
        'EvaluationOrder__c' => 1,
        'IsActive__c' => false,
        'EvaluationType__c' => 'FORMULA',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Website needs review.',
        'PassConditionFormula__c' => 'NoSuchField__c = 1',
        'Record_Health_Check_Set__c' => setId
      }
    );

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckMetadataValidator()
      .validateRecords(
        new List<Record_Health_Check_Set__mdt>{ checkSet },
        new List<Record_Health_Check__mdt>{ check }
      );
    Test.stopTest();

    Boolean found = false;
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      found =
        found ||
        (issue.componentName == 'RHC_SP_Formula_Website' &&
        issue.fieldName == 'PassConditionFormula__c' &&
        issue.reasonCode == RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED);
    }
    Assert.isTrue(
      found,
      'Inactive draft Checks must receive the shared planner finding during metadata validation. Actual issues: ' +
      JSON.serialize(issues)
    );
  }

  @IsTest
  static void quotesDoNotAffectSoql() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'QUERY',
        'SourceQuery__c' => 'SELECT Id FROM Account WHERE Industry = \'Banking\'',
        'SourceQueryField__c' => 'Id'
      }
    );

    Test.startTest();
    RecordHealthCheckFieldPlanner.FieldPlan plan = new RecordHealthCheckFieldPlanner()
      .planRecordFields(check, Account.SObjectType);
    RecordHealthCheckQuerySchemaValidator.validateSupportedSubset(
      check.SourceQuery__c
    );
    Test.stopTest();

    Assert.isTrue(
      plan.formulaFindings.isEmpty(),
      'SOQL single-quoted literals must never receive formula-literal diagnostics.'
    );
    Assert.areEqual(
      new Set<String>{ 'Id' },
      plan.selectedFields,
      'SOQL literal contents must not become record-plan field dependencies.'
    );
  }

  private static Set<String> pathsOf(
    List<RecordHealthCheckFormulaFieldScanner.FieldReference> references
  ) {
    Set<String> paths = new Set<String>();
    for (
      RecordHealthCheckFormulaFieldScanner.FieldReference reference : references
    ) {
      paths.add(reference.path);
    }
    return paths;
  }

  private static RecordHealthCheckFormulaTokenizer.Token tokenNamed(
    List<RecordHealthCheckFormulaTokenizer.Token> tokens,
    String text
  ) {
    for (RecordHealthCheckFormulaTokenizer.Token token : tokens) {
      if (token.text == text) {
        return token;
      }
    }
    return null;
  }

  private static List<String> kindsOf(
    List<RecordHealthCheckFormulaTokenizer.Token> tokens
  ) {
    List<String> kinds = new List<String>();
    for (RecordHealthCheckFormulaTokenizer.Token token : tokens) {
      kinds.add(token.kind);
    }
    return kinds;
  }

  private static Set<String> fieldTokens(
    List<RecordHealthCheckFormulaTokenizer.Token> tokens
  ) {
    Set<String> fields = new Set<String>();
    for (RecordHealthCheckFormulaTokenizer.Token token : tokens) {
      if (token.kind == 'FIELD_PATH') {
        fields.add(token.text);
      }
    }
    return fields;
  }

  private static String repeatedNumbers(Integer count) {
    List<String> values = new List<String>();
    for (Integer index = 0; index < count; index++) {
      values.add('1');
    }
    return String.join(values, ' ');
  }

  private static List<String> findingTuples(
    List<RecordHealthCheckFormulaPlanService.Finding> findings
  ) {
    List<String> tuples = new List<String>();
    for (RecordHealthCheckFormulaPlanService.Finding finding : findings) {
      tuples.add(
        finding.configurationField +
          '|' +
          finding.offendingToken +
          '|' +
          finding.startOffset +
          '|' +
          finding.endOffset +
          '|' +
          finding.code
      );
    }
    return tuples;
  }

  private static List<String> formulaSurfaces() {
    return new List<String>{
      'ApplicabilityFormula__c',
      'PassConditionFormula__c',
      'DisplayFoundFormula__c',
      'DisplayExpectedFormula__c',
      'FindInListFormula__c',
      'ExpectedRecordFormula__c'
    };
  }

  private class RejectingCompiler implements RecordHealthCheckFormulaPlanService.Compiler {
    private Integer calls = 0;

    public RecordHealthCheckFormulaPlanService.CompileResult compile(
      String formula,
      Schema.SObjectType baseType,
      String configurationField,
      String declaredReturnType
    ) {
      calls++;
      return new RecordHealthCheckFormulaPlanService.CompileResult(
        false,
        'FORMULA_FUNCTION_NOT_SUPPORTED',
        'ISCHANGED'
      );
    }
  }

  private class CapturingCompiler implements RecordHealthCheckFormulaPlanService.Compiler {
    private String declaredReturnType;

    public RecordHealthCheckFormulaPlanService.CompileResult compile(
      String formula,
      Schema.SObjectType baseType,
      String configurationField,
      String declaredReturnType
    ) {
      this.declaredReturnType = declaredReturnType;
      return new RecordHealthCheckFormulaPlanService.CompileResult(
        true,
        null,
        null
      );
    }
  }
}
