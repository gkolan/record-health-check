trigger RHCSubscriberCheckResultTrigger on rhc__Record_Health_Check_Result__e(
  after insert
) {
  RHCSubscriberEventReceipt.receiveCheckResults(Trigger.new);
}
