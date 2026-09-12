/** Verifies transaction-scoped formula compile cache behavior. */
@IsTest
private class RHCFormulaCompilerCacheTest {
  @IsTest
  static void successfulCompileIsReusedWithinTransaction() {
    CountingCompiler compiler = new CountingCompiler(true);
    RecordHealthCheckFormulaPlanService.compilerOverride = compiler;
    try {
      Test.startTest();
      planName();
      planName();
      Test.stopTest();

      Assert.areEqual(
        1,
        compiler.calls,
        'An identical successful compile plan must be reused within one transaction.'
      );
    } finally {
      RecordHealthCheckFormulaPlanService.compilerOverride = null;
    }
  }

  @IsTest
  static void failedCompileIsNotCached() {
    CountingCompiler compiler = new CountingCompiler(false);
    RecordHealthCheckFormulaPlanService.compilerOverride = compiler;
    try {
      Test.startTest();
      planName();
      planName();
      Test.stopTest();

      Assert.areEqual(
        2,
        compiler.calls,
        'Permission-sensitive or capability failures must not be cached as successful plans.'
      );
    } finally {
      RecordHealthCheckFormulaPlanService.compilerOverride = null;
    }
  }

  @IsTest
  static void displayFormulaPlanningUsesRuntimeAutoType() {
    CapturingCompiler compiler = new CapturingCompiler();
    RecordHealthCheckFormulaPlanService.compilerOverride = compiler;
    try {
      RecordHealthCheckFormulaPlanService.plan(
        'Name',
        Account.SObjectType,
        'DisplayFoundFormula__c',
        'TEXT'
      );

      Assert.areEqual(
        'AUTO',
        compiler.declaredReturnType,
        'Display formulas must use the same AUTO contract in planning and runtime.'
      );
    } finally {
      RecordHealthCheckFormulaPlanService.compilerOverride = null;
    }
  }

  @IsTest
  static void explicitNumberPlanningRejectsBooleanFormula() {
    RecordHealthCheckFormulaPlanService.FormulaPlan plan = RecordHealthCheckFormulaPlanService.plan(
      'TRUE',
      Account.SObjectType,
      'ExpectedRecordFormula__c',
      'NUMBER'
    );

    Assert.areEqual(1, plan.findings.size());
    Assert.areEqual(
      'INVALID_FORMULA',
      plan.findings[0].code,
      'Planning must enforce the same strict declared NUMBER type as runtime.'
    );
  }

  @IsTest
  static void compileFailureCarriesBoundedMessageFreeDiagnostics() {
    String secretFormula = 'IF(Name = "customer-secret", Missing__c, 0)';
    String hostileMessage =
      secretFormula +
      '\n' +
      secretFormula +
      secretFormula +
      secretFormula;

    Test.startTest();
    String detail = RecordHealthCheckCompileDiagnostic.fromAttempt(
      'DECIMAL',
      new SyntheticCompilerException(hostileMessage)
    );
    Test.stopTest();

    Assert.isTrue(detail.startsWith('DECIMAL:'));
    Assert.isTrue(
      detail.length() <= 120,
      'Diagnostics must have a hard bound.'
    );
    Assert.isFalse(
      detail.contains('customer-secret'),
      'Compiler diagnostics must never echo formula text or literal contents.'
    );
    Assert.isFalse(
      detail.contains('\n'),
      'Compiler diagnostics must remain one line.'
    );
    Assert.areEqual(
      'STRING:COMPILER_RETURNED_NULL',
      RecordHealthCheckCompileDiagnostic.fromAttempt('STRING', null),
      'A null compiler result must remain distinguishable from an exception.'
    );
    List<String> manyCategories = new List<String>();
    for (Integer index = 0; index < 100; index++) {
      manyCategories.add(detail);
    }
    Assert.areEqual(
      1000,
      RecordHealthCheckCompileDiagnostic.boundedCategories(manyCategories)
        .length(),
      'Aggregated AUTO probe diagnostics must have a hard response bound.'
    );
  }

  @IsTest
  static void failedPlanRetainsProbeDiagnosticsWithoutSourceText() {
    DiagnosticCompiler compiler = new DiagnosticCompiler();
    RecordHealthCheckFormulaPlanService.compilerOverride = compiler;
    try {
      RecordHealthCheckFormulaPlanService.FormulaPlan plan = RecordHealthCheckFormulaPlanService.plan(
        'Name = "private-literal"',
        Account.SObjectType,
        'DisplayFoundFormula__c',
        'AUTO'
      );

      Assert.areEqual(1, plan.findings.size());
      Assert.areEqual(
        'BOOLEAN:FORMULA_COMPILE_REJECTED; DECIMAL:FORMULA_COMPILE_REJECTED',
        plan.findings[0].diagnosticDetail
      );
      Assert.isFalse(
        plan.findings[0].diagnosticDetail.contains('private-literal')
      );
    } finally {
      RecordHealthCheckFormulaPlanService.compilerOverride = null;
    }
  }

  @IsTest
  static void metadataAdapterCarriesSafeCompilerDiagnostics() {
    RecordHealthCheckFormulaPlanService.compilerOverride = new DiagnosticCompiler();
    try {
      Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{
          'DeveloperName' => 'Compiler_Diagnostics',
          'EvaluationType__c' => 'FORMULA',
          'PassConditionFormula__c' => 'Name = "private-literal"'
        }
      );

      List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RecordHealthCheckFormulaMetadataAdapter.issues(
        check,
        Account.SObjectType
      );

      Assert.areEqual(1, issues.size());
      Assert.areEqual(
        'BOOLEAN:FORMULA_COMPILE_REJECTED; DECIMAL:FORMULA_COMPILE_REJECTED',
        issues[0].diagnosticDetail
      );
      Assert.isFalse(issues[0].message.contains('private-literal'));
    } finally {
      RecordHealthCheckFormulaPlanService.compilerOverride = null;
    }
  }

  private static void planName() {
    RecordHealthCheckFormulaPlanService.plan(
      'Name',
      Account.SObjectType,
      'DisplayFoundFormula__c',
      'TEXT'
    );
  }

  private class CountingCompiler implements RecordHealthCheckFormulaPlanService.Compiler {
    private Integer calls = 0;
    private Boolean succeeds;

    private CountingCompiler(Boolean succeeds) {
      this.succeeds = succeeds;
    }

    public RecordHealthCheckFormulaPlanService.CompileResult compile(
      String formula,
      Schema.SObjectType baseType,
      String configurationField,
      String declaredReturnType
    ) {
      calls++;
      return new RecordHealthCheckFormulaPlanService.CompileResult(
        succeeds,
        succeeds ? null : 'INVALID_FORMULA',
        null
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

  private class DiagnosticCompiler implements RecordHealthCheckFormulaPlanService.Compiler {
    public RecordHealthCheckFormulaPlanService.CompileResult compile(
      String formula,
      Schema.SObjectType baseType,
      String configurationField,
      String declaredReturnType
    ) {
      return new RecordHealthCheckFormulaPlanService.CompileResult(
        false,
        'INVALID_FORMULA',
        null,
        'BOOLEAN:FORMULA_COMPILE_REJECTED; DECIMAL:FORMULA_COMPILE_REJECTED'
      );
    }
  }

  private class SyntheticCompilerException extends Exception {
  }
}
