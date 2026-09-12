/**
 * Expands calculated-field dependencies with bounded, cycle-safe describe traversal.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckFormulaDepsPlanner {
  private static final Integer DEPTH_LIMIT = 10;

  /**
   * @param resolver Shared schema and calculated-field resolver.
   * @param baseType Root record type used by the eventual SELECT.
   * @param resolveType Type that owns the referenced calculated field.
   * @param reference Resolved calculated-field candidate.
   * @param visited Transaction-local path-aware cycle set.
   * @return Detached selected paths and dependency findings.
   */
  public static Expansion expand(
    RecordHealthCheckFieldPlanner resolver,
    Schema.SObjectType baseType,
    Schema.SObjectType resolveType,
    RecordHealthCheckFormulaFieldScanner.FieldReference reference,
    Set<String> visited
  ) {
    Expansion result = new Expansion();
    expandInto(
      result,
      resolver,
      baseType,
      resolveType,
      reference,
      '',
      0,
      visited
    );
    return result;
  }

  private static void expandInto(
    Expansion result,
    RecordHealthCheckFieldPlanner resolver,
    Schema.SObjectType baseType,
    Schema.SObjectType resolveType,
    RecordHealthCheckFormulaFieldScanner.FieldReference reference,
    String pathPrefix,
    Integer depth,
    Set<String> visited
  ) {
    RecordHealthCheckFieldPlanner.CalculatedDependency dependency = resolver.calculatedDependency(
      resolveType,
      reference.path,
      reference,
      pathPrefix
    );
    if (dependency == null) {
      return;
    }
    String dependencyPrefix = pathPrefix + dependency.relationshipPrefix;
    if (!visited.add(dependencyPrefix + dependency.visitKey)) {
      return;
    }
    if (depth >= DEPTH_LIMIT) {
      result.findings.add(
        new DependencyFinding(
          RecordHealthCheckReasonCodes.FORMULA_DEPENDENCY_DEPTH_EXCEEDED,
          dependencyPrefix + reference.path
        )
      );
      return;
    }
    RecordHealthCheckFormulaTokenizer.Result lexical = RecordHealthCheckFormulaTokenizer.tokenize(
      dependency.formula
    );
    if (!lexical.executable) {
      result.findings.add(
        new DependencyFinding(
          lexical.findings[0].code,
          dependencyPrefix + reference.path
        )
      );
      return;
    }
    expandTokens(
      result,
      resolver,
      baseType,
      dependency,
      dependencyPrefix,
      depth,
      visited,
      lexical
    );
  }

  private static void expandTokens(
    Expansion result,
    RecordHealthCheckFieldPlanner resolver,
    Schema.SObjectType baseType,
    RecordHealthCheckFieldPlanner.CalculatedDependency dependency,
    String dependencyPrefix,
    Integer depth,
    Set<String> visited,
    RecordHealthCheckFormulaTokenizer.Result lexical
  ) {
    for (RecordHealthCheckFormulaTokenizer.Token token : lexical.tokens) {
      if (token.kind != 'FIELD_PATH' || token.text.startsWith('$')) {
        continue;
      }
      List<RecordHealthCheckFormulaFieldScanner.FieldReference> references = RecordHealthCheckFormulaFieldScanner.scan(
        token.text,
        dependency.ownerType
      );
      String dependencyPath = dependencyPrefix + token.text;
      if (references.isEmpty()) {
        addFinding(result, resolver, baseType, dependencyPath);
        continue;
      }
      String resolvedPath = dependencyPrefix + references[0].path;
      String reasonCode = resolver.resolutionReasonCode(baseType, resolvedPath);
      if (reasonCode != null) {
        result.findings.add(new DependencyFinding(reasonCode, resolvedPath));
        continue;
      }
      result.selectedFields.add(resolvedPath);
      expandInto(
        result,
        resolver,
        baseType,
        dependency.ownerType,
        references[0],
        dependencyPrefix,
        depth + 1,
        visited
      );
    }
  }

  private static void addFinding(
    Expansion result,
    RecordHealthCheckFieldPlanner resolver,
    Schema.SObjectType baseType,
    String dependencyPath
  ) {
    String reasonCode = resolver.resolutionReasonCode(baseType, dependencyPath);
    result.findings.add(
      new DependencyFinding(
        String.isBlank(reasonCode)
          ? RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED
          : reasonCode,
        dependencyPath
      )
    );
  }

  /** Detached calculated-field expansion result. */
  public class Expansion {
    public Set<String> selectedFields { get; private set; }
    public List<DependencyFinding> findings { get; private set; }

    private Expansion() {
      selectedFields = new Set<String>();
      findings = new List<DependencyFinding>();
    }
  }

  /** One reason and root-qualified dependency path. */
  public class DependencyFinding {
    public String code { get; private set; }
    public String dependencyPath { get; private set; }

    private DependencyFinding(String code, String dependencyPath) {
      this.code = code;
      this.dependencyPath = dependencyPath;
    }
  }
}
