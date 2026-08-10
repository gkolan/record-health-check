/** Identifies the caller context attributed to a Record Health Check run. */
global enum RecordHealthCheckExecutionOrigin {
  APEX_API,
  FLOW,
  USER_INITIATED,
  RUN_ON_LOAD,
  BATCH,
  QUEUEABLE,
  SCHEDULED,
  FUTURE,
  AGENT
}
