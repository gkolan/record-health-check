const compareVersions = (left, right) => {
  const leftParts = left.split(".").map(Number);
  const rightParts = right.split(".").map(Number);
  for (let index = 0; index < 3; index += 1) {
    if (leftParts[index] !== rightParts[index]) {
      return leftParts[index] - rightParts[index];
    }
  }
  return 0;
};

/**
 * Returns every place the development version disagrees with package
 * metadata or would sit below an already released version.
 */
export function versionSyncErrors({
  productVersion,
  packageLock,
  releaseRegistry,
  packageDirectory,
  frameworkVersion
}) {
  const expectedVersionNumber = `${productVersion}.NEXT`;
  const expectedVersionName = `Version ${productVersion}`;
  const failures = [];
  if (!/^\d+\.\d+\.\d+$/.test(productVersion)) {
    failures.push(
      `package.json version must use major.minor.patch format; found "${productVersion}".`
    );
  }
  if (packageLock.version !== productVersion) {
    failures.push(
      `package-lock.json version must be "${productVersion}"; found "${packageLock.version}".`
    );
  }
  if (packageLock.packages?.[""]?.version !== productVersion) {
    failures.push(
      `package-lock.json root package version must be "${productVersion}"; found "${packageLock.packages?.[""]?.version}".`
    );
  }
  const releasedVersions = [
    releaseRegistry.stable?.version,
    releaseRegistry.previous?.version,
    releaseRegistry.candidate?.status === "released"
      ? releaseRegistry.candidate.version
      : null
  ]
    .filter(Boolean)
    .map((version) => version.split(".").slice(0, 3).join("."));
  const latestReleasedVersion = releasedVersions.sort(compareVersions).at(-1);
  if (
    latestReleasedVersion &&
    /^\d+\.\d+\.\d+$/.test(productVersion) &&
    compareVersions(productVersion, latestReleasedVersion) < 0
  ) {
    failures.push(
      `development version ${productVersion} must not be older than released version ${latestReleasedVersion}. A matching semantic version is permitted for a higher 2GP hotfix build.`
    );
  }
  if (packageDirectory.versionNumber !== expectedVersionNumber) {
    failures.push(
      `versionNumber must be "${expectedVersionNumber}"; found "${packageDirectory.versionNumber}".`
    );
  }
  if (packageDirectory.versionName !== expectedVersionName) {
    failures.push(
      `versionName must be "${expectedVersionName}"; found "${packageDirectory.versionName}".`
    );
  }
  if (frameworkVersion !== productVersion) {
    failures.push(
      `RecordHealthCheckLifecyclePublisher.FRAMEWORK_VERSION must be "${productVersion}"; found "${frameworkVersion ?? "missing"}".`
    );
  }
  return failures;
}
