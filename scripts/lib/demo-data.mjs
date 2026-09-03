import { paths } from "./paths.mjs";
import { tryRun } from "./run.mjs";

/** Keep setup-object User DML separate from business-data DML. */
export function seedDemoData(alias, execute = tryRun) {
  function step(name) {
    console.log(`Running demo lifecycle step ${name}...`);
    const result = execute("sf", [
      "apex",
      "run",
      "--target-org",
      alias,
      "--file",
      `${paths.subscriberData}/${name}`,
      "--json"
    ]);
    let payload;
    try {
      payload = JSON.parse(result.stdout);
    } catch {
      throw new Error(
        result.stderr || result.stdout || `Could not run ${name}`
      );
    }
    if (
      result.status !== 0 ||
      payload.status !== 0 ||
      !payload.result?.success
    ) {
      throw new Error(
        `${name}: ${payload.message ?? payload.result?.exceptionMessage ?? result.stderr}`
      );
    }
    for (const line of (payload.result.logs ?? "").split("\n")) {
      if (line.includes("|USER_DEBUG|") && line.includes("RHC_"))
        console.log(line);
    }
  }
  step("setupDemoUser.apex");
  try {
    step("setupDemoData.apex");
    step("setupReadinessData.apex");
  } finally {
    // Do not leave the synthetic user active if a data step fails.
    step("deactivateDemoUser.apex");
  }
}
