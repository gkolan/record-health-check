/** Retains source coordinates for record-field merge planning failures. */
public class RecordHealthCheckMergeFindingService {
  public static List<RecordHealthCheckFormulaPlanService.Finding> findings(
    String template,
    String configurationField,
    Schema.SObjectType objectType,
    RecordHealthCheckFieldPlanner resolver
  ) {
    List<RecordHealthCheckFormulaPlanService.Finding> findings = new List<RecordHealthCheckFormulaPlanService.Finding>();
    if (String.isBlank(template)) {
      return findings;
    }
    for (
      RecordHealthCheckToken token : RecordHealthCheckTemplateService.parse(
        template
      )
    ) {
      if (
        token.namespaceName != 'record' ||
        token.shape == null ||
        !token.shape.isUsable()
      ) {
        continue;
      }
      String reasonCode = resolver.resolutionReasonCode(
        objectType,
        token.shape.fieldPath
      );
      if (reasonCode != null) {
        findings.add(
          RecordHealthCheckFormulaPlanService.templateFinding(
            reasonCode,
            configurationField,
            token,
            objectType
          )
        );
      }
    }
    return findings;
  }
}
