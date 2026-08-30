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
    Integer matchCount = 0;
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
      onlyMatch = candidate.QualifiedApiName;
      matchCount++;
    }
    return matchCount == 1 ? onlyMatch : null;
  }

  /**
   * Resolves a prerequisite against qualified result identities.
   * @param dependent Check whose prerequisite is being resolved.
   * @param qualifiedApiNames identities available in the current record run.
   * @return same-namespace identity first, then an unambiguous fallback, or null.
   */
  public static String resolveQualified(
    Record_Health_Check__mdt dependent,
    Set<String> qualifiedApiNames
  ) {
    String prerequisite = String.isNotBlank(dependent?.PrerequisiteCheck__c)
      ? dependent.PrerequisiteCheck__c.trim()
      : null;
    if (prerequisite == null || qualifiedApiNames == null) {
      return null;
    }
    String dependentNamespace = namespacePrefix(
      dependent?.QualifiedApiName,
      dependent?.DeveloperName
    );
    String preferred = String.isBlank(dependentNamespace)
      ? prerequisite
      : dependentNamespace + '__' + prerequisite;
    for (String qualifiedApiName : qualifiedApiNames) {
      if (
        qualifiedApiName != null && qualifiedApiName.equalsIgnoreCase(preferred)
      ) {
        return qualifiedApiName;
      }
    }
    String onlyMatch;
    Integer matchCount = 0;
    for (String qualifiedApiName : qualifiedApiNames) {
      if (qualifiedApiName == null) {
        continue;
      }
      if (
        qualifiedApiName != prerequisite &&
        !qualifiedApiName.toLowerCase()
          .endsWith(('__' + prerequisite).toLowerCase())
      ) {
        continue;
      }
      onlyMatch = qualifiedApiName;
      matchCount++;
    }
    return matchCount == 1 ? onlyMatch : null;
  }

  /**
   * Orders Checks so an included prerequisite always precedes its dependents.
   * Unresolved dependencies and cycles retain their input order.
   * @param checks Checks in their normal deterministic display order.
   * @return dependency-safe evaluation order.
   */
  public static List<Record_Health_Check__mdt> orderForEvaluation(
    List<Record_Health_Check__mdt> checks
  ) {
    List<Record_Health_Check__mdt> ordered = new List<Record_Health_Check__mdt>();
    Set<String> pending = new Set<String>();
    for (Record_Health_Check__mdt check : checks) {
      pending.add(check.QualifiedApiName);
    }

    Boolean madeProgress = true;
    while (!pending.isEmpty() && madeProgress) {
      madeProgress = false;
      for (Record_Health_Check__mdt check : checks) {
        if (!pending.contains(check.QualifiedApiName)) {
          continue;
        }
        String prerequisite = resolve(check, checks);
        if (prerequisite == null || !pending.contains(prerequisite)) {
          ordered.add(check);
          pending.remove(check.QualifiedApiName);
          madeProgress = true;
        }
      }
    }
    for (Record_Health_Check__mdt check : checks) {
      if (pending.contains(check.QualifiedApiName)) {
        ordered.add(check);
      }
    }
    return ordered;
  }

  private static String namespacePrefix(
    String qualifiedApiName,
    String developerName
  ) {
    String suffix = '__' + developerName;
    return String.isNotBlank(qualifiedApiName) &&
      String.isNotBlank(developerName) &&
      qualifiedApiName.toLowerCase().endsWith(suffix.toLowerCase())
      ? qualifiedApiName.substring(
          0,
          qualifiedApiName.length() - suffix.length()
        )
      : '';
  }
}
