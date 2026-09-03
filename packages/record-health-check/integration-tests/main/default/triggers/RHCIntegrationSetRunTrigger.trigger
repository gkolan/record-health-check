trigger RHCIntegrationSetRunTrigger on Record_Health_Check_Set_Run__e(
  after insert
) {
  RHCIntegrationEventReceipt.receiveSetRuns(Trigger.new);
}
