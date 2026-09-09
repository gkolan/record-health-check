import assert from "node:assert/strict";
import test from "node:test";

import {
  checkPluginInterfaceBoundaries,
  maskApexNonCode
} from "./plugin-interface-boundary.mjs";

const safeDispatch = `
  Object instance;
  Exception constructionFailure;
  try { instance = pluginType.newInstance(); } catch (Exception ex) {
    constructionFailure = ex;
  }
  if (constructionFailure != null) { throw constructionFailure; }
  try {
    return (RecordHealthCheckPlugin) instance;
  } catch (TypeException ex) {
    return null;
  }
`;

const safeResolver = `
  RecordHealthCheckPlugin instance = RecordHealthCheckConfigValidator.takeValidatedPlugin(check);
  if (instance == null) {
    instance = RecordHealthCheckPluginDispatch.instantiate(evaluatorType);
  }
  return requireCheck(instance);
`;

test("the safe guarded-cast boundary passes", () => {
  assert.deepEqual(
    checkPluginInterfaceBoundaries({
      dispatchSource: safeDispatch,
      resolverSource: safeResolver
    }),
    []
  );
});

test("restoring only the dispatcher instanceof guard fails", () => {
  const findings = checkPluginInterfaceBoundaries({
    dispatchSource:
      safeDispatch +
      "return instance instanceof RecordHealthCheckPlugin ? (RecordHealthCheckPlugin) instance : null;",
    resolverSource: safeResolver
  });
  assert.equal(
    findings.filter((finding) => finding.includes("not instanceof")).length,
    1
  );
  assert.match(findings[0], /PluginDispatch/);
});

test("restoring only the resolver instanceof guard fails", () => {
  const findings = checkPluginInterfaceBoundaries({
    dispatchSource: safeDispatch,
    resolverSource:
      safeResolver +
      "if (!(instance instanceof RecordHealthCheckPlugin)) { return null; }"
  });
  assert.equal(
    findings.filter((finding) => finding.includes("not instanceof")).length,
    1
  );
  assert.match(findings[0], /PluginResolver/);
});

test("comments, strings, JSON checks, and exception checks remain permitted", () => {
  const dispatchSource = `${safeDispatch}
    // instance instanceof RecordHealthCheckPlugin is prohibited in executable code.
    String explanation = 'instance instanceof RecordHealthCheckPlugin';
    if (error instanceof ContractException) { throw error; }
  `;
  const resolverSource = `${safeResolver}
    /* instanceof RecordHealthCheckPlugin */
    if (!(parsed instanceof Map<String, Object>)) { return null; }
  `;
  assert.deepEqual(
    checkPluginInterfaceBoundaries({ dispatchSource, resolverSource }),
    []
  );
});

test("direct resolver construction is rejected", () => {
  const findings = checkPluginInterfaceBoundaries({
    dispatchSource: safeDispatch,
    resolverSource:
      safeResolver + "Object bypass = evaluatorType.newInstance();"
  });
  assert.ok(findings.some((finding) => finding.includes("must go through")));
});

test("the cast cannot precede constructor failure handling", () => {
  const findings = checkPluginInterfaceBoundaries({
    dispatchSource: safeDispatch.replace(
      "if (constructionFailure != null) { throw constructionFailure; }",
      ""
    ),
    resolverSource: safeResolver
  });
  assert.ok(findings.some((finding) => finding.includes("cast only after")));
});

test("masking preserves offsets and line breaks", () => {
  const source = "code // hidden\n'also hidden' tail";
  const masked = maskApexNonCode(source);
  assert.equal(masked.length, source.length);
  assert.equal(masked.split("\n").length, source.split("\n").length);
  assert.match(masked, /^code\s+\n\s+tail$/);
});
