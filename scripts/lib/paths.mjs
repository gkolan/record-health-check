import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);

export const paths = {
  repoRoot,
  packageRoot: path.join(repoRoot, "packages/record-health-check"),
  forceApp: path.join(repoRoot, "packages/record-health-check/force-app"),
  integrationTests: path.join(
    repoRoot,
    "packages/record-health-check/integration-tests"
  ),
  manifest: path.join(repoRoot, "packages/record-health-check/manifest"),
  packageProject: path.join(
    repoRoot,
    "packages/record-health-check/sfdx-project.json"
  ),
  subscriberApp: path.join(repoRoot, "subscriber-app"),
  demoMetadata: path.join(repoRoot, "scripts/demo/metadata"),
  packageReleases: path.join(repoRoot, "config/package-releases.json"),
  subscriberScratchDef: path.join(
    repoRoot,
    "config/subscriber-scratch-def.json"
  ),
  lockerScratchDef: path.join(repoRoot, "config/locker-scratch-def.json"),
  packageScratchDef: path.join(
    repoRoot,
    "packages/record-health-check/config/project-scratch-def.json"
  ),
  subscriberData: path.join(repoRoot, "scripts/subscriber/data")
};
