/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Invokes a custom Apex Rule and holds it to its contract.
 *
 * Every guarantee the extension boundary makes is enforced here, in one place,
 * so there is no second path a caller could use to reach a plugin without them.
 * Consumers must never instantiate a plugin directly: doing so would bypass
 * scope construction, the write check that blocks DML, callouts, email, events,
 * and async work, completeness validation, and identity stamping all at once.
 *
 * Two behaviors are worth reading closely, because both are easy to get subtly
 * wrong and neither is recoverable afterwards.
 *
 * 1. The write check runs in a `finally`, so it also runs when the plugin
 *    throws. A plugin that performs DML and then throws would otherwise have its
 *    exception converted into ordinary ERROR rows, and those rows would commit
 *    along with the mutation the framework promises never to make.
 *
 * 2. A detected forbidden write outranks every other outcome, including an
 *    exception, and is rethrown rather than converted. Nothing downstream may
 *    catch it and turn it into results, because the only way to undo the
 *    mutation is to let the transaction die.
 */
public with sharing class RecordHealthCheckPluginDispatch {
  /**
   * Prohibited effects, with the counter that detects each. Where Apex exposes
   * no reliable counter (batch and scheduled dispatch, event publication) the
   * obligation moves to static analysis and the contract test, and the
   * report does not pretend otherwise.
   */
  public class SideEffectException extends Exception {
    public String reasonCode;
    public String effect;
    public Boolean reversible;
  }

  public class ContractException extends Exception {
    public String reasonCode;
  }

  /**
   * Constructs a plugin inside the same counter-and-savepoint fence used for
   * evaluation. Constructors are executable Apex and therefore part of the
   * extension boundary, not configuration-only reflection.
   */
  public static RecordHealthCheckRule instantiate(Type pluginType) {
    if (pluginType == null) {
      return null;
    }
    Savepoint before = Database.setSavepoint();
    Integer dmlBefore = Limits.getDmlStatements();
    Integer dmlRowsBefore = Limits.getDmlRows();
    Integer calloutsBefore = Limits.getCallouts();
    Integer queueableBefore = Limits.getQueueableJobs();
    Integer futureBefore = Limits.getFutureCalls();
    Integer emailBefore = Limits.getEmailInvocations();
    Object instance;
    Exception constructionFailure;
    try {
      instance = pluginType.newInstance();
    } catch (Exception ex) {
      constructionFailure = ex;
    } finally {
      SideEffectException violation = detect(
        dmlBefore,
        dmlRowsBefore,
        calloutsBefore,
        queueableBefore,
        futureBefore,
        emailBefore
      );
      if (violation != null) {
        Database.rollback(before);
        Database.releaseSavepoint(before);
        throw violation;
      }
      Database.releaseSavepoint(before);
    }
    if (constructionFailure != null) {
      throw constructionFailure;
    }
    return instance instanceof RecordHealthCheckRule
      ? (RecordHealthCheckRule) instance
      : null;
  }

  /**
   * Runs one plugin against one scope and returns an outcome per record Id.
   *
   * @throws SideEffectException when the plugin mutated state. Fatal by design:
   *         the caller must let it propagate so the transaction rolls back.
   */
  public static Map<Id, RecordHealthCheckOutcome> run(
    RecordHealthCheckRule plugin,
    RecordHealthCheckScope scope
  ) {
    // Taken BEFORE the counters are captured, because setting a savepoint is
    // itself a DML statement and would otherwise look like the very violation
    // this exists to undo.
    //
    // Throwing alone does not undo a mutation. Apex rolls back only when an
    // exception escapes the entire transaction, so any caller with a catch
    // block anywhere above this frame would leave the plugin's DML committed
    // while the run reported a tidy failure. The savepoint makes the rollback
    // ours to perform rather than something we hope the stack allows.
    //
    // Deliberately one per invocation rather than one shared across the
    // transaction. Each boundary releases its savepoint as soon as the plugin
    // returns, so sequential Rules do not accumulate active savepoints.
    //
    // A shared savepoint was tried and is wrong: rolling back to the first
    // savepoint of the transaction undoes everything since, not just the
    // offending check. A scan would lose the records it had already written,
    // and the framework would cause more damage cleaning up than the check did.
    // Rollback has to reach exactly as far as this one call and no further.
    Savepoint before = Database.setSavepoint();

    Integer dmlBefore = Limits.getDmlStatements();
    Integer dmlRowsBefore = Limits.getDmlRows();
    Integer calloutsBefore = Limits.getCallouts();
    Integer queueableBefore = Limits.getQueueableJobs();
    Integer futureBefore = Limits.getFutureCalls();
    Integer emailBefore = Limits.getEmailInvocations();

    Map<Id, RecordHealthCheckOutcome> returned;
    Exception pluginFailure;

    try {
      returned = plugin.evaluate(scope);
    } catch (Exception ex) {
      // Held, not handled. The fence below decides whether this exception is
      // the real story or merely the exit route from a plugin that already
      // mutated something.
      pluginFailure = ex;
    } finally {
      SideEffectException violation = detect(
        dmlBefore,
        dmlRowsBefore,
        calloutsBefore,
        queueableBefore,
        futureBefore,
        emailBefore
      );
      if (violation != null) {
        // Undo what can be undone before anything else runs. A callout or an
        // email has already left and the rollback cannot reach it, which is why
        // the exception carries `reversible` rather than claiming success.
        Database.rollback(before);
        Database.releaseSavepoint(before);
        // Deliberately thrown from `finally`: it replaces any in-flight
        // exception, which is exactly the precedence the contract requires.
        throw violation;
      }
      Database.releaseSavepoint(before);
    }

    if (pluginFailure != null) {
      // No prohibited effect, so the throw is attributable to the rule and can
      // safely become results. The engine cannot tell WHICH record caused it,
      // so the whole scope is affected; only the plugin can isolate per record.
      throw newContractException(
        RecordHealthCheckReasonCodes.PLUGIN_THREW,
        'The check threw an unhandled exception: ' + pluginFailure.getMessage()
      );
    }

    return validate(returned, scope);
  }

  /**
   * Compares resource counters captured around the call. A nonzero delta is a
   * contract violation regardless of intent.
   */
  @TestVisible
  private static SideEffectException detect(
    Integer dmlBefore,
    Integer dmlRowsBefore,
    Integer calloutsBefore,
    Integer queueableBefore,
    Integer futureBefore,
    Integer emailBefore
  ) {
    if (
      Limits.getDmlStatements() > dmlBefore ||
      Limits.getDmlRows() > dmlRowsBefore
    ) {
      return newSideEffect('DML', true, 'performed DML on a record');
    }
    if (Limits.getCallouts() > calloutsBefore) {
      // Already sent. Failing the run cannot unsend it, and the message says so.
      return newSideEffect('CALLOUT', false, 'made an HTTP callout');
    }
    if (Limits.getQueueableJobs() > queueableBefore) {
      return newSideEffect('QUEUEABLE', true, 'enqueued a Queueable job');
    }
    if (Limits.getFutureCalls() > futureBefore) {
      return newSideEffect('FUTURE', true, 'called a future method');
    }
    if (Limits.getEmailInvocations() > emailBefore) {
      return newSideEffect('EMAIL', false, 'sent email');
    }
    return null;
  }

  private static SideEffectException newSideEffect(
    String effect,
    Boolean reversible,
    String description
  ) {
    SideEffectException ex = new SideEffectException(
      'A health check must not change anything. This one ' +
        description +
        ', so the run was stopped' +
        (reversible
          ? ' and the change was rolled back.'
          : '. That effect cannot be undone.')
    );
    ex.reasonCode = RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED;
    ex.effect = effect;
    ex.reversible = reversible;
    return ex;
  }

  /**
   * Completeness, split by whose fault it is.
   *
   * A missing key is one record's ERROR. An unrecognized key fails the Rule for
   * the entire scope: a malformed response is not partially trustworthy, and a
   * plugin confused about which records it was handed is not one whose other
   * answers should be believed. That trade is deliberately fail-closed, so one
   * stray key can invalidate two hundred results.
   */
  private static Map<Id, RecordHealthCheckOutcome> validate(
    Map<Id, RecordHealthCheckOutcome> returned,
    RecordHealthCheckScope scope
  ) {
    List<Id> requested = scope.recordIds;
    Set<Id> requestedSet = new Set<Id>(requested);

    if (returned == null) {
      throw newContractException(
        RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING,
        'The check returned nothing instead of a result for each record.'
      );
    }

    for (Id returnedId : returned.keySet()) {
      if (!requestedSet.contains(returnedId)) {
        throw newContractException(
          RecordHealthCheckReasonCodes.PLUGIN_RESULT_UNKNOWN_KEY,
          'The check returned a result for a record it was not asked about.'
        );
      }
    }

    Map<Id, RecordHealthCheckOutcome> complete = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : requested) {
      RecordHealthCheckOutcome outcome = returned.get(recordId);
      complete.put(
        recordId,
        outcome == null
          ? RecordHealthCheckOutcome.error(
              RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING
            )
          : outcome
      );
    }
    return complete;
  }

  private static ContractException newContractException(
    String reasonCode,
    String message
  ) {
    ContractException ex = new ContractException(message);
    ex.reasonCode = reasonCode;
    return ex;
  }
}
