/** Optional additive presentation contract for card execution only. */
global interface RecordHealthCheckDisplayPlugin {
  Map<Id, RecordHealthCheckDisplayOverride> getDisplay(
    RecordHealthCheckScope scope
  );
}
