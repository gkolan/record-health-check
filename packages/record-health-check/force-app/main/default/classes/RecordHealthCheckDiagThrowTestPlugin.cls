/** Test-only plugin that proves entry into the evaluate boundary before throwing. */
@IsTest
public class RecordHealthCheckDiagThrowTestPlugin implements RecordHealthCheckPlugin {
  public static Integer calls = 0;

  public Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    calls++;
    throw new EvaluationFailureException('Expected evaluate failure.');
  }

  public class EvaluationFailureException extends Exception {
  }
}
