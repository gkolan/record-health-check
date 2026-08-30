/** Automation-neutral asynchronous side effect used only by package tests. */
@IsTest
public class RHCTestNoopQueueable implements Queueable, Finalizer {
  public void execute(QueueableContext context) {
    System.attachFinalizer(this);
  }

  public void execute(FinalizerContext context) {
    Limits.getDmlStatements();
  }
}
