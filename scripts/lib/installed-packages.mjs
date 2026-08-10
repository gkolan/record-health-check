/**
 * Normalize `sf package installed list --json` output across CLI versions.
 */
export function installedPackageRecords(payload) {
  const result = payload?.result;
  if (Array.isArray(result)) {
    return result;
  }
  if (Array.isArray(result?.records)) {
    return result.records;
  }
  if (Array.isArray(result?.installedPackages)) {
    return result.installedPackages;
  }
  return [];
}

export function hasInstalledPackageVersion(
  records,
  subscriberPackageVersionId
) {
  const target = String(subscriberPackageVersionId ?? "");
  return records.some((entry) => {
    const id =
      entry.SubscriberPackageVersionId ??
      entry.subscriberPackageVersionId ??
      entry.Id ??
      "";
    return (
      String(id).startsWith("04t") && (target ? String(id) === target : true)
    );
  });
}
