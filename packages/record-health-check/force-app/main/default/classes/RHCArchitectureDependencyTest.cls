/** Guards exact cycle membership and dependency ordering. */
@IsTest
private with sharing class RHCArchitectureDependencyTest {
  @IsTest
  static void caseD01IdentifiesTwoNodeCycle() {
    Assert.areEqual(
      new Set<String>{ 'A', 'B' },
      RHCDefinitionDependencyIdentity.cycleMembers(
        new List<Record_Health_Check__mdt>{ check('A', 'B'), check('B', 'A') }
      )
    );
  }

  @IsTest
  static void caseD02IdentifiesSelfCycle() {
    Assert.areEqual(
      new Set<String>{ 'A' },
      RHCDefinitionDependencyIdentity.cycleMembers(
        new List<Record_Health_Check__mdt>{ check('A', 'A') }
      )
    );
  }

  @IsTest
  static void caseD03ExcludesDownstreamDependent() {
    Assert.areEqual(
      new Set<String>{ 'A', 'B' },
      RHCDefinitionDependencyIdentity.cycleMembers(
        new List<Record_Health_Check__mdt>{
          check('A', 'B'),
          check('B', 'A'),
          check('D', 'A')
        }
      ),
      'A downstream dependent must not become a cycle member.'
    );
  }

  @IsTest
  static void caseD04IgnoresHealthyControlBranch() {
    Assert.areEqual(
      new Set<String>{ 'A', 'B' },
      RHCDefinitionDependencyIdentity.cycleMembers(
        new List<Record_Health_Check__mdt>{
          check('A', 'B'),
          check('B', 'A'),
          check('Control', null)
        }
      )
    );
  }

  @IsTest
  static void caseD05HandlesNullInput() {
    Assert.areEqual(
      new Set<String>(),
      RHCDefinitionDependencyIdentity.cycleMembers(null)
    );
  }

  @IsTest
  static void caseD06OrdersHealthyBranchFirst() {
    List<Record_Health_Check__mdt> input = new List<Record_Health_Check__mdt>{
      check('D', 'A'),
      check('A', 'B'),
      check('B', 'A'),
      check('Control', null)
    };
    List<Record_Health_Check__mdt> ordered = RHCDefinitionDependencyIdentity.orderForEvaluation(
      input
    );
    Assert.areEqual('Control', ordered[0].QualifiedApiName);
  }

  @IsTest
  static void caseD07PrefersSameNamespaceDependency() {
    List<Record_Health_Check__mdt> checks = new List<Record_Health_Check__mdt>{
      check('pkg__A', 'B'),
      check('pkg__B', 'A'),
      check('B', null)
    };
    Assert.areEqual(
      new Set<String>{ 'pkg__A', 'pkg__B' },
      RHCDefinitionDependencyIdentity.cycleMembers(checks),
      'Same-namespace dependencies must win over unqualified siblings.'
    );
  }

  @IsTest
  static void caseD08IgnoresMissingPrerequisite() {
    Assert.areEqual(
      new Set<String>(),
      RHCDefinitionDependencyIdentity.cycleMembers(
        new List<Record_Health_Check__mdt>{ check('A', 'Missing') }
      )
    );
  }

  @IsTest
  static void caseW06RecomputesCorrectedGraph() {
    List<Record_Health_Check__mdt> repaired = new List<Record_Health_Check__mdt>{
      check('A', null),
      check('B', 'A')
    };
    Assert.areEqual(
      new Set<String>(),
      RHCDefinitionDependencyIdentity.cycleMembers(repaired),
      'A corrected graph must be recomputed without stale cycle state.'
    );
  }

  private static Record_Health_Check__mdt check(
    String qualifiedApiName,
    String prerequisite
  ) {
    Integer namespaceSeparator = qualifiedApiName.indexOf('__');
    String developerName = namespaceSeparator >= 0
      ? qualifiedApiName.substring(namespaceSeparator + 2)
      : qualifiedApiName;
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'QualifiedApiName' => qualifiedApiName,
        'DeveloperName' => developerName,
        'PrerequisiteCheck__c' => prerequisite
      }
    );
  }
}
