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
