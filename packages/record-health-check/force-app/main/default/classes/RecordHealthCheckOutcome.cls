/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * What a plugin returns for one record: a verdict and its values. Nothing else.
 *
 * A plugin does not stamp `recordId`, `checkDeveloperName`, or `severity`.
 * Identity comes from the map key and the scope; severity comes from
 * `FailureSeverity__c`. That removes a whole class of disagreement a
 * plugin-authored result would otherwise allow: a map key naming record A whose
 * body claims record B, or a scope dispatching Check X whose result claims Check
 * Y. The engine wraps each outcome into an Evaluation Result, so the two can
 * never disagree.
 *
 * A plugin also never touches rendered strings, display formats, action URLs,
 * currency display, or admin diagnostics. It reports a verdict and typed values;
 * the Framework does the rest. Anything else would recouple the extension boundary to
 * the display layer that the result contract deliberately separates.
 */
global class RecordHealthCheckOutcome {
  /** Plugin verdict status. */
  global String status { get; private set; }
  /** Stable plugin-authored reason code, at most 80 characters. */
  global String reasonCode { get; private set; }
  /** Typed value observed by the plugin. */
  global RecordHealthCheckValue found { get; private set; }
  /** Operator relating Found to Expected. */
  global String comparisonOperator { get; private set; }
  /** Typed target value. */
  global RecordHealthCheckValue expected { get; private set; }
  /** Optional typed evidence, snapshotted when attached. */
  global RecordHealthCheckEvidence evidence { get; private set; }

  private RecordHealthCheckOutcome(String status, String reasonCode) {
    this.status = status;
    this.reasonCode = reasonCode;
  }

  /** @return A successful plugin outcome. */
  global static RecordHealthCheckOutcome pass(String reasonCode) {
    return new RecordHealthCheckOutcome(
      RecordHealthCheckStatus.PASS,
      reasonCode
    );
  }

  /** @return A business-failure plugin outcome. */
  global static RecordHealthCheckOutcome fail(String reasonCode) {
    return new RecordHealthCheckOutcome(
      RecordHealthCheckStatus.FAIL,
      reasonCode
    );
  }

  /** Builds a PASS outcome whose typed operands are equal. */
  global static RecordHealthCheckOutcome passEquals(
    String reasonCode,
    RecordHealthCheckValue found,
    RecordHealthCheckValue expected
  ) {
    return equalityOutcome(
      RecordHealthCheckStatus.PASS,
      reasonCode,
      found,
      expected
    );
  }

  /** Builds a FAIL outcome whose typed operands are not equal. */
  global static RecordHealthCheckOutcome failEquals(
    String reasonCode,
    RecordHealthCheckValue found,
    RecordHealthCheckValue expected
  ) {
    return equalityOutcome(
      RecordHealthCheckStatus.FAIL,
      reasonCode,
      found,
      expected
    );
  }

  /** Builds the standard PASS outcome for an empty item collection. */
  global static RecordHealthCheckOutcome noneFound(String reasonCode) {
    return passEquals(
      reasonCode,
      RecordHealthCheckValue.ofList(new List<String>()),
      RecordHealthCheckValue.ofList(new List<String>())
    );
  }

  /** Builds the standard FAIL outcome for a nonempty item collection. */
  global static RecordHealthCheckOutcome itemsFound(
    String reasonCode,
    List<String> items
  ) {
    if (items == null || items.isEmpty()) {
      throw new RecordHealthCheckOutcomeBuilderException(
        'INVALID_BUILDER_VALUES'
      );
    }
    return failEquals(
      reasonCode,
      RecordHealthCheckValue.ofList(items),
      RecordHealthCheckValue.ofList(new List<String>())
    );
  }

  /** Invokes one preloaded per-record evaluator exactly once. */
  global static RecordHealthCheckOutcome tryEvaluate(
    Id recordId,
    RecordHealthCheckRecordEvaluator evaluator
  ) {
    if (recordId == null || evaluator == null) {
      throw new RecordHealthCheckOutcomeBuilderException(
        'INVALID_RECORD_EVALUATOR'
      );
    }
    RecordHealthCheckOutcome outcome;
    try {
      outcome = evaluator.evaluateRecord(recordId);
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (Exception ex) {
      if (
        ex instanceof RecordHealthCheckFatalFailure ||
        ex instanceof System.NoAccessException
      ) {
        throw ex;
      }
      return unableToEvaluate('RECORD_EVALUATION_FAILED');
    }
    return outcome == null
      ? unableToEvaluate('RECORD_RESULT_MISSING')
      : outcome;
  }

  private static RecordHealthCheckOutcome equalityOutcome(
    String status,
    String reasonCode,
    RecordHealthCheckValue found,
    RecordHealthCheckValue expected
  ) {
    if (String.isBlank(reasonCode) || reasonCode.length() > 80) {
      throw new RecordHealthCheckOutcomeBuilderException(
        'INVALID_BUILDER_REASON'
      );
    }
    if (!compatibleValues(found, expected)) {
      throw new RecordHealthCheckOutcomeBuilderException(
        'INVALID_BUILDER_VALUES'
      );
    }
    Boolean equal = valuesEqual(found, expected);
    if (
      (status == RecordHealthCheckStatus.PASS && !equal) ||
      (status == RecordHealthCheckStatus.FAIL && equal)
    ) {
      throw new RecordHealthCheckOutcomeBuilderException(
        'BUILDER_VERDICT_MISMATCH'
      );
    }
    RecordHealthCheckOutcome outcome = new RecordHealthCheckOutcome(
        status,
        reasonCode
      )
      .withFound(found)
      .withComparison('EQUALS', expected);
    if (!RecordHealthCheckOutcomeValidator.validate(outcome).isEmpty()) {
      throw new RecordHealthCheckOutcomeBuilderException(
        'INVALID_BUILDER_VALUES'
      );
    }
    return outcome;
  }

  private static Boolean compatibleValues(
    RecordHealthCheckValue found,
    RecordHealthCheckValue expected
  ) {
    if (
      found == null ||
      expected == null ||
      String.isBlank(found.dataType) ||
      found.dataType != expected.dataType
    ) {
      return false;
    }
    return found.isList() ||
      (found.storedValue != null &&
      expected.storedValue != null);
  }

  private static Boolean valuesEqual(
    RecordHealthCheckValue found,
    RecordHealthCheckValue expected
  ) {
    if (!found.isList()) {
      return found.storedValue == expected.storedValue;
    }
    List<String> foundItems = found.storedValues;
    List<String> expectedItems = expected.storedValues;
    if (foundItems.size() != expectedItems.size()) {
      return false;
    }
    for (Integer index = 0; index < foundItems.size(); index++) {
      if (foundItems[index] != expectedItems[index]) {
        return false;
      }
    }
    return true;
  }

  /**
   * The check ran correctly but could not reach a verdict: data, access, or
   * runtime conditions rather than a defect. Distinct from ERROR, which the
   * engine reserves for a broken plugin contract.
   */
  global static RecordHealthCheckOutcome unableToEvaluate(String reasonCode) {
    return new RecordHealthCheckOutcome(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      reasonCode
    );
  }

  /** @return A deliberately skipped plugin outcome. */
  global static RecordHealthCheckOutcome skipped(String reasonCode) {
    return new RecordHealthCheckOutcome(
      RecordHealthCheckStatus.SKIPPED,
      reasonCode
    );
  }

  /**
   * Reserved for the engine. A plugin reports UNABLE_TO_EVALUATE when it cannot
   * reach a verdict; ERROR means the contract itself was broken, which is the
   * engine's call to make, not the plugin's.
   */
  global static RecordHealthCheckOutcome error(String reasonCode) {
    return new RecordHealthCheckOutcome(
      RecordHealthCheckStatus.ERROR,
      reasonCode
    );
  }

  /** The value the record produced. */
  global RecordHealthCheckOutcome withFound(RecordHealthCheckValue found) {
    this.found = found;
    return this;
  }

  /**
   * The comparison this verdict rests on. Carried separately from the values
   * because a value alone is ambiguous: an Expected of 5 cannot distinguish
   * "equal to" from "greater than" from "at least". Null for checks that make
   * no comparison.
   */
  global RecordHealthCheckOutcome withComparison(
    String comparisonOperator,
    RecordHealthCheckValue expected
  ) {
    this.comparisonOperator = comparisonOperator;
    this.expected = expected;
    return this;
  }

  /** An Expected value with no operator, for checks that state a target without comparing. */
  global RecordHealthCheckOutcome withExpected(
    RecordHealthCheckValue expected
  ) {
    this.expected = expected;
    return this;
  }

  /** Attaches a detached snapshot of optional structured evidence. */
  global RecordHealthCheckOutcome withEvidence(
    RecordHealthCheckEvidence evidence
  ) {
    this.evidence = evidence?.snapshot();
    return this;
  }
}
