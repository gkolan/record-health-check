/** Optional additive presentation contract for display-capable evaluation. */
global interface RecordHealthCheckDisplayPlugin {
  Map<Id, RecordHealthCheckDisplayOverride> getDisplay(
    RecordHealthCheckScope scope
  );
}
