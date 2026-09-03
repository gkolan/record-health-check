import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

for (const file of [
  "packages/record-health-check/integration-tests/main/default/flows/RHC_Release_Matrix.flow-meta.xml",
  "subscriber-app/main/default/flows/RHC_Subscriber_Release_Matrix.flow-meta.xml"
]) {
  test(`${file} terminates unexpected action faults with explicit failure outputs`, () => {
    const xml = fs.readFileSync(
      new URL(`../../${file}`, import.meta.url),
      "utf8"
    );
    const actions = [
      ...xml.matchAll(/<actionCalls>([\s\S]*?)<\/actionCalls>/g)
    ];
    assert.equal(actions.length, 2);
    for (const [, action] of actions) {
      assert.match(
        action,
        /<faultConnector>\s*<targetReference>Handle_Action_Fault<\/targetReference>\s*<\/faultConnector>/
      );
      assert.match(action, /<description[\s>]/);
    }
    const handler = xml.match(/<assignments>([\s\S]*?)<\/assignments>/)?.[1];
    assert.ok(handler);
    assert.match(handler, /<name>Handle_Action_Fault<\/name>/);
    assert.doesNotMatch(handler, /<connector>/);
    const items = new Map(
      [
        ...handler.matchAll(
          /<assignmentItems>\s*<assignToReference>([^<]+)<\/assignToReference>\s*<operator>Assign<\/operator>\s*<value>\s*<([^>]+)>([^<]+)<\/[^>]+>\s*<\/value>\s*<\/assignmentItems>/g
        )
      ].map(([, name, type, value]) => [name, [type.trim(), value]])
    );
    for (const prefix of ["check", "set"]) {
      assert.deepEqual(items.get(`${prefix}IsSuccess`), [
        "booleanValue",
        "false"
      ]);
      assert.deepEqual(items.get(`${prefix}Status`), ["stringValue", "ERROR"]);
      assert.deepEqual(items.get(`${prefix}ErrorType`), [
        "stringValue",
        "FLOW_FAULT"
      ]);
    }
    assert.deepEqual(items.get("flowFaultMessage"), [
      "elementReference",
      "$Flow.FaultMessage"
    ]);
    for (const [, variable] of xml.matchAll(
      /<variables>([\s\S]*?)<\/variables>/g
    )) {
      assert.match(variable, /<description[\s>]/);
    }
    // Parameters inherit FlowBaseElement, not FlowElement: descriptions are
    // invalid there even though the analyzer currently requests them.
    for (const [, parameter] of xml.matchAll(
      /<(?:inputParameters|outputParameters)>([\s\S]*?)<\/(?:inputParameters|outputParameters)>/g
    )) {
      assert.doesNotMatch(parameter, /<description[\s>]/);
    }
  });
}
