import assert from "node:assert/strict";
import test from "node:test";
import { isKnownFirefoxBuilderShellErrors } from "./salesforce-browser-errors.mjs";

const primary = {
  name: "uncaught exception",
  message: "Object",
  stack:
    "uncaught exception: Object\n" +
    "at _getServerData/</< (https://b.static.lightning.force.com/usa488s.sfdc/aura/%7B%7D/hash/apppart2-4.js:1356:5)\n" +
    "at b (https://b.static.lightning.force.com/usa488s.sfdc/auraFW/javascript/hash/aura_prod.js:1050:72)"
};
const duplicate = {
  name: "uncaught exception",
  message: "Object",
  stack: "uncaught exception: Object\n"
};

test("accepts the known Firefox App Builder shell error across numeric Salesforce asset shards", () => {
  assert.equal(
    isKnownFirefoxBuilderShellErrors("firefox", [primary, duplicate]),
    true
  );
});

test("rejects a similar error outside Salesforce static assets", () => {
  assert.equal(
    isKnownFirefoxBuilderShellErrors("firefox", [
      {
        ...primary,
        stack: primary.stack.replace(
          "b.static.lightning.force.com",
          "example.invalid"
        )
      },
      duplicate
    ]),
    false
  );
});

test("rejects component or non-Firefox errors", () => {
  assert.equal(
    isKnownFirefoxBuilderShellErrors("chromium", [primary, duplicate]),
    false
  );
  assert.equal(
    isKnownFirefoxBuilderShellErrors("firefox", [
      primary,
      { ...duplicate, message: "Component failure" }
    ]),
    false
  );
});
