/** Regression coverage for namespace-safe prerequisite resolution. */
@IsTest
private class RHCDefinitionDependencyIdentityTest {
  @IsTest
  static void resolvesPrerequisiteInDependentNamespace() {
    Record_Health_Check__mdt managedPrerequisite = check(
      'Shared_Name',
      'rhc__Shared_Name',
      null
    );
    Record_Health_Check__mdt subscriberPrerequisite = check(
      'Shared_Name',
      'Shared_Name',
      null
    );
    Record_Health_Check__mdt dependent = check(
      'Dependent',
      'rhc__Dependent',
      'Shared_Name'
    );

    Assert.areEqual(
      'rhc__Shared_Name',
      RHCDefinitionDependencyIdentity.resolve(
        dependent,
        new List<Record_Health_Check__mdt>{
          subscriberPrerequisite,
          managedPrerequisite,
          dependent
        }
      ),
      'A managed dependent must not attach to a subscriber Check with the same DeveloperName.'
    );
  }

  @IsTest
  static void rejectsAmbiguousCrossNamespaceFallbacks() {
    Record_Health_Check__mdt dependent = check(
      'Dependent',
      'third__Dependent',
      'Shared_Name'
    );
    List<Record_Health_Check__mdt> candidates = new List<Record_Health_Check__mdt>{
      check('Other_Name', 'other__Other_Name', null),
      check('Shared_Name', 'first__Shared_Name', null),
      check('Shared_Name', 'second__Shared_Name', null)
    };

    Assert.isNull(
      RHCDefinitionDependencyIdentity.resolve(dependent, candidates),
      'Two cross-namespace fallbacks are ambiguous and must fail closed.'
    );
  }

  @IsTest
  static void resolvesQualifiedIdentityWithoutCaseSensitivity() {
    Record_Health_Check__mdt dependent = check(
      'Dependent',
      'rhc__Dependent',
      'account_has_owner'
    );

    Assert.areEqual(
      'rhc__Account_Has_Owner',
      RHCDefinitionDependencyIdentity.resolveQualified(
        dependent,
        new Set<String>{ 'rhc__Account_Has_Owner' }
      ),
      'Configured prerequisite casing must not change runtime identity resolution.'
    );
  }

  @IsTest
  static void ordersPrerequisitesBeforeDependents() {
    Record_Health_Check__mdt dependent = check(
      'Dependent',
      'Dependent',
      'Prerequisite'
    );
    dependent.EvaluationOrder__c = 10;
    Record_Health_Check__mdt prerequisite = check(
      'Prerequisite',
      'Prerequisite',
      null
    );
    prerequisite.EvaluationOrder__c = null;

    List<Record_Health_Check__mdt> ordered = RHCDefinitionDependencyIdentity.orderForEvaluation(
      new List<Record_Health_Check__mdt>{ dependent, prerequisite }
    );

    Assert.areEqual(
      'Prerequisite',
      ordered[0].QualifiedApiName,
      'Dependency order must override nullable metadata ordering in headless runs.'
    );
    Assert.areEqual('Dependent', ordered[1].QualifiedApiName);
  }

  private static Record_Health_Check__mdt check(
    String developerName,
    String qualifiedApiName,
    String prerequisite
  ) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => developerName,
        'QualifiedApiName' => qualifiedApiName,
        'PrerequisiteCheck__c' => prerequisite
      }
    );
  }
}
