import fs from "node:fs";

import { checkPluginInterfaceBoundaries } from "../lib/plugin-interface-boundary.mjs";

const classRoot = "packages/record-health-check/force-app/main/default/classes";
const findings = checkPluginInterfaceBoundaries({
  dispatchSource: fs.readFileSync(
    `${classRoot}/RecordHealthCheckPluginDispatch.cls`,
    "utf8"
  ),
  resolverSource: fs.readFileSync(
    `${classRoot}/RecordHealthCheckApexPluginResolver.cls`,
    "utf8"
  )
});

if (findings.length > 0) {
  console.error(
    "Plugin interface boundary policy failed:\n- " + findings.join("\n- ")
  );
  process.exit(1);
}

console.log(
  "Plugin interface boundary policy passed: guarded cast retained and resolver construction remains protected."
);
