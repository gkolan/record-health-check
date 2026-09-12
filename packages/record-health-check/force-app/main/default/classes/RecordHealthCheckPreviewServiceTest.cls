@IsTest
private class RecordHealthCheckPreviewServiceTest {
  @IsTest
  static void validateOnlyReturnsNoResultsAndNoReceipt() {
    authorize();
    try {
      Record_Health_Check_Set__mdt checkSet = accountSet();
      RecordHealthCheckPreviewResponse response = RecordHealthCheckPreviewService.preview(
        RecordHealthCheckPreviewRequest.forDraftCheck(
          formulaDraft(checkSet.Id),
          checkSet.QualifiedApiName,
          new List<Id>()
        )
      );

      Assert.areEqual(
        '1.0',
        response.version,
        'Preview must retain response contract version 1.0.'
      );
      Assert.areEqual(
        'VALIDATE_ONLY',
        response.mode,
        'The default preview mode must be VALIDATE_ONLY.'
      );
      Assert.areEqual(
        'VALID',
        response.validationStatus,
        'A valid formula draft must validate successfully.'
      );
      Assert.areEqual(
        0,
        response.results.size(),
        'Validation alone must not produce evaluation results.'
      );
      Assert.areEqual(
        'NOT_REQUESTED',
        response.readinessReceipt.receiptStatus,
        'Validation alone must not request a readiness receipt.'
      );
      Assert.areEqual(
        'DRAFT',
        response.readinessState,
        'Validation alone must leave readiness in DRAFT.'
      );
      Assert.areEqual(
        false,
        response.hasCurrentLiveVerification,
        'Validation alone must not claim live verification.'
      );
      Assert.isNotNull(
        response.definitionFingerprint,
        'Validation must return a definition fingerprint.'
      );
    } finally {
      clearAuthorization();
    }
  }

  @IsTest
  static void newDraftCannotForgeServerIdentity() {
    authorize();
    try {
      Record_Health_Check_Set__mdt checkSet = accountSet();
      Record_Health_Check__mdt draft = formulaDraft(checkSet.Id);
      draft.put('QualifiedApiName', 'Forged_Identity');
      try {
        RecordHealthCheckPreviewService.preview(
          RecordHealthCheckPreviewRequest.forDraftCheck(
            draft,
            checkSet.QualifiedApiName,
            new List<Id>()
          )
        );
        Assert.fail('A new draft must not supply a server-owned identity.');
      } catch (RecordHealthCheckPreviewService.PreviewException expected) {
        Assert.isTrue(
          expected.getMessage().contains('identity'),
          'A forged draft identity must be rejected as an identity error.'
        );
      }
    } finally {
      clearAuthorization();
    }
  }

  @IsTest
  static void mismatchedParentIsRejectedBeforeEvaluation() {
    authorize();
    try {
      List<Record_Health_Check_Set__mdt> sets = [
        SELECT Id, QualifiedApiName
        FROM Record_Health_Check_Set__mdt
        ORDER BY DeveloperName
        LIMIT 2
      ];
      Record_Health_Check__mdt draft = formulaDraft(sets[1].Id);
      try {
        RecordHealthCheckPreviewService.preview(
          RecordHealthCheckPreviewRequest.forDraftCheck(
            draft,
            sets[0].QualifiedApiName,
            new List<Id>()
          )
        );
        Assert.fail('A caller must not forge the owning Check Set.');
      } catch (RecordHealthCheckPreviewService.PreviewException expected) {
        Assert.isTrue(
          expected.getMessage().contains('parent'),
          'A mismatched owner must be rejected as a parent error.'
        );
      }
    } finally {
      clearAuthorization();
    }
  }

  @IsTest
  static void validateOnlyDoesNotLoadApexPlugin() {
    authorize();
    try {
      Record_Health_Check_Set__mdt checkSet = accountSet();
      Record_Health_Check__mdt draft = formulaDraft(checkSet.Id);
      draft.EvaluationType__c = 'APEX';
      draft.PassConditionFormula__c = null;
      draft.ApexClass__c = 'AccountHasRecentActivityCheck';
      draft.ApexParametersJson__c = '{}';

      RecordHealthCheckPreviewResponse response = RecordHealthCheckPreviewService.preview(
        RecordHealthCheckPreviewRequest.forDraftCheck(
          draft,
          checkSet.QualifiedApiName,
          new List<Id>()
        )
      );

      Assert.areEqual(
        'INCOMPLETE',
        response.validationStatus,
        'Validation without loading a plugin must remain incomplete.'
      );
      Assert.areEqual(
        'INCOMPLETE',
        response.capabilities.get('pluginSchema'),
        'The unloaded plugin schema must remain incomplete.'
      );
      Assert.areEqual(
        0,
        response.results.size(),
        'Plugin validation alone must not produce evaluation results.'
      );
    } finally {
      clearAuthorization();
    }
  }

  @IsTest
  static void formulaFindingRetainsSafeSourceOffsets() {
    authorize();
    try {
      Record_Health_Check_Set__mdt checkSet = accountSet();
      Record_Health_Check__mdt draft = formulaDraft(checkSet.Id);
      String formula = 'Website = "unterminated';
      draft.PassConditionFormula__c = formula;

      RecordHealthCheckPreviewResponse response = RecordHealthCheckPreviewService.preview(
        RecordHealthCheckPreviewRequest.forDraftCheck(
          draft,
          checkSet.QualifiedApiName,
          new List<Id>()
        )
      );

      RecordHealthCheckPreviewFinding finding = response.findings[0];
      Assert.areEqual(
        'INVALID_FORMULA_LITERAL',
        finding.code,
        'An unterminated literal must retain its specific finding code.'
      );
      Assert.areEqual(
        'PassConditionFormula__c',
        finding.configurationField,
        'The literal finding must identify the formula configuration field.'
      );
      Assert.areEqual(
        '[redacted literal]',
        finding.offendingToken,
        'The literal finding must redact source content.'
      );
      Assert.areEqual(
        10,
        finding.startOffset,
        'The literal finding must begin at the opening quote.'
      );
      Assert.areEqual(
        formula.length(),
        finding.endOffset,
        'The literal finding must end at the formula boundary.'
      );
    } finally {
      clearAuthorization();
    }
  }

  @IsTest
  static void previewRequiresBothAdministratorAndRunEntitlement() {
    RecordHealthCheckAccess.setRunPermissionForTest(false);
    try {
      Record_Health_Check_Set__mdt checkSet = accountSet();
      try {
        RecordHealthCheckPreviewService.preview(
          RecordHealthCheckPreviewRequest.forDraftCheck(
            formulaDraft(checkSet.Id),
            checkSet.QualifiedApiName,
            new List<Id>()
          )
        );
        Assert.fail('A non-administrator must not preview detached metadata.');
      } catch (RecordHealthCheckPreviewService.PreviewException expected) {
        Assert.isTrue(
          expected.getMessage().contains('administrator'),
          'Unauthorized preview must explain its administrator requirement.'
        );
      }
    } finally {
      clearAuthorization();
    }
  }

  @IsTest
  static void rejectsNullBlankAndSelfDependentDrafts() {
    authorize();
    try {
      assertPreviewFailure(null, 'required');
      Record_Health_Check_Set__mdt checkSet = accountSet();
      Record_Health_Check__mdt blank = formulaDraft(checkSet.Id);
      blank.DeveloperName = null;
      assertPreviewFailure(
        RecordHealthCheckPreviewRequest.forDraftCheck(
          blank,
          checkSet.QualifiedApiName,
          new List<Id>()
        ),
        'DeveloperName'
      );
      Record_Health_Check__mdt selfDependent = formulaDraft(checkSet.Id);
      selfDependent.PrerequisiteCheck__c = selfDependent.DeveloperName;
      assertPreviewFailure(
        RecordHealthCheckPreviewRequest.forDraftCheck(
          selfDependent,
          checkSet.QualifiedApiName,
          new List<Id>()
        ),
        'depend on itself'
      );
    } finally {
      clearAuthorization();
    }
  }

  @IsTest
  static void executeDiscoversEveryPluginParameterShape() {
    authorize();
    RecordHealthCheckDefTestPlugin.mode = null;
    try {
      Record_Health_Check_Set__mdt checkSet = accountSet();
      Record_Health_Check__mdt draft = formulaDraft(checkSet.Id);
      draft.EvaluationType__c = 'APEX';
      draft.PassConditionFormula__c = null;
      draft.ApexClass__c = 'RecordHealthCheckDefTestPlugin';
      draft.ApexParametersJson__c = '{"maxPreviewRecords":7,"displayFormat":"nameRule","includeInactive":true}';

      RecordHealthCheckPreviewResponse response = RecordHealthCheckPreviewService.preview(
        RecordHealthCheckPreviewRequest.forDraftCheck(
            draft,
            checkSet.QualifiedApiName,
            new List<Id>()
          )
          .withMode('EXECUTE')
      );

      Assert.areEqual(
        'INCOMPLETE',
        response.validationStatus,
        'A plugin without a reliable revision remains explicitly incomplete.'
      );
      Assert.areEqual(
        4,
        response.pluginParameters.size(),
        'Schema discovery must expose all four parameter shapes.'
      );
      Assert.areEqual(
        'maxPreviewRecords',
        response.pluginParameters[0].key,
        'The numeric parameter must retain its key.'
      );
      Assert.areEqual(
        7,
        response.pluginParameters[0].currentValue,
        'The numeric parameter must retain its configured value.'
      );
      Assert.areEqual(
        1,
        response.pluginParameters[0].minValue,
        'The numeric parameter must retain its minimum.'
      );
      Assert.areEqual(
        50,
        response.pluginParameters[0].maxValue,
        'The numeric parameter must retain its maximum.'
      );
      Assert.areEqual(
        'displayFormat',
        response.pluginParameters[1].key,
        'The enum parameter must retain its key.'
      );
      Assert.areEqual(
        4,
        response.pluginParameters[1].choices.size(),
        'The enum parameter must retain all four choices.'
      );
      Assert.areEqual(
        'previewService',
        response.pluginParameters[2].key,
        'The text parameter must retain its key.'
      );
      Assert.areEqual(
        255,
        response.pluginParameters[2].maxLength,
        'The text parameter must retain its length bound.'
      );
      Assert.areEqual(
        false,
        response.pluginParameters[3].defaultValue,
        'The Boolean parameter must retain its false default.'
      );
    } finally {
      RecordHealthCheckDefTestPlugin.mode = null;
      clearAuthorization();
    }
  }

  @IsTest
  static void existingIdentityCannotBeReassignedOrForged() {
    authorize();
    try {
      Record_Health_Check__mdt existing = [
        SELECT
          Id,
          DeveloperName,
          QualifiedApiName,
          NamespacePrefix,
          Language,
          Record_Health_Check_Set__c,
          CheckTitle__c,
          EvaluationOrder__c,
          IsActive__c,
          EvaluationType__c,
          FailureSeverity__c,
          PassConditionFormula__c,
          FailureMessage__c
        FROM Record_Health_Check__mdt
        WHERE
          Record_Health_Check_Set__r.DeveloperName = 'Example_Account_Check_Builder_Guide'
        LIMIT 1
      ];
      Record_Health_Check_Set__mdt checkSet = accountSet();
      Record_Health_Check__mdt wrongId = formulaDraft(checkSet.Id);
      wrongId.put(
        'Id',
        RecordHealthCheckTestDataFactory.syntheticId(
          Record_Health_Check__mdt.SObjectType,
          99
        )
      );
      assertPreviewFailure(
        RecordHealthCheckPreviewRequest.forDraftCheck(
          wrongId,
          checkSet.QualifiedApiName,
          new List<Id>()
        ),
        'identity'
      );

      Record_Health_Check__mdt renamed = existing.clone(true, true, true, true);
      renamed.DeveloperName = 'Renamed_Server_Check';
      assertPreviewFailure(
        RecordHealthCheckPreviewRequest.forDraftCheck(
          renamed,
          checkSet.QualifiedApiName,
          new List<Id>()
        ),
        'identity'
      );
    } finally {
      clearAuthorization();
    }
  }

  private static void assertPreviewFailure(
    RecordHealthCheckPreviewRequest request,
    String expectedText
  ) {
    try {
      RecordHealthCheckPreviewService.preview(request);
      Assert.fail('The invalid detached preview must be rejected.');
    } catch (RecordHealthCheckPreviewService.PreviewException expected) {
      Assert.isTrue(
        expected.getMessage().contains(expectedText),
        'The preview rejection must contain the expected error detail.'
      );
    }
  }

  private static void authorize() {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  private static void clearAuthorization() {
    RecordHealthCheckAccess.setRunPermissionForTest(null);
  }

  private static Record_Health_Check_Set__mdt accountSet() {
    return [
      SELECT Id, QualifiedApiName
      FROM Record_Health_Check_Set__mdt
      WHERE DeveloperName = 'Example_Account_Check_Builder_Guide'
      LIMIT 1
    ];
  }

  private static Record_Health_Check__mdt formulaDraft(Id checkSetId) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Detached_Preview',
        'MasterLabel' => 'Detached Preview',
        'Record_Health_Check_Set__c' => checkSetId,
        'CheckTitle__c' => 'Detached Preview',
        'EvaluationOrder__c' => 1,
        'IsActive__c' => false,
        'EvaluationType__c' => 'FORMULA',
        'FailureSeverity__c' => 'WARNING',
        'PassConditionFormula__c' => 'TRUE',
        'FailureMessage__c' => 'Preview failed.'
      }
    );
  }
}
