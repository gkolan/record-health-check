export function releaseUpgradeBases(matrix, releases) {
  const bases = matrix.upgradeBases;
  // Publication moves the validated candidate into stable and the former
  // stable into previous. Preserve the reviewed upgrade origins across that
  // registry-only transition without accepting a different package ID.
  const baseline =
    releases.stable?.version === matrix.candidateVersion
      ? releases.previous
      : releases.stable;
  if (
    !Array.isArray(bases) ||
    bases.length === 0 ||
    new Set(bases.map((b) => b.version)).size !== bases.length ||
    new Set(bases.map((b) => b.subscriberPackageVersionId)).size !==
      bases.length ||
    bases.some(
      (b) =>
        !/^\d+\.\d+\.\d+\.\d+$/.test(b.version) ||
        !/^04t[0-9A-Za-z]{15}$/.test(b.subscriberPackageVersionId)
    )
  ) {
    throw new Error(
      "Release upgrade bases must have unique exact versions and 18-character 04t IDs."
    );
  }
  if (
    !bases.some(
      (b) =>
        b.version === matrix.upgradeFromVersion &&
        b.version === baseline?.version &&
        b.subscriberPackageVersionId === baseline?.subscriberPackageVersionId
    )
  ) {
    throw new Error(
      "Upgrade bases must include the tracked stable version and package ID."
    );
  }
  return bases;
}

export function selectUpgradeBase(matrix, releases, id) {
  const base = releaseUpgradeBases(matrix, releases).find(
    (b) => b.subscriberPackageVersionId === id
  );
  if (!base)
    throw new Error("Upgrade base is not in the reviewed release matrix.");
  return base;
}
