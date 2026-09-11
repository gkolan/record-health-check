/**
 * Produces detached, permission-sensitive formula field plans for validation and runtime callers.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckFormulaPlanService {
  public static final Integer FINDING_LIMIT = 100;
  @TestVisible
  private static Compiler compilerOverride;
  private static Set<String> successfulCompileKeys = new Set<String>();

  /** Plans lexical tokens and directly referenced accessible record fields. */
  public static FormulaPlan plan(
    String formula,
    Schema.SObjectType baseType,
    String configurationField,
    String declaredReturnType,
    RecordHealthCheckFieldPlanner resolver
  ) {
    FormulaPlan plan = new FormulaPlan();
    if (String.isBlank(formula)) {
      return plan;
    }
    RecordHealthCheckFormulaTokenizer.Result lexical = RecordHealthCheckFormulaTokenizer.tokenize(
      formula
    );
    plan.tokens.addAll(lexical.tokens);
    for (
      RecordHealthCheckFormulaTokenizer.Finding lexicalFinding : lexical.findings
    ) {
      plan.findings.add(
        finding(
          lexicalFinding.code,
          configurationField,
          lexicalFinding.code == 'INVALID_FORMULA_LITERAL'
            ? '[redacted literal]'
            : safeSlice(
                formula,
                lexicalFinding.startOffset,
                lexicalFinding.endOffset
              ),
          lexicalFinding.startOffset,
          lexicalFinding.endOffset,
          baseType,
          null
        )
      );
    }
    if (!lexical.executable || baseType == null) {
      applyFindingLimit(plan);
      return plan;
    }

    Set<String> selected = new Set<String>();
    resolver = resolver == null
      ? new RecordHealthCheckFieldPlanner()
      : resolver;
    Set<String> visitedDependencies = new Set<String>();
    for (RecordHealthCheckFormulaTokenizer.Token token : lexical.tokens) {
      if (token.kind != 'FIELD_PATH' || token.text.startsWith('$')) {
        continue;
      }
      List<RecordHealthCheckFormulaFieldScanner.FieldReference> references = RecordHealthCheckFormulaFieldScanner.scan(
        token.text,
        baseType
      );
      if (references.isEmpty()) {
        plan.findings.add(
          finding(
            RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED,
            configurationField,
            token.text,
            token.startOffset,
            token.endOffset,
            baseType,
            null
          )
        );
        continue;
      }
      String path = references[0].path;
      String reasonCode = resolver.resolutionReasonCode(baseType, path);
      if (reasonCode == null) {
        selected.add(path);
        RecordHealthCheckFormulaDepsPlanner.Expansion expansion = RecordHealthCheckFormulaDepsPlanner.expand(
          resolver,
          baseType,
          baseType,
          references[0],
          visitedDependencies
        );
        selected.addAll(expansion.selectedFields);
        for (
          RecordHealthCheckFormulaDepsPlanner.DependencyFinding dependencyFinding : expansion.findings
        ) {
          plan.findings.add(
            finding(
              dependencyFinding.code,
              configurationField,
              token.text,
              token.startOffset,
              token.endOffset,
              baseType,
              dependencyFinding.dependencyPath
            )
          );
        }
      } else {
        RecordHealthCheckFormulaDepsPlanner.Expansion expansion = RecordHealthCheckFormulaDepsPlanner.expand(
          resolver,
          baseType,
          baseType,
          references[0],
          visitedDependencies
        );
        selected.addAll(expansion.selectedFields);
        for (
          RecordHealthCheckFormulaDepsPlanner.DependencyFinding dependencyFinding : expansion.findings
        ) {
          plan.findings.add(
            finding(
              dependencyFinding.code,
              configurationField,
              token.text,
              token.startOffset,
              token.endOffset,
              baseType,
              dependencyFinding.dependencyPath
            )
          );
        }
        plan.findings.add(
          finding(
            reasonCode,
            configurationField,
            token.text,
            token.startOffset,
            token.endOffset,
            baseType,
            null
          )
        );
      }
    }
    plan.selectedFields.addAll(selected);
    plan.selectedFields.sort();
    if (plan.findings.isEmpty()) {
      addCompileFinding(
        plan,
        formula,
        baseType,
        configurationField,
        normalizedReturnType(declaredReturnType, configurationField)
      );
    }
    applyFindingLimit(plan);
    return plan;
  }

  /** Plans with an inferred return type for the original shared API. */
  public static FormulaPlan plan(
    String formula,
    Schema.SObjectType baseType,
    String configurationField
  ) {
    return plan(formula, baseType, configurationField, null);
  }

  /** Plans with the caller's describe resolver and controlled dependency fixtures. */
  public static FormulaPlan plan(
    String formula,
    Schema.SObjectType baseType,
    String configurationField,
    String declaredReturnType
  ) {
    return plan(
      formula,
      baseType,
      configurationField,
      declaredReturnType,
      new RecordHealthCheckFieldPlanner()
    );
  }

  private static void applyFindingLimit(FormulaPlan plan) {
    if (plan.findings.size() <= FINDING_LIMIT) {
      return;
    }
    plan.findingsTruncated = true;
    while (plan.findings.size() > FINDING_LIMIT) {
      plan.findings.remove(plan.findings.size() - 1);
    }
  }

  private static void addCompileFinding(
    FormulaPlan plan,
    String formula,
    Schema.SObjectType baseType,
    String configurationField,
    String declaredReturnType
  ) {
    String cacheKey = String.join(
      new List<String>{
        UserInfo.getOrganizationId(),
        UserInfo.getUserId(),
        String.valueOf(baseType),
        declaredReturnType,
        'api67',
        formula
      },
      '|'
    );
    if (successfulCompileKeys.contains(cacheKey)) {
      return;
    }
    Compiler selectedCompiler = compilerOverride == null
      ? new PlatformCompiler()
      : compilerOverride;
    CompileResult compiled = selectedCompiler.compile(
      formula,
      baseType,
      configurationField,
      declaredReturnType
    );
    if (compiled.succeeded) {
      successfulCompileKeys.add(cacheKey);
      return;
    }
    RecordHealthCheckFormulaTokenizer.Token token = functionToken(
      plan.tokens,
      compiled.offendingToken
    );
    plan.findings.add(
      finding(
        String.isBlank(compiled.code) ? 'INVALID_FORMULA' : compiled.code,
        configurationField,
        token == null ? compiled.offendingToken : token.text,
        token == null ? 0 : token.startOffset,
        token == null ? formula.length() : token.endOffset,
        baseType,
        null
      )
    );
  }

  private static String normalizedReturnType(
    String declaredReturnType,
    String configurationField
  ) {
    if (
      configurationField == 'PassConditionFormula__c' ||
      configurationField == 'ApplicabilityFormula__c'
    ) {
      return 'BOOLEAN';
    }
    return String.isBlank(declaredReturnType) ? 'AUTO' : declaredReturnType;
  }

  private static RecordHealthCheckFormulaTokenizer.Token functionToken(
    List<RecordHealthCheckFormulaTokenizer.Token> tokens,
    String name
  ) {
    if (String.isBlank(name)) {
      return null;
    }
    for (RecordHealthCheckFormulaTokenizer.Token token : tokens) {
      if (token.kind == 'FUNCTION' && token.text.equalsIgnoreCase(name)) {
        return token;
      }
    }
    return null;
  }

  private static Finding finding(
    String code,
    String configurationField,
    String offendingToken,
    Integer startOffset,
    Integer endOffset,
    Schema.SObjectType baseType,
    String dependencyPath
  ) {
    Finding result = new Finding();
    result.code = code;
    result.severity = 'ERROR';
    result.configurationField = configurationField;
    result.offendingToken = offendingToken;
    result.startOffset = startOffset;
    result.endOffset = endOffset;
    result.baseObject = baseType == null ? null : String.valueOf(baseType);
    result.dependencyPath = dependencyPath;
    return result;
  }

  /** Creates a structured finding for a parsed merge-template token. */
  public static Finding templateFinding(
    String code,
    String configurationField,
    RecordHealthCheckToken token,
    Schema.SObjectType baseType
  ) {
    return finding(
      code,
      configurationField,
      token?.expression,
      token?.startIndex,
      token?.endIndex,
      baseType,
      token?.shape?.fieldPath
    );
  }

  private static String safeSlice(
    String source,
    Integer startOffset,
    Integer endOffset
  ) {
    return source == null ? null : source.substring(startOffset, endOffset);
  }

  /** Compile-only capability boundary; production owns its implementation. */
  public interface Compiler {
    CompileResult compile(
      String formulaExpression,
      Schema.SObjectType baseType,
      String configurationField,
      String declaredReturnType
    );
  }

  /** Detached compiler outcome used by the platform and deterministic tests. */
  public class CompileResult {
    public Boolean succeeded { get; private set; }
    public String code { get; private set; }
    public String offendingToken { get; private set; }

    public CompileResult(
      Boolean succeeded,
      String code,
      String offendingToken
    ) {
      this.succeeded = succeeded;
      this.code = code;
      this.offendingToken = offendingToken;
    }
  }

  private class PlatformCompiler implements Compiler {
    public CompileResult compile(
      String formulaExpression,
      Schema.SObjectType baseType,
      String configurationField,
      String declaredReturnType
    ) {
      for (
        formulaeval.FormulaReturnType returnType : returnTypes(
          declaredReturnType
        )
      ) {
        try {
          Object compiled = Formula.builder()
            .withType(baseType)
            .withReturnType(returnType)
            .withFormula(formulaExpression)
            .treatNumericNullAsZero(true)
            .build();
          if (compiled != null) {
            return new CompileResult(true, null, null);
          }
        } catch (Exception ex) {
          continue;
        }
      }
      return new CompileResult(false, 'INVALID_FORMULA', null);
    }

    private List<formulaeval.FormulaReturnType> returnTypes(
      String declaredReturnType
    ) {
      if (declaredReturnType == 'BOOLEAN') {
        return new List<formulaeval.FormulaReturnType>{
          formulaeval.FormulaReturnType.BOOLEAN
        };
      }
      return new List<formulaeval.FormulaReturnType>{
        formulaeval.FormulaReturnType.BOOLEAN,
        formulaeval.FormulaReturnType.DECIMAL,
        formulaeval.FormulaReturnType.DATE,
        formulaeval.FormulaReturnType.DATETIME,
        formulaeval.FormulaReturnType.STRING,
        formulaeval.FormulaReturnType.DOUBLE,
        formulaeval.FormulaReturnType.INTEGER,
        formulaeval.FormulaReturnType.LONG
      };
    }
  }

  /** Detached planning result shared by metadata validation and runtime field loading. */
  public class FormulaPlan {
    public List<RecordHealthCheckFormulaTokenizer.Token> tokens {
      get;
      private set;
    }
    public List<String> selectedFields { get; private set; }
    public List<Finding> findings { get; private set; }
    public Boolean findingsTruncated { get; private set; }

    private FormulaPlan() {
      tokens = new List<RecordHealthCheckFormulaTokenizer.Token>();
      selectedFields = new List<String>();
      findings = new List<Finding>();
      findingsTruncated = false;
    }
  }

  /** One formula finding retaining its authored source coordinates. */
  public class Finding {
    public String code { get; private set; }
    public String severity { get; private set; }
    public String configurationField { get; private set; }
    public String offendingToken { get; private set; }
    public Integer startOffset { get; private set; }
    public Integer endOffset { get; private set; }
    public String baseObject { get; private set; }
    public String dependencyPath { get; private set; }
  }
}
