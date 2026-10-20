import assert from "node:assert/strict";
import test from "node:test";
import { refreshedCheckActionCount } from "../../tests/browser/lifecycle.mjs";

const evaluate = (source) => ({
  descriptor: "apex://RecordHealthCheckController/ACTION$evaluateCheckJson",
  params: { source }
});
const request = (actions, { method = "POST", url = "/aura?r=1" } = {}) => ({
  method: () => method,
  url: () => `https://example.invalid${url}`,
  postData: () =>
    new URLSearchParams({ message: JSON.stringify({ actions }) }).toString()
});

test("counts every page-load evaluation in a finished Aura request", () => {
  assert.equal(
    refreshedCheckActionCount(
      request([
        evaluate("RUN_ON_LOAD"),
        evaluate("RUN_ON_LOAD"),
        {
          descriptor: "aura://ApexActionController/ACTION$execute",
          params: {
            method: "evaluateCheckJson",
            params: { source: "RUN_ON_LOAD" }
          }
        }
      ])
    ),
    3
  );
});

test("generic Aura traffic and user runs are not refresh evidence", () => {
  const cases = {
    "definition reload": request([
      {
        descriptor:
          "apex://RecordHealthCheckController/ACTION$getCheckDefinitions",
        params: { source: "RUN_ON_LOAD" }
      }
    ]),
    "user-initiated run": request([evaluate("USER_INITIATED")]),
    "GET request": request([evaluate("RUN_ON_LOAD")], { method: "GET" }),
    "non-Aura POST": request([evaluate("RUN_ON_LOAD")], { url: "/services" }),
    "Aura POST without a message": {
      method: () => "POST",
      url: () => "https://example.invalid/aura",
      postData: () => null
    }
  };
  for (const [label, finished] of Object.entries(cases)) {
    assert.equal(refreshedCheckActionCount(finished), 0, label);
  }
});
