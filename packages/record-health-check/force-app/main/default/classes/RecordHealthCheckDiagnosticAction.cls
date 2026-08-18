/** One ordered action attached to an authorized diagnostic incident. */
global class RecordHealthCheckDiagnosticAction {
  @AuraEnabled
  /** Stable action kind consumed by diagnostic surfaces. */
  global String kind;
  @AuraEnabled
  /** Short action label. */
  global String label;
  @AuraEnabled
  /** Plain-language instruction. */
  global String instruction;
  @AuraEnabled
  /** Optional safe target such as a metadata field or component name. */
  global String target;
}
