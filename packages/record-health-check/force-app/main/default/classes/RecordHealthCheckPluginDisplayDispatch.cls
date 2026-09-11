/** Guards, validates, and detaches the optional card presentation phase. */
public with sharing class RecordHealthCheckPluginDisplayDispatch {
  /** Recoverable optional-presentation contract failure. */
  public class DisplayException extends Exception {
    public String reasonCode;
  }

  public static Map<Id, RecordHealthCheckDisplayOverride> run(
    RecordHealthCheckPlugin plugin,
    RecordHealthCheckScope scope
  ) {
    RecordHealthCheckDisplayPlugin displayPlugin;
    try {
      displayPlugin = (RecordHealthCheckDisplayPlugin) plugin;
    } catch (TypeException ex) {
      return null;
    }
    RecordHealthCheckScope detached = new RecordHealthCheckScope(
      scope.objectApiName,
      scope.recordIds,
      scope.parameters,
      scope.checkDeveloperName,
      scope.checkSetDeveloperName,
      scope.runId,
      scope.checkQualifiedApiName,
      scope.checkSetQualifiedApiName
    );
    Savepoint before = Database.setSavepoint();
    Integer dmlBefore = Limits.getDmlStatements();
    Integer rowsBefore = Limits.getDmlRows();
    Integer calloutsBefore = Limits.getCallouts();
    Integer queueablesBefore = Limits.getQueueableJobs();
    Integer futuresBefore = Limits.getFutureCalls();
    Integer emailsBefore = Limits.getEmailInvocations();
    Integer queriesBefore = Limits.getQueries();
    Map<Id, RecordHealthCheckDisplayOverride> returned;
    Exception failure;
    try {
      returned = displayPlugin.getDisplay(detached);
    } catch (Exception ex) {
      failure = ex;
    } finally {
      String effect = changedEffect(
        dmlBefore,
        rowsBefore,
        calloutsBefore,
        queueablesBefore,
        futuresBefore,
        emailsBefore
      );
      if (effect != null) {
        Database.rollback(before);
        Database.releaseSavepoint(before);
        RecordHealthCheckPluginDispatch.SideEffectException violation = new RecordHealthCheckPluginDispatch.SideEffectException(
          'A health check must not change anything during display.'
        );
        violation.reasonCode = RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED;
        violation.effect = effect;
        violation.reversible = effect == 'DML' || effect == 'QUEUEABLE';
        throw violation;
      }
      Database.releaseSavepoint(before);
    }
    if (failure != null || Limits.getQueries() > queriesBefore) {
      throw displayFailure(
        Limits.getQueries() > queriesBefore
          ? 'PLUGIN_DISPLAY_QUERIED'
          : 'PLUGIN_DISPLAY_THREW',
        'Optional plugin display was rejected.'
      );
    }
    if (returned == null) {
      return null;
    }
    Set<Id> requested = new Set<Id>(scope.recordIds);
    for (Id key : returned.keySet()) {
      if (!requested.contains(key)) {
        throw displayFailure(
          'PLUGIN_DISPLAY_UNKNOWN_KEY',
          'Optional display named an unknown record.'
        );
      }
    }
    Map<Id, RecordHealthCheckDisplayOverride> copy = new Map<Id, RecordHealthCheckDisplayOverride>();
    for (Id recordId : scope.recordIds) {
      RecordHealthCheckDisplayOverride value = returned.get(recordId);
      copy.put(
        recordId,
        value == null ||
          value.found?.valid == false ||
          value.expected?.valid == false
          ? null
          : copyOverride(value)
      );
    }
    return copy;
  }

  private static String changedEffect(
    Integer dmlBefore,
    Integer rowsBefore,
    Integer calloutsBefore,
    Integer queueablesBefore,
    Integer futuresBefore,
    Integer emailsBefore
  ) {
    if (
      Limits.getDmlStatements() > dmlBefore ||
      Limits.getDmlRows() > rowsBefore
    ) {
      return 'DML';
    }
    if (Limits.getCallouts() > calloutsBefore) {
      return 'CALLOUT';
    }
    if (Limits.getQueueableJobs() > queueablesBefore) {
      return 'QUEUEABLE';
    }
    if (Limits.getFutureCalls() > futuresBefore) {
      return 'FUTURE';
    }
    return Limits.getEmailInvocations() > emailsBefore ? 'EMAIL' : null;
  }

  private static RecordHealthCheckDisplayOverride copyOverride(
    RecordHealthCheckDisplayOverride source
  ) {
    return new RecordHealthCheckDisplayOverride()
      .withFound(copyText(source.found))
      .withExpected(copyText(source.expected));
  }

  private static RecordHealthCheckDisplayText copyText(
    RecordHealthCheckDisplayText source
  ) {
    if (source == null) {
      return null;
    }
    RecordHealthCheckDisplayText copy = new RecordHealthCheckDisplayText();
    for (RecordHealthCheckDisplayNode node : source.copyNodes()) {
      if (node.kind == 'text') {
        copy.text(node.text);
      } else if (node.kind == 'link') {
        copy.link(node.text, node.href);
      } else if (node.kind == 'break') {
        copy.lineBreak();
      } else {
        copy.valid = false;
      }
    }
    return copy;
  }

  private static DisplayException displayFailure(
    String reasonCode,
    String message
  ) {
    DisplayException ex = new DisplayException(message);
    ex.reasonCode = reasonCode;
    return ex;
  }
}
