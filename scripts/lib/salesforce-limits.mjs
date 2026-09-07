import { runJson } from "./run.mjs";

function requiredLimit(records, name) {
  const limit = records.find((entry) => entry.name === name);
  if (!limit) {
    throw new Error(`Dev Hub did not return the ${name} limit.`);
  }
  return limit;
}

export function formatScratchCapacity(devHub, active, daily) {
  const activeUsed = active.max - active.remaining;
  const dailyUsed = daily.max - daily.remaining;
  return (
    `Scratch-org capacity on ${devHub}: ` +
    `${activeUsed} of ${active.max} active orgs are in use; ` +
    `${active.remaining} active slots are available. ` +
    `Today, ${dailyUsed} of ${daily.max} creations have been used; ` +
    `${daily.remaining} creations are available.`
  );
}

export function assertScratchCapacity(devHub, required = 1) {
  const payload = runJson("sf", [
    "limits",
    "api",
    "display",
    "--target-org",
    devHub
  ]);
  const records = payload.result ?? [];
  const active = requiredLimit(records, "ActiveScratchOrgs");
  const daily = requiredLimit(records, "DailyScratchOrgs");
  const capacity = formatScratchCapacity(devHub, active, daily);

  if (active.remaining < required || daily.remaining < required) {
    console.error(`${capacity} This stage requires ${required} fresh orgs.`);
    console.error(
      "Reuse or delete an existing project org when appropriate, or wait for the daily limit to reset."
    );
    process.exit(1);
  }

  console.log(`${capacity} This stage requires ${required} fresh orgs.`);
}

export function assertPackageVersionCapacity(devHub) {
  const payload = runJson("sf", [
    "limits",
    "api",
    "display",
    "--target-org",
    devHub
  ]);
  const limit = requiredLimit(payload.result ?? [], "Package2VersionCreates");
  if (limit.remaining < 1) {
    console.error(
      `No validated 2GP package-version creates remain today on ${devHub} (${limit.remaining}/${limit.max}).`
    );
    process.exit(1);
  }
  console.log(
    `2GP package-version capacity confirmed on ${devHub}: ${limit.remaining}/${limit.max} creates remain.`
  );
  return limit;
}
