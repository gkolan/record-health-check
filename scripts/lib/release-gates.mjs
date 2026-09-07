/**
 * The one declaration of the named source gates. Both the local release
 * preflight and hosted CI run this list, so neither can drift from the other.
 *
 * The toolchain gate is the single deliberate difference: locally the preflight
 * verifies the pinned Salesforce CLI is still the official latest release;
 * hosted CI verifies the pinned policy without a mutable registry lookup.
 */
export const sourceGates = [
  "prettier:verify",
  "lint",
  "lint:slds",
  "lint:python",
  "lint:workflows",
  "check:namespaced-tokens",
  "check:configuration-identity",
  "check:lightning-runtime-compatibility",
  "check:hosted-validation:self-test",
  "check:release-runtime-matrix",
  "check:dependency-security",
  "check:agent-tool-contract",
  "check:mcp",
  "check:test-data-factory",
  "check:test-data-factory-inventory",
  "check:apex-architecture",
  "check:apex-surface",
  "check:code-analyzer-output-paths",
  "check:code-analyzer-suppressions",
  "check:code-analyzer-inline-suppressions",
  "check:plugin-sharing",
  "check:version-sync",
  "check:product-version-language",
  "check:docs",
  "check:ai-prompts",
  "check:field-limits",
  "check:check-set-comprehension",
  "check:fixture-value-coverage",
  "check:manifest",
  "check:package-artifact",
  "check:package-boundary",
  "check:query-shapes",
  "check:distribution-boundary",
  "check:permission-sets",
  "check:xml",
  "test:scripts",
  "test:unit:coverage",
  "check:quality-metrics"
];

/**
 * Optional release-only gates belong here when they are deterministic and do
 * not depend on a vendor credential. AI drafting evidence is instead recorded
 * deliberately when its prompts change; `check:ai-prompts` remains a mandatory
 * source gate and rejects missing, stale, or invalid committed evidence.
 */
export const releaseGates = [];

/**
 * Narrows `gates` to the exactly-named `requested` gates, preserving the
 * declared run order.
 *
 * Names must match a declared gate exactly. Substring matching would silently
 * change which gates ran as the list grows - "check:code-analyzer" alone
 * matches three gates today - so an unknown name is an error that names the
 * valid gates rather than a filter that quietly selects nothing.
 *
 * @param {string[]} gates Declared gates, in run order.
 * @param {string[]} requested Exact gate names to keep.
 * @returns {string[]} The requested gates in declared order.
 */
export function selectGates(gates, requested) {
  const wanted = requested.map((name) => name.trim()).filter(Boolean);
  if (wanted.length === 0) {
    throw new Error("--only needs at least one gate name.");
  }
  const unknown = wanted.filter((name) => !gates.includes(name));
  if (unknown.length > 0) {
    throw new Error(
      `Unknown gate name(s): ${unknown.join(", ")}.\n` +
        `Run with --list to print every gate name for this environment.`
    );
  }
  return gates.filter((gate) => wanted.includes(gate));
}

/** Propagates explicit CI mode so child gates cannot mistake it for a local run. */
export function gateEnvironment(environment, baseEnvironment = process.env) {
  return environment === "ci"
    ? { ...baseEnvironment, CI: "true" }
    : { ...baseEnvironment };
}

/** Returns every gate to run, toolchain gate first. */
export function gatesFor(environment) {
  const toolchainGate =
    environment === "ci" ? "check:toolchain-policy" : "check:toolchain-latest";
  return environment === "ci"
    ? [toolchainGate, ...sourceGates]
    : [toolchainGate, ...sourceGates, ...releaseGates];
}
