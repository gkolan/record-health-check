export function selectCardUserPermissionSet(records, { installedPackage }) {
  const candidates = Array.isArray(records) ? records : [];
  const matching = installedPackage
    ? candidates.filter((record) => Boolean(record.NamespacePrefix))
    : candidates;

  if (matching.length !== 1) {
    const qualifier = installedPackage ? "namespaced package " : "";
    throw new Error(
      `Expected one ${qualifier}Card User permission set; found ${matching.length}.`
    );
  }

  return matching[0];
}
