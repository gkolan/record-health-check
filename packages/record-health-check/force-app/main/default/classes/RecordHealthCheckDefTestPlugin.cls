/** Controlled provider plugin used only by subscriber definition tests. */
public with sharing class RecordHealthCheckDefTestPlugin implements RecordHealthCheckPlugin, RecordHealthCheckPluginDefinitionSource {
  public static Integer constructorCount = 0;
  public static Integer definitionCount = 0;
  public static Integer evaluateCount = 0;
  public static String mode;
  public static Id mutationAccountId;
  public static Map<String, Object> seenParameters;

  public RecordHealthCheckDefTestPlugin() {
    constructorCount++;
  }

  public RecordHealthCheckPluginDefinition getDefinition() {
    definitionCount++;
    if (mode == 'NULL_DEFINITION') {
      return null;
    }
    if (mode == 'THROW_DEFINITION') {
      throw new RecordHealthCheckPluginDefinition.DefinitionException(
        'Controlled definition failure.'
      );
    }
    if (mode == 'QUERY_DEFINITION') {
      List<Account> queriedAccounts = [
        SELECT Id
        FROM Account
        WITH USER_MODE
        LIMIT 1
      ];
      queriedAccounts.clear();
    }
    if (mode == 'DML_DEFINITION') {
      update RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Id' => mutationAccountId,
          'Name' => 'Forbidden definition mutation'
        }
      );
    }
    List<String> displayChoices = new List<String>{
      'nameId',
      'nameRule',
      'nameRuleStep',
      'nameCommaIds'
    };
    RecordHealthCheckPluginDefinition definition = new RecordHealthCheckPluginDefinition()
      .integerParameter('maxPreviewRecords', 5, 1, 50)
      .choiceParameter('displayFormat', 'nameId', displayChoices)
      .stringParameter(
        'previewService',
        'QuoteInactiveApproverPreviewService',
        255
      )
      .booleanParameter('includeInactive', false)
      .describe(
        'maxPreviewRecords',
        'Maximum preview records',
        'Maximum number of records shown in a preview.'
      );
    displayChoices.clear();
    if (mode == 'INVALID_DEFINITION') {
      definition.booleanParameter('includeInactive', true);
    }
    if (mode == 'REQUIRED') {
      definition.stringParameter('requiredText', null, 20)
        .required('requiredText', true);
    }
    if (mode == 'NULLABLE') {
      definition.nullable('maxPreviewRecords', true);
    }
    if (mode == 'CAPACITY') {
      definition.capacity(5, false, 'HIGH');
    }
    return definition;
  }

  public Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    evaluateCount++;
    seenParameters = scope.parameters;
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.passEquals(
          'DEFINITION_ACCEPTED',
          RecordHealthCheckValue.ofCount(scope.size()),
          RecordHealthCheckValue.ofCount(scope.size())
        )
      );
    }
    return outcomes;
  }
}
