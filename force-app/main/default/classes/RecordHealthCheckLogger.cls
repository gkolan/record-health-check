/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Single logging API for the Record Health Check framework.
 * EVERY framework log line flows through this class. The engine, controller, and
 * evaluators never call System.debug directly — they call this logger — so the
 * destination can be changed in exactly one place. To adopt Nebula
 * Logger (or any other logging framework) later, replace the body of `emit`
 * with the equivalent Nebula calls; no other class needs to change.
 * Two things make a line useful for debugging:
 * - runId — a correlation id generated once per page load / run in the LWC and
 * threaded through every Apex call, so an admin can filter a debug
 * log down to a single user interaction.
 * - user — captured automatically from UserInfo.getUserId(), so every line is
 * attributable to the running user without any caller passing it in.
 * This is trusted server-side (it cannot be spoofed by the client) and means
 * "show me everything that happened for user X" is a simple log filter.
 */
public with sharing class RecordHealthCheckLogger {
  /**
   * Framework-level severity. Kept independent of System.LoggingLevel so the
   * destination can map it however the target framework expects. DEBUG maps to FINE.
   */
  public enum Level {
    ERROR,
    WARN,
    INFO,
    DEBUG
  }

  private static final String PREFIX = '[RHC]';

  // ─── Platform-event ERROR destination ───────────────────────────────────────
  // System.debug is ephemeral and usually off in production, so a check that
  // errors would otherwise leave no trace. ERROR lines are ALSO held as
  // Record_Health_Check_Log__e events and published once at the transaction
  // boundary via flush() — the counterpart to Nebula's saveLog(). Framework only
  // publishes the versioned event; the extension package owns persistence, retention,
  // and reporting. Holding events (not per-line publish) keeps a 200-record bulk run
  // that errors on every record to one chunked publish, well under DML limits.
  private static final String LOG_CONTRACT_VERSION = '1.0';
  private static final Integer PUBLISH_CHUNK_SIZE = 100;
  private static final Integer MESSAGE_MAX = 4000;
  private static final Integer STACK_MAX = 32000;

  @TestVisible
  private static RecordHealthCheckSettingsProvider settingsProvider = new RecordHealthCheckSettingsProvider();
  // Loop guard: a subscriber processing a log event sets this so its own ERROR
  // logging cannot republish onto the same bus.
  private static Boolean inSubscriberContext = false;
  private static Boolean debugEnabled = false;
  // Held ERROR events for the current transaction, awaiting flush().
  private static final List<Record_Health_Check_Log__e> PENDING_EVENTS = new List<Record_Health_Check_Log__e>();

  // Correlation keys carried for the life of one evaluate()/load call so that
  // individual log statements stay terse.
  private final String runId;
  private final String checkSetDeveloperName;
  private final String recordId;

  public RecordHealthCheckLogger(
    String runId,
    String checkSetDeveloperName,
    Id recordId
  ) {
    this.runId = sanitize(String.isBlank(runId) ? 'no-run-id' : runId, 120);
    this.checkSetDeveloperName = sanitize(checkSetDeveloperName, 120);
    this.recordId = recordId == null ? null : String.valueOf(recordId);
  }

  // ─── Instance API (used by the engine, which holds a context) ──────────────

  public void error(
    String checkName,
    String event,
    Map<String, Object> fields,
    Exception ex
  ) {
    emit(Level.ERROR, checkName, event, fields, ex);
  }

  public void warn(String checkName, String event, Map<String, Object> fields) {
    emit(Level.WARN, checkName, event, fields, null);
  }

  public void info(String checkName, String event, Map<String, Object> fields) {
    emit(Level.INFO, checkName, event, fields, null);
  }

  public void debug(
    String checkName,
    String event,
    Map<String, Object> fields
  ) {
    emit(Level.DEBUG, checkName, event, fields, null);
  }

  // ─── Static API (used at boundaries that don't hold a context instance) ────

  public static void log(
    Level lvl,
    String runId,
    String checkSetDeveloperName,
    Id recordId,
    String checkName,
    String event,
    Map<String, Object> fields,
    Exception ex
  ) {
    new RecordHealthCheckLogger(runId, checkSetDeveloperName, recordId)
      .emit(lvl, checkName, event, fields, ex);
  }

  // ─── Destination ───────────────────────────────────────────────────────────

  private void emit(
    Level lvl,
    String checkName,
    String event,
    Map<String, Object> fields,
    Exception ex
  ) {
    if (lvl == Level.DEBUG && !debugEnabled) {
      return;
    }
    String line = render(lvl, checkName, event, fields, ex);

    // The ONE place that decides where framework logs go. To switch to Nebula
    // Logger, replace this switch with (roughly)
    // Logger.newEntry(toSystemLevel(lvl), line);
    // // Logger.saveLog() is then called once at the transaction boundary
    // // (controller) so async work is not flushed mid-evaluation.
    switch on lvl {
      when ERROR {
        System.debug(LoggingLevel.ERROR, line);
      }
      when WARN {
        System.debug(LoggingLevel.WARN, line);
      }
      when INFO {
        System.debug(LoggingLevel.INFO, line);
      }
      when DEBUG {
        System.debug(LoggingLevel.FINE, line);
      }
    }

    captureErrorEvent(lvl, checkName, event, fields, ex);
  }

  // ─── Platform-event ERROR destination ────────────────────────────────────────

  /**
   * Buffers an ERROR line as a Record_Health_Check_Log__e event. No-op for
   * non-ERROR levels, when the feature is switched off, or inside a subscriber
   * context (loop guard). RecordId__c and the check context are included so a
   * failing evaluator is reproducible; field values (actual/expected) are
   * deliberately NOT carried — those stay in Debug Mode's admin detail.
   */
  private void captureErrorEvent(
    Level lvl,
    String checkName,
    String event,
    Map<String, Object> fields,
    Exception ex
  ) {
    if (
      lvl != Level.ERROR ||
      !isErrorEventPublicationEnabled() ||
      inSubscriberContext
    ) {
      return;
    }
    PENDING_EVENTS.add(
      new Record_Health_Check_Log__e(
        ContractVersion__c = LOG_CONTRACT_VERSION,
        EventId__c = newEventId(event),
        RunId__c = runId,
        OccurredAt__c = System.now(),
        FrameworkVersion__c = RecordHealthCheckLifecyclePublisher.FRAMEWORK_VERSION,
        Level__c = lvl.name(),
        Code__c = sanitize(event, 120),
        CheckSetDeveloperName__c = checkSetDeveloperName,
        RuleDeveloperName__c = sanitize(checkName, 120),
        RecordId__c = recordId,
        ExceptionType__c = ex == null ? null : sanitize(ex.getTypeName(), 120),
        Message__c = buildMessage(fields, ex),
        StackTrace__c = ex == null
          ? null
          : sanitize(ex.getStackTraceString(), STACK_MAX),
        UserId__c = UserInfo.getUserId()
      )
    );
  }

  /**
   * Returns whether the current Check Set permits ERROR log-event publication.
   * Missing or unresolved Check Set configuration remains enabled so failures
   * that occur before valid configuration is available are still observable.
   */
  private Boolean isErrorEventPublicationEnabled() {
    return settingsProvider.isErrorEventPublicationEnabled(
      checkSetDeveloperName
    );
  }

  /** Prefers the exception message; otherwise a compact, sorted field summary. */
  private String buildMessage(Map<String, Object> fields, Exception ex) {
    if (ex != null) {
      return sanitize(ex.getMessage(), MESSAGE_MAX);
    }
    if (fields == null || fields.isEmpty()) {
      return null;
    }
    List<String> keys = new List<String>(fields.keySet());
    keys.sort();
    List<String> parts = new List<String>();
    for (String k : keys) {
      parts.add(
        sanitize(k, 80) + '=' + sanitize(String.valueOf(fields.get(k)), 500)
      );
    }
    return sanitize(String.join(parts, ' '), MESSAGE_MAX);
  }

  private String newEventId(String code) {
    return runId.left(50) + '-' + sanitize(code, 20) + '-' + randomSuffix();
  }

  private static String randomSuffix() {
    return String.valueOf(Crypto.getRandomInteger()).replace('-', '').left(8);
  }

  /**
   * Publishes held ERROR events (chunked) and clears the buffer. Call once at
   * every transaction boundary — the controller @AuraEnabled methods, the public
   * RecordHealthCheck API, and Flow invocables. Best-effort and exception-safe:
   * a publish failure is logged and swallowed so platform-event logging can never
   * disrupt the health check result.
   */
  public static void flush() {
    if (PENDING_EVENTS.isEmpty()) {
      return;
    }
    List<Record_Health_Check_Log__e> toPublish = PENDING_EVENTS.clone();
    PENDING_EVENTS.clear();
    try {
      for (
        Integer start = 0; start < toPublish.size(); start += PUBLISH_CHUNK_SIZE
      ) {
        Integer finish = Math.min(start + PUBLISH_CHUNK_SIZE, toPublish.size());
        List<Record_Health_Check_Log__e> chunk = new List<Record_Health_Check_Log__e>();
        for (Integer i = start; i < finish; i++) {
          chunk.add(toPublish[i]);
        }
        inspectPublish(EventBus.publish(chunk));
      }
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.WARN,
        PREFIX +
          ' WARN LOG_EVENT_FLUSH_FAILED | ' +
          ex.getTypeName() +
          ': ' +
          ex.getMessage()
      );
    }
  }

  /**
   * Subscribers processing Record_Health_Check_Log__e MUST call this first so an
   * error raised while handling a log event does not republish onto the same bus.
   */
  public static void enterSubscriberContext() {
    inSubscriberContext = true;
  }

  private static void inspectPublish(List<Database.SaveResult> results) {
    if (results == null) {
      return;
    }
    for (Database.SaveResult sr : results) {
      if (sr.isSuccess()) {
        continue;
      }
      System.debug(
        LoggingLevel.WARN,
        PREFIX +
          ' WARN LOG_EVENT_PUBLISH_FAILED | errors=' +
          sr.getErrors().size()
      );
    }
  }

  @TestVisible
  private static Integer pendingEventCount() {
    return PENDING_EVENTS.size();
  }

  @TestVisible
  private static List<Record_Health_Check_Log__e> pendingEventsForTest() {
    debugEnabled = true;
    return PENDING_EVENTS;
  }

  /**
   * Renders one structured, greppable line
   * [RHC] WARN METADATA_INVALID | runId=.. user=.. checkSet=.. rule=.. <fields>
   * Fields are sorted by key so output is deterministic regardless of map order.
   */
  private String render(
    Level lvl,
    String checkName,
    String event,
    Map<String, Object> fields,
    Exception ex
  ) {
    List<String> parts = new List<String>();
    parts.add('runId=' + runId);
    parts.add('user=' + UserInfo.getUserId());
    if (String.isNotBlank(checkSetDeveloperName)) {
      parts.add('checkSet=' + checkSetDeveloperName);
    }
    if (String.isNotBlank(checkName)) {
      parts.add('rule=' + sanitize(checkName, 120));
    }
    if (recordId != null) {
      parts.add('record=' + recordId);
    }
    if (fields != null && !fields.isEmpty()) {
      List<String> keys = new List<String>(fields.keySet());
      keys.sort();
      for (String k : keys) {
        parts.add(
          sanitize(k, 80) + '=' + sanitize(String.valueOf(fields.get(k)), 500)
        );
      }
    }

    String line =
      PREFIX +
      ' ' +
      lvl.name() +
      ' ' +
      sanitize(event, 120) +
      ' | ' +
      String.join(parts, ' ');

    if (ex != null) {
      line +=
        ' | ' +
        sanitize(ex.getTypeName(), 120) +
        ': ' +
        sanitize(ex.getMessage(), 1000) +
        ' stack=' +
        sanitize(ex.getStackTraceString(), 2000);
    }
    return line;
  }

  private static String sanitize(String value, Integer maxLength) {
    if (value == null) {
      return null;
    }
    String cleaned = value.replaceAll('[\\r\\n\\t]', ' ').trim();
    Integer effectiveMax = maxLength == null || maxLength < 1 ? 500 : maxLength;
    return cleaned.length() <= effectiveMax
      ? cleaned
      : cleaned.substring(0, effectiveMax);
  }

  /** Normalizes caller-supplied correlation/configuration identifiers. */
  public static String normalizeIdentifier(String value, Integer maxLength) {
    return sanitize(value, maxLength);
  }
}
