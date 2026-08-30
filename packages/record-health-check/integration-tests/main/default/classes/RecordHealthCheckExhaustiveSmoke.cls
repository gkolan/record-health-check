/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Test-only scratch-org harness that runs each Check Set or Check separately. */
public class RecordHealthCheckExhaustiveSmoke implements Queueable {
  private Id recordId;
  private String itemName;
  private String mode;

  public static List<Id> startSets(Id recordId) {
    List<Id> jobs = new List<Id>();
    for (Record_Health_Check_Set__mdt item : [
      SELECT QualifiedApiName
      FROM Record_Health_Check_Set__mdt
      ORDER BY DeveloperName
      LIMIT 50000
    ]) {
      // code-analyzer-suppress-next-line OperationWithLimitsInLoop: Queueable Apex exposes only a single-job enqueue API; this scratch-org harness is bounded by the platform's 50-job transaction limit.
      jobs.add(
        System.enqueueJob(
          new RecordHealthCheckExhaustiveSmoke(
            recordId,
            item.QualifiedApiName,
            'SET'
          )
        )
      );
    }
    return jobs;
  }

  public static List<Id> startChecks(Id recordId, Integer batchOffset) {
    List<Id> jobs = new List<Id>();
    Map<String, Id> recordIdsByObject = fixtureRecordIds(recordId);
    for (Record_Health_Check__mdt item : [
      SELECT QualifiedApiName, Record_Health_Check_Set__r.ObjectApiName__c
      FROM Record_Health_Check__mdt
      ORDER BY DeveloperName
      LIMIT 50
      OFFSET :batchOffset
    ]) {
      String objectApiName = item.Record_Health_Check_Set__r.ObjectApiName__c;
      Id compatibleRecordId = recordIdsByObject.containsKey(objectApiName)
        ? recordIdsByObject.get(objectApiName)
        : recordId;
      // code-analyzer-suppress-next-line OperationWithLimitsInLoop: Queueable Apex exposes only a single-job enqueue API; this query caps the scratch-org harness at 50 jobs.
      jobs.add(
        System.enqueueJob(
          new RecordHealthCheckExhaustiveSmoke(
            compatibleRecordId,
            item.QualifiedApiName,
            'CHECK'
          )
        )
      );
    }
    return jobs;
  }

  private static Map<String, Id> fixtureRecordIds(Id accountId) {
    Map<String, Id> recordIds = new Map<String, Id>{ 'Account' => accountId };
    List<Contact> contacts = [
      SELECT Id
      FROM Contact
      WHERE AccountId = :accountId
      ORDER BY CreatedDate, Id
      LIMIT 1
    ];
    if (!contacts.isEmpty()) {
      recordIds.put('Contact', contacts[0].Id);
    }
    List<Opportunity> opportunities = [
      SELECT Id
      FROM Opportunity
      WHERE AccountId = :accountId
      ORDER BY CreatedDate, Id
      LIMIT 1
    ];
    if (!opportunities.isEmpty()) {
      recordIds.put('Opportunity', opportunities[0].Id);
    }
    return recordIds;
  }

  @TestVisible
  private RecordHealthCheckExhaustiveSmoke(
    Id recordId,
    String itemName,
    String mode
  ) {
    this.recordId = recordId;
    this.itemName = itemName;
    this.mode = mode;
  }

  public void execute(QueueableContext context) {
    // code-analyzer-suppress-next-line QueueableWithoutFinalizer: This one-shot scratch-org harness persists its outcome itself; no recovery or chained cleanup is required.
    Map<String, Object> outcome = new Map<String, Object>{
      'mode' => mode,
      'name' => itemName
    };
    try {
      if (mode == 'SET') {
        RecordHealthCheckResponse result = RecordHealthCheck.evaluate(
          RecordHealthCheckRequest.forCheckSet(itemName, recordId)
            .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
        );
        outcome.put('status', overallStatus(result.summary));
        outcome.put('passed', result.summary.passed);
        outcome.put('failed', result.summary.failed);
        outcome.put('skipped', result.summary.skipped);
        outcome.put('unable', result.summary.unable);
        outcome.put('systemErrors', result.summary.systemError);
        outcome.put('results', summarize(result.results));
      } else {
        RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
          RecordHealthCheckRequest.forCheck(itemName, recordId)
            .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
        );
        RecordHealthCheckResultItem result = response.results[0];
        outcome.put('status', result.evaluation.status);
        outcome.put('reasonCode', result.evaluation.reasonCode);
        outcome.put(
          'message',
          result.display == null ? null : result.display.renderedMessage
        );
      }
    } catch (Exception ex) {
      outcome.put('threw', true);
      outcome.put('exceptionType', ex.getTypeName());
      outcome.put('exceptionMessage', ex.getMessage());
      outcome.put('stackTrace', ex.getStackTraceString());
    }
    upsert new RHC_Event_Export__c(
      EventId__c = mode + ':' + itemName,
      CheckName__c = itemName,
      Status__c = (String) outcome.get('status'),
      ReasonCode__c = (String) outcome.get('reasonCode'),
      Threw__c = outcome.get('threw') == true,
      ExceptionType__c = (String) outcome.get('exceptionType'),
      Payload__c = JSON.serialize(outcome)
    )
      RHC_Event_Export__c.EventId__c;
  }

  @TestVisible
  private static List<Object> summarize(
    List<RecordHealthCheckResultItem> results
  ) {
    List<Object> summary = new List<Object>();
    for (RecordHealthCheckResultItem result : results) {
      summary.add(
        new Map<String, Object>{
          'name' => result.evaluation.checkQualifiedApiName,
          'status' => result.evaluation.status,
          'reasonCode' => result.evaluation.reasonCode,
          'message' => result.display == null
            ? null
            : result.display.renderedMessage
        }
      );
    }
    return summary;
  }

  @TestVisible
  private static String overallStatus(RecordHealthCheckRunSummary summary) {
    if (summary.systemError > 0) {
      return 'ERROR';
    }
    if (summary.unable > 0) {
      return 'UNABLE_TO_EVALUATE';
    }
    if (summary.failed > 0) {
      return 'FAIL';
    }
    if (summary.passed > 0) {
      return 'PASS';
    }
    return 'SKIPPED';
  }

  public static void report() {
    List<RHC_Event_Export__c> rows = [
      SELECT EventId__c, Payload__c
      FROM RHC_Event_Export__c
      WHERE EventId__c LIKE 'SET:%' OR EventId__c LIKE 'CHECK:%'
      ORDER BY EventId__c
    ];
    Integer concerningRows = 0;
    for (RHC_Event_Export__c row : rows) {
      Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
        row.Payload__c
      );
      Boolean concerning =
        payload.get('threw') == true ||
        payload.get('status') == 'ERROR' ||
        payload.get('status') == 'UNABLE_TO_EVALUATE';
      if (concerning) {
        concerningRows++;
        System.debug(
          LoggingLevel.ERROR,
          'RHC_EXHAUSTIVE_RESULT=' + row.EventId__c + '|' + row.Payload__c
        );
      }
    }
    System.debug(LoggingLevel.ERROR, 'RHC_EXHAUSTIVE_ROWS=' + rows.size());
    System.debug(
      LoggingLevel.ERROR,
      'RHC_EXHAUSTIVE_CONCERNING_ROWS=' + concerningRows
    );
  }
}
