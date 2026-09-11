/** Keeps Apex Check validation and authoring issue taxonomy out of the shared validators. */
public with sharing class RecordHealthCheckApexConfigSupport {
  /** Returns the first Apex configuration finding in validation precedence order. */
  public static List<RecordHealthCheckValidator.Finding> findings(
    Record_Health_Check__mdt check
  ) {
    List<RecordHealthCheckValidator.Finding> out = structuralFindings(check);
    if (!out.isEmpty()) {
      return out;
    }
    RecordHealthCheckConfigValidator.ApexPluginValidation validation = RecordHealthCheckConfigValidator.validateApexPlugin(
      check
    );
    if (!validation.isValid) {
      RecordHealthCheckValidator.Finding invalidPlugin = finding(
        findingCode(validation.reasonCode)
      );
      invalidPlugin.phase = validation.phase;
      invalidPlugin.originalException = validation.originalException;
      out.add(invalidPlugin);
    }
    return out;
  }

  /** Validates an Apex Check without loading or constructing subscriber code. */
  public static List<RecordHealthCheckValidator.Finding> structuralFindings(
    Record_Health_Check__mdt check
  ) {
    List<RecordHealthCheckValidator.Finding> out = new List<RecordHealthCheckValidator.Finding>();
    if (String.isBlank(check.ApexClass__c)) {
      out.add(
        finding(RecordHealthCheckValidator.FindingCode.APEX_CLASS_MISSING)
      );
      return out;
    }
    if (
      !RecordHealthCheckConfigValidator.isValidApexClassNameSyntax(
        check.ApexClass__c
      )
    ) {
      out.add(
        finding(RecordHealthCheckValidator.FindingCode.APEX_CLASS_INVALID)
      );
      return out;
    }
    if (
      !RecordHealthCheckConfigValidator.isJsonObject(
        check.ApexParametersJson__c
      )
    ) {
      out.add(
        finding(RecordHealthCheckValidator.FindingCode.APEX_PARAMS_INVALID)
      );
      return out;
    }
    return out;
  }

  /** Maps one Apex finding to its authoring validation issue. */
  public static RecordHealthCheckMetadataValidator.ValidationIssue metadataIssue(
    Record_Health_Check__mdt check,
    RecordHealthCheckValidator.Finding finding
  ) {
    String fieldName = 'ApexClass__c';
    String message;
    String reasonCode;
    switch on finding.code {
      when APEX_CLASS_MISSING {
        message = 'Apex Class Name is required for Apex checks.';
        reasonCode = RecordHealthCheckReasonCodes.APEX_CLASS_NOT_FOUND;
      }
      when APEX_CLASS_INVALID {
        message = 'Apex Class Name must be a class name or namespace-qualified class name.';
        reasonCode = RecordHealthCheckReasonCodes.APEX_CLASS_INVALID;
      }
      when APEX_CLASS_NOT_FOUND {
        message = 'Apex Class Name did not identify a visible class.';
        reasonCode = RecordHealthCheckReasonCodes.APEX_CLASS_NOT_FOUND;
      }
      when APEX_CLASS_LOAD_FAILED {
        message = 'Apex Class Name could not be loaded.';
        reasonCode = RecordHealthCheckReasonCodes.APEX_CLASS_LOAD_FAILED;
      }
      when APEX_PLUGIN_INTERFACE_INVALID {
        message = 'The configured class does not implement RecordHealthCheckPlugin.';
        reasonCode = RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID;
      }
      when APEX_PLUGIN_CONSTRUCTOR_FAILED {
        message = 'The configured Apex Check could not be constructed.';
        reasonCode = RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED;
      }
      when APEX_PLUGIN_DEFINITION_INVALID {
        fieldName = 'ApexParametersJson__c';
        message = 'The configured Apex Check definition is invalid.';
        reasonCode = RecordHealthCheckReasonCodes.PLUGIN_DEFINITION_INVALID;
      }
      when else {
        fieldName = 'ApexParametersJson__c';
        message = 'Apex Parameters must contain a valid JSON object.';
        reasonCode = RecordHealthCheckReasonCodes.INVALID_APEX_PARAMETERS;
      }
    }
    return new RecordHealthCheckMetadataValidator.ValidationIssue(
      'ERROR',
      check.DeveloperName,
      fieldName,
      message,
      reasonCode
    );
  }

  private static RecordHealthCheckValidator.Finding finding(
    RecordHealthCheckValidator.FindingCode code
  ) {
    return new RecordHealthCheckValidator.Finding(code, null);
  }

  private static RecordHealthCheckValidator.FindingCode findingCode(
    String reasonCode
  ) {
    Map<String, RecordHealthCheckValidator.FindingCode> codesByReason = new Map<String, RecordHealthCheckValidator.FindingCode>{
      RecordHealthCheckReasonCodes.APEX_CLASS_NOT_FOUND => RecordHealthCheckValidator.FindingCode.APEX_CLASS_NOT_FOUND,
      RecordHealthCheckReasonCodes.APEX_CLASS_LOAD_FAILED => RecordHealthCheckValidator.FindingCode.APEX_CLASS_LOAD_FAILED,
      RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID => RecordHealthCheckValidator.FindingCode.APEX_PLUGIN_INTERFACE_INVALID,
      RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED => RecordHealthCheckValidator.FindingCode.APEX_PLUGIN_CONSTRUCTOR_FAILED,
      RecordHealthCheckReasonCodes.PLUGIN_DEFINITION_INVALID => RecordHealthCheckValidator.FindingCode.APEX_PLUGIN_DEFINITION_INVALID,
      RecordHealthCheckReasonCodes.INVALID_APEX_PARAMETERS => RecordHealthCheckValidator.FindingCode.APEX_PARAMS_INVALID
    };
    RecordHealthCheckValidator.FindingCode code = codesByReason.get(reasonCode);
    return code == null
      ? RecordHealthCheckValidator.FindingCode.APEX_CLASS_INVALID
      : code;
  }
}
