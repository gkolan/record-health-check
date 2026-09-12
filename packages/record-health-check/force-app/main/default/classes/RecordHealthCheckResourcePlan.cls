/** Calculates transaction admission without executing queries, DML, or plugins. */
public with sharing class RecordHealthCheckResourcePlan {
  private static final Integer FORMULA_CALL_BUDGET = 95;

  /** Fatal admission failure raised before a platform governor limit is reached. */
  public class BudgetException extends Exception implements RecordHealthCheckFatalFailure {
    public String reasonCode = 'TRANSACTION_BUDGET_EXCEEDED';
  }

  private RecordHealthCheckResourcePlan() {
  }

  /** Returns the conservative FormulaEval calls required by a scope. */
  public static Integer formulaCalls(
    List<Record_Health_Check__mdt> checks,
    Integer recordCount
  ) {
    if (recordCount == null || recordCount < 0) {
      throw new IllegalArgumentException(
        'recordCount must be zero or greater.'
      );
    }
    if (recordCount == 0 || checks == null || checks.isEmpty()) {
      return 0;
    }
    Integer planned = 0;
    for (Record_Health_Check__mdt check : checks) {
      if (check == null) {
        continue;
      }
      if (check.ApplicabilityMode__c == 'WHEN_FORMULA_TRUE') {
        planned += recordCount;
      }
      if (check.EvaluationType__c == 'FORMULA') {
        planned += recordCount;
        planned += displayFormulaCalls(
          check.DisplayFoundFormula__c,
          'AUTO',
          recordCount
        );
        planned += displayFormulaCalls(
          check.DisplayExpectedFormula__c,
          'AUTO',
          recordCount
        );
      } else if (check.EvaluationType__c == 'QUERY') {
        planned += displayFormulaCalls(
          check.FindInListFormula__c,
          check.FormulaResultType__c,
          recordCount
        );
        planned += displayFormulaCalls(
          check.ExpectedRecordFormula__c,
          check.FormulaResultType__c,
          recordCount
        );
      }
    }
    return planned;
  }

  /** Returns the largest safe automatic Batch scope up to the preferred size. */
  public static Integer defaultAsyncScope(
    List<Record_Health_Check__mdt> checks,
    Integer preferredSize
  ) {
    if (preferredSize == null || preferredSize < 1 || preferredSize > 200) {
      throw new IllegalArgumentException(
        'preferredSize must be between 1 and 200.'
      );
    }
    for (Integer size = preferredSize; size >= 1; size--) {
      if (formulaCalls(checks, size) <= FORMULA_CALL_BUDGET) {
        return size;
      }
    }
    throw budgetException(
      'The selected configuration cannot evaluate one record inside the FormulaEval budget.'
    );
  }

  /** Requires capacity for one savepoint, a possible rollback, and release. */
  public static void requireFenceCapacity(Integer reservedAfterHook) {
    if (reservedAfterHook == null || reservedAfterHook < 0) {
      throw new IllegalArgumentException(
        'reservedAfterHook must be zero or greater.'
      );
    }
    Integer remaining =
      Limits.getLimitDmlStatements() - Limits.getDmlStatements();
    Integer required = 3 + reservedAfterHook;
    if (remaining < required) {
      throw budgetException(
        'Plugin hook requires ' +
          required +
          ' DML statements of capacity, but only ' +
          remaining +
          ' remain.'
      );
    }
  }

  private static Integer displayFormulaCalls(
    String expression,
    String declaredType,
    Integer recordCount
  ) {
    if (String.isBlank(expression) || recordCount == 0) {
      return 0;
    }
    return String.isBlank(declaredType) || declaredType == 'AUTO'
      ? recordCount + 7
      : recordCount;
  }

  private static BudgetException budgetException(String message) {
    BudgetException failure = new BudgetException(message);
    failure.reasonCode = 'TRANSACTION_BUDGET_EXCEEDED';
    return failure;
  }
}
