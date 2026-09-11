/** Shared semantic validation for subscriber-authored plugin outcomes. */
public with sharing class RecordHealthCheckOutcomeValidator {
  private static final Integer REASON_CODE_MAX = 80;
  private static final Set<String> VALID_STATUSES = new Set<String>{
    RecordHealthCheckStatus.PASS,
    RecordHealthCheckStatus.FAIL,
    RecordHealthCheckStatus.SKIPPED,
    RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
    RecordHealthCheckStatus.ERROR
  };

  /** One ordered, value-free contract violation. */
  public class Violation {
    public String reasonCode;
    public String message;
    public String side;
    public String declaredType;
    public Integer memberCount;
    public Boolean renderedBlank;
  }

  /** Returns every semantic violation in stable contract-precedence order. */
  public static List<Violation> validate(RecordHealthCheckOutcome outcome) {
    List<Violation> violations = new List<Violation>();
    if (outcome == null) {
      return violations;
    }
    if (!VALID_STATUSES.contains(outcome.status)) {
      violations.add(
        violation(
          RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID,
          'The outcome returned an unsupported status.'
        )
      );
    }
    if (
      outcome.reasonCode != null &&
      outcome.reasonCode.length() > REASON_CODE_MAX
    ) {
      violations.add(
        violation(
          RecordHealthCheckReasonCodes.PLUGIN_REASON_CODE_INVALID,
          'The outcome returned a reason code longer than 80 characters.'
        )
      );
    }
    if (
      outcome.status == RecordHealthCheckStatus.PASS ||
      outcome.status == RecordHealthCheckStatus.FAIL
    ) {
      addMissingViolation(violations, outcome.status, 'Found', outcome.found);
      addMissingViolation(
        violations,
        outcome.status,
        'Expected',
        outcome.expected
      );
    }
    return violations;
  }

  private static void addMissingViolation(
    List<Violation> violations,
    String status,
    String side,
    RecordHealthCheckValue value
  ) {
    Boolean listValue = value != null && value.isList();
    Boolean missing =
      value == null || (!listValue && String.isBlank(value.storedValue));
    if (!missing) {
      return;
    }
    Violation item = violation(
      RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING,
      'A ' + status + ' outcome must include a nonblank ' + side + ' value.'
    );
    item.side = side;
    item.declaredType = value?.dataType;
    item.memberCount = listValue ? value.storedValues.size() : null;
    item.renderedBlank = true;
    violations.add(item);
  }

  private static Violation violation(String reasonCode, String message) {
    Violation item = new Violation();
    item.reasonCode = reasonCode;
    item.message = message;
    return item;
  }
}
