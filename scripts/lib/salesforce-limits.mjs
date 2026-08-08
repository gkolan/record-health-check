import { runJson } from "./run.mjs";

function requiredLimit(records, name) {
  const limit = records.find((entry) => entry.name === name);
  if (!limit) {
    throw new Error(`Dev Hub did not return the ${name} limit.`);
  }
  return limit;
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

  if (active.remaining < required || daily.remaining < required) {
    console.error(
      `Scratch-org capacity is insufficient on ${devHub}: ` +
        `${active.remaining}/${active.max} active slots and ` +
        `${daily.remaining}/${daily.max} daily creates remain; ${required} required.`
    );
    console.error(
      "Reuse or delete an existing project org when appropriate, or wait for the daily limit to reset."
    );
    process.exit(1);
  }

  console.log(
    `Scratch-org capacity confirmed on ${devHub}: ` +
      `${active.remaining}/${active.max} active slots and ` +
      `${daily.remaining}/${daily.max} daily creates remain.`
  );
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
