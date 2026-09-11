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
}
