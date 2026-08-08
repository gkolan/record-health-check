import fs from "node:fs";
import { paths } from "./paths.mjs";

export function readPackageReleases() {
  return JSON.parse(fs.readFileSync(paths.packageReleases, "utf8"));
}

export function stablePackageVersionId(releases = readPackageReleases()) {
  const id = releases?.stable?.subscriberPackageVersionId ?? "";
  if (!id.startsWith("04t")) {
    throw new Error(
      "config/package-releases.json stable.subscriberPackageVersionId must start with 04t"
    );
  }
  return id;
}

export function previousPackageVersionId(releases = readPackageReleases()) {
  const id = releases?.previous?.subscriberPackageVersionId ?? "";
  if (!id.startsWith("04t")) {
    throw new Error(
      "config/package-releases.json previous.subscriberPackageVersionId must start with 04t"
    );
  }
  return id;
}

export function namespacedPermissionSet(
  localName,
  releases = readPackageReleases()
) {
  const namespace = releases.namespace ?? "";
  if (!namespace || localName.includes("__")) {
    return localName;
  }
  return `${namespace}__${localName}`;
}
