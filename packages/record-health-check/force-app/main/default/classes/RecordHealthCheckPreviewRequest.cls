/** Immutable detached-draft request for privileged validation and preview. */
global class RecordHealthCheckPreviewRequest {
  private static final Integer MAX_RECORDS = 200;
  private static final Integer MAX_REQUEST_BYTES = 1024 * 1024;
  private static final Set<String> IGNORED_QUERY_FIELDS = new Set<String>{
    'Record_Health_Check_Set__r',
    'SystemModstamp'
  };
  private static final Set<String> ALLOWED_FIELDS = new Set<String>{
    'Id',
    'DeveloperName',
    'QualifiedApiName',
    'NamespacePrefix',
    'Language',
    'MasterLabel',
    'Record_Health_Check_Set__c',
    'CheckTitle__c',
    'CheckDescription__c',
    'Category__c',
    'EvaluationOrder__c',
    'IsActive__c',
    'EvaluationType__c',
    'FailureSeverity__c',
    'PassConditionFormula__c',
    'DisplayFoundFormula__c',
    'DisplayExpectedFormula__c',
    'FindInListFormula__c',
    'FormulaResultType__c',
    'SourceQuery__c',
    'SourceQueryField__c',
    'ExpectedValueSource__c',
    'ExpectedFixedValue__c',
    'ExpectedCurrencyIsoCode__c',
    'ExpectedRecordFormula__c',
    'ComparisonQuery__c',
    'ComparisonQueryField__c',
    'ComparisonOperator__c',
    'QueryResultHandling__c',
    'NoRowsResult__c',
    'EmptyValueHandling__c',
    'DisplayFoundText__c',
    'DisplayExpectedText__c',
    'DisplayValueFormat__c',
    'FailureMessage__c',
    'UnableToEvaluateMessage__c',
    'ActionLabel__c',
    'ActionUrl__c',
    'FixMessage__c',
    'ApexClass__c',
    'ApexParametersJson__c',
    'MaxQueryRows__c',
    'PrerequisiteCheck__c',
    'ApplicabilityMode__c',
    'ApplicabilityFormula__c',
    'ApplicabilityNotMetMessage__c',
    'ApplicabilityCountQuery__c',
    'ApplicabilityCountOperator__c',
    'ApplicabilityCountThreshold__c',
    'ComparisonDisplayMode__c',
    'PublishUserResultEvent__c'
  };

  /** Qualified server-owned Check Set selected for this preview. */
  global String qualifiedSetName { get; private set; }
  /** VALIDATE_ONLY or EXECUTE. */
  global String mode { get; private set; }
  /** Whether a successful preview may persist a bounded readiness receipt. */
  global Boolean readinessReceiptRequested { get; private set; }
  private Record_Health_Check__mdt draftInternal;
  private List<Id> recordIdsInternal;

  /** Returns a defensive detached Check copy. */
  global Record_Health_Check__mdt draftCheck {
    get {
      return copyDraft(draftInternal);
    }
  }

  /** Returns stable-order unique record IDs. */
  global List<Id> recordIds {
    get {
      return new List<Id>(recordIdsInternal);
    }
  }

  private RecordHealthCheckPreviewRequest(
    Record_Health_Check__mdt draft,
    String setName,
    List<Id> ids,
    String selectedMode,
    Boolean receipt
  ) {
    draftInternal = copyDraft(draft);
    qualifiedSetName = RecordHealthCheckQualifiedIdentity.normalize(
      setName,
      'Check Set'
    );
    recordIdsInternal = dedupe(ids);
    mode = selectedMode;
    readinessReceiptRequested = receipt;
    enforceSize();
  }

  /** Creates a VALIDATE_ONLY request for one detached draft Check. */
  global static RecordHealthCheckPreviewRequest forDraftCheck(
    Record_Health_Check__mdt checkDraft,
    String qualifiedSetName,
    List<Id> recordIds
  ) {
    if (checkDraft == null) {
      throw new PreviewRequestException('A draft Check is required.');
    }
    return new RecordHealthCheckPreviewRequest(
      checkDraft,
      qualifiedSetName,
      recordIds == null ? new List<Id>() : recordIds,
      'VALIDATE_ONLY',
      false
    );
  }

  /** Returns a copied request in VALIDATE_ONLY or EXECUTE mode. */
  global RecordHealthCheckPreviewRequest withMode(String value) {
    if (value != 'VALIDATE_ONLY' && value != 'EXECUTE') {
      throw new PreviewRequestException(
        'Mode must be VALIDATE_ONLY or EXECUTE.'
      );
    }
    return new RecordHealthCheckPreviewRequest(
      draftInternal,
      qualifiedSetName,
      recordIdsInternal,
      value,
      readinessReceiptRequested
    );
  }

  /** Returns a copied request with explicit receipt persistence intent. */
  global RecordHealthCheckPreviewRequest withReadinessReceipt(Boolean value) {
    return new RecordHealthCheckPreviewRequest(
      draftInternal,
      qualifiedSetName,
      recordIdsInternal,
      mode,
      value == true
    );
  }

  private static Record_Health_Check__mdt copyDraft(
    Record_Health_Check__mdt source
  ) {
    Record_Health_Check__mdt copy = new Record_Health_Check__mdt();
    for (String field : source.getPopulatedFieldsAsMap().keySet()) {
      String localField = localFieldName(field);
      if (IGNORED_QUERY_FIELDS.contains(localField)) {
        continue;
      }
      if (localField == 'Label') {
        localField = 'MasterLabel';
      }
      if (!ALLOWED_FIELDS.contains(localField)) {
        throw new PreviewRequestException(
          'Unsupported draft field: ' + field + '.'
        );
      }
      copy.put(
        localField == 'MasterLabel' ? 'MasterLabel' : field,
        source.get(field)
      );
    }
    return copy;
  }

  private static String localFieldName(String fieldName) {
    if (ALLOWED_FIELDS.contains(fieldName)) {
      return fieldName;
    }
    String localObjectName = 'Record_Health_Check__mdt';
    String objectName = Record_Health_Check__mdt.SObjectType.getDescribe(
        SObjectDescribeOptions.DEFERRED
      )
      .getName();
    if (!objectName.endsWith(localObjectName)) {
      return fieldName;
    }
    String namespacePrefix = objectName.substring(
      0,
      objectName.length() - localObjectName.length()
    );
    return String.isNotBlank(namespacePrefix) &&
      namespacePrefix.endsWith('__') &&
      fieldName.startsWith(namespacePrefix)
      ? fieldName.substring(namespacePrefix.length())
      : fieldName;
  }

  private static List<Id> dedupe(List<Id> ids) {
    List<Id> ordered = new List<Id>();
    Set<Id> seen = new Set<Id>();
    for (Id recordId : ids) {
      if (recordId != null && seen.add(recordId)) {
        ordered.add(recordId);
      }
    }
    if (ordered.size() > MAX_RECORDS) {
      throw new PreviewRequestException(
        'Preview accepts at most 200 unique record IDs.'
      );
    }
    return ordered;
  }

  private void enforceSize() {
    if (
      Blob.valueOf(
          JSON.serialize(
            new Map<String, Object>{
              'draft' => draftInternal,
              'set' => qualifiedSetName,
              'recordIds' => recordIdsInternal,
              'mode' => mode,
              'receipt' => readinessReceiptRequested
            }
          )
        )
        .size() > MAX_REQUEST_BYTES
    ) {
      throw new PreviewRequestException(
        'Canonical preview request exceeds 1 MiB.'
      );
    }
  }

  /** Invalid detached preview request. */
  global class PreviewRequestException extends Exception {
  }
}
