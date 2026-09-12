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
    RecordHealthCheckResourcePlan.requireFenceCapacity(0);
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
    return validateAndCopy(returned, scope);
  }

  private static Map<Id, RecordHealthCheckDisplayOverride> validateAndCopy(
    Map<Id, RecordHealthCheckDisplayOverride> returned,
    RecordHealthCheckScope scope
  ) {
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
    CopyBudget budget = new CopyBudget(returned, scope.recordIds);
    if (budget.exhausted) {
      return null;
    }
    for (Id recordId : scope.recordIds) {
      RecordHealthCheckDisplayOverride value = returned.get(recordId);
      copy.put(recordId, value == null ? null : copyOverride(value, budget));
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
    RecordHealthCheckDisplayOverride source,
    CopyBudget budget
  ) {
    Boolean alreadyExhausted = budget.exhausted;
    RecordHealthCheckDisplayOverride copy = new RecordHealthCheckDisplayOverride()
      .withMessage(copyText(source.message, budget))
      .withFix(copyText(source.fix, budget))
      .withFound(copyText(source.found, budget))
      .withExpected(copyText(source.expected, budget));
    copyMetadata(source, copy, budget);
    markInvalid(copy, source.found, 'found');
    markInvalid(copy, source.expected, 'expected');
    markInvalid(copy, source.message, 'message');
    markInvalid(copy, source.fix, 'fix');
    if (!alreadyExhausted && budget.exhausted) {
      copy.invalidFields.add('displayBudget');
    }
    return copy;
  }

  private static void copyMetadata(
    RecordHealthCheckDisplayOverride source,
    RecordHealthCheckDisplayOverride target,
    CopyBudget budget
  ) {
    RecordHealthCheckDisplayOverride metadata = new RecordHealthCheckDisplayOverride()
      .withAction(source.action)
      .withExpectedLabel(source.expectedLabel)
      .withFoundFormat(source.foundFormat, source.foundCurrencyIsoCode)
      .withExpectedFormat(
        source.expectedFormat,
        source.expectedCurrencyIsoCode
      );
    if (!budget.acceptMetadata(metadata)) {
      return;
    }
    target.withAction(copyAction(metadata.action))
      .withExpectedLabel(metadata.expectedLabel)
      .withFoundFormat(metadata.foundFormat, metadata.foundCurrencyIsoCode)
      .withExpectedFormat(
        metadata.expectedFormat,
        metadata.expectedCurrencyIsoCode
      );
  }

  private static void markInvalid(
    RecordHealthCheckDisplayOverride target,
    RecordHealthCheckDisplayText source,
    String fieldName
  ) {
    if (source?.valid == false) {
      target.invalidFields.add(fieldName);
    }
  }

  private static RecordHealthCheckDisplayAction copyAction(
    RecordHealthCheckDisplayAction source
  ) {
    return source == null
      ? null
      : new RecordHealthCheckDisplayAction(source.label, source.destination);
  }

  private static RecordHealthCheckDisplayText copyText(
    RecordHealthCheckDisplayText source,
    CopyBudget budget
  ) {
    if (source == null || source.valid == false || source.nodeCount() == 0) {
      return null;
    }
    if (!budget.accept(Blob.valueOf(JSON.serialize(source)).size() - 4)) {
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

  private class CopyBudget {
    private Integer usedBytes;
    private Integer emptyOverrideBytes;
    public Boolean exhausted = false;

    public CopyBudget(
      Map<Id, RecordHealthCheckDisplayOverride> returned,
      List<Id> recordIds
    ) {
      RecordHealthCheckDisplayOverride empty = new RecordHealthCheckDisplayOverride();
      emptyOverrideBytes = Blob.valueOf(JSON.serialize(empty)).size();
      Map<Id, RecordHealthCheckDisplayOverride> baseline = new Map<Id, RecordHealthCheckDisplayOverride>();
      for (Id recordId : recordIds) {
        baseline.put(recordId, returned.get(recordId) == null ? null : empty);
      }
      usedBytes = Blob.valueOf(JSON.serialize(baseline)).size();
      exhausted = usedBytes > 256 * 1024;
    }

    public Boolean acceptMetadata(RecordHealthCheckDisplayOverride metadata) {
      if (exhausted) {
        return false;
      }
      Integer minimumBytes = 0;
      for (
        String value : new List<String>{
          metadata.expectedLabel,
          metadata.foundFormat,
          metadata.foundCurrencyIsoCode,
          metadata.expectedFormat,
          metadata.expectedCurrencyIsoCode,
          metadata.action?.label,
          metadata.action?.destination
        }
      ) {
        minimumBytes += value == null ? 0 : value.length();
      }
      // Null placeholders can shrink when replaced by short strings; their
      // total baseline is bounded. Reject huge strings before serializing them.
      if (minimumBytes > 256 * 1024 - usedBytes + emptyOverrideBytes) {
        exhausted = true;
        return false;
      }
      return accept(
        Blob.valueOf(JSON.serialize(metadata)).size() - emptyOverrideBytes
      );
    }

    public Boolean accept(Integer candidateBytes) {
      if (exhausted) {
        return false;
      }
      if (usedBytes + candidateBytes > 256 * 1024) {
        exhausted = true;
        return false;
      }
      usedBytes += candidateBytes;
      return true;
    }
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
