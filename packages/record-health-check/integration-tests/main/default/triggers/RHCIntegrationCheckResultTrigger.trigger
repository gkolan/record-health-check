trigger RHCIntegrationCheckResultTrigger on Record_Health_Check_Result__e(
  after insert
) {
  RHCIntegrationEventReceipt.receiveCheckResults(Trigger.new);
}
