/** Test-only facade for verifying a subscriber plugin contract. */
global class RecordHealthCheckPluginTest {
  /** Captures one guarded plugin execution for fluent contract assertions. */
  global static RecordHealthCheckPluginVerification verify(
    RecordHealthCheckPlugin plugin,
    RecordHealthCheckScope scope
  ) {
    if (!Test.isRunningTest()) {
      throw new TestContextRequiredException('TEST_CONTEXT_REQUIRED');
    }
    return RecordHealthCheckPluginVerification.create(plugin, scope);
  }

  /** Raised when the test-only facade is invoked from production execution. */
  global class TestContextRequiredException extends Exception {
  }
}
