#!/usr/bin/env node

import { parseArgs } from "node:util";
import { assertScratchCapacity } from "../lib/salesforce-limits.mjs";

const { values } = parseArgs({
  options: {
    "dev-hub": { type: "string", default: process.env.DEV_HUB_ALIAS ?? "" },
    required: { type: "string", default: "1" }
  }
});

if (!values["dev-hub"]) {
  console.error("Pass --dev-hub or set DEV_HUB_ALIAS.");
  process.exit(1);
}

const required = Number.parseInt(values.required, 10);
if (!Number.isInteger(required) || required < 1) {
  console.error("--required must be a positive integer.");
  process.exit(1);
}

assertScratchCapacity(values["dev-hub"], required);
