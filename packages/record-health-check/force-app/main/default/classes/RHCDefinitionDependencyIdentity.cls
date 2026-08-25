/** Resolves prerequisite Checks without collapsing managed and subscriber identities. */
public with sharing class RHCDefinitionDependencyIdentity {
  /**
   * Resolves the prerequisite's qualified identity in the dependent Check's namespace.
   * @param dependent Check whose prerequisite is being resolved.
   * @param checks active Checks in the same Check Set.
   * @return namespace-safe QualifiedApiName, or null when absent or ambiguous.
   */
  public static String resolve(
    Record_Health_Check__mdt dependent,
    List<Record_Health_Check__mdt> checks
  ) {
    String prerequisite = String.isNotBlank(dependent?.PrerequisiteCheck__c)
      ? dependent.PrerequisiteCheck__c.trim()
      : null;
    if (prerequisite == null) {
      return null;
    }

    String dependentNamespace = namespacePrefix(
      dependent?.QualifiedApiName,
      dependent?.DeveloperName
    );
    String onlyMatch;
    for (Record_Health_Check__mdt candidate : checks) {
      if (
        candidate.QualifiedApiName != prerequisite &&
        candidate.DeveloperName != prerequisite
      ) {
        continue;
      }
      if (
        namespacePrefix(candidate.QualifiedApiName, candidate.DeveloperName) ==
        dependentNamespace
      ) {
        return candidate.QualifiedApiName;
      }
      onlyMatch = onlyMatch == null
        ? candidate.QualifiedApiName
        : onlyMatch == candidate.QualifiedApiName ? onlyMatch : null;
    }
    return onlyMatch;
  }

  private static String namespacePrefix(
    String qualifiedApiName,
    String developerName
  ) {
    String suffix = '__' + developerName;
    return String.isNotBlank(qualifiedApiName) &&
      String.isNotBlank(developerName) &&
      qualifiedApiName.endsWith(suffix)
      ? qualifiedApiName.substring(
          0,
          qualifiedApiName.length() - suffix.length()
        )
      : '';
  }
}
