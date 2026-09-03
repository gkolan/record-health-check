trigger RHCSubscriberSetRunTrigger on rhc__Record_Health_Check_Set_Run__e(
  after insert
) {
  RHCSubscriberEventReceipt.receiveSetRuns(Trigger.new);
}
