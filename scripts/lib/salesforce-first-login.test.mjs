import assert from "node:assert/strict";
import test from "node:test";
import {
  completeScratchUserFirstLogin,
  firstLoginState,
  isLightningHome
} from "./salesforce-first-login.mjs";

const origin = "https://example.invalid";
const home = `${origin}/lightning/page/home`;
const change = `${origin}/_ui/system/security/ChangePassword?retURL=%2Flightning%2Fpage%2Fhome`;
const credentials = {
  currentPassword: "fake-current",
  newPassword: "fake-new"
};
const options = { timeout: 200, intervals: [1, 2, 5] };

function fakePage(states, destination = home) {
  const fields = [
    "* Current Password",
    "New Password",
    "Confirm New Password *",
    "* New Answer"
  ];
  let state = states[0];
  let probes = 0;
  let clicks = 0;
  const filled = [];
  return {
    filled,
    probes: () => probes,
    clicks: () => clicks,
    url: () => state.url,
    getByLabel(pattern) {
      const matching = fields.filter((field) => pattern.test(field));
      assert.equal(matching.length, 1);
      return {
        async isVisible() {
          state = states[Math.min(probes++, states.length - 1)];
          return state.visible;
        },
        async fill(value) {
          assert.equal(state.visible, true);
          filled.push([matching[0], value]);
        }
      };
    },
    getByRole(role, { name }) {
      assert.equal(role, "button");
      assert.ok(name.test("Change Password"));
      return {
        async click() {
          clicks++;
          state = { url: destination, visible: false };
        }
      };
    },
    async waitForURL(predicate) {
      assert.ok(
        predicate(new URL(state.url)),
        "Post-submit destination is not Lightning Home"
      );
    }
  };
}

test("waits through frontdoor and a delayed password form before completing setup", async () => {
  const page = fakePage([
    { url: `${origin}/secur/frontdoor.jsp`, visible: false },
    { url: change, visible: false },
    { url: change, visible: true }
  ]);
  await completeScratchUserFirstLogin(page, credentials, options);
  assert.equal(page.probes(), 3);
  assert.equal(page.clicks(), 1);
  assert.deepEqual(
    page.filled.map(([, value]) => value),
    ["fake-current", "fake-new", "fake-new", "Chicago"]
  );
});

test("waits for an already initialized user without changing credentials", async () => {
  const page = fakePage([
    { url: `${origin}/secur/contentDoor`, visible: false },
    { url: home, visible: false }
  ]);
  await completeScratchUserFirstLogin(page, credentials, options);
  assert.equal(page.clicks(), 0);
  assert.equal(page.filled.length, 0);
});

test("a Home return URL inside a redirect or password page is not success", () => {
  for (const url of [
    change,
    `${origin}/login?retURL=/lightning/page/home`,
    "about:blank",
    "invalid"
  ]) {
    assert.equal(firstLoginState(url, false), "pending");
  }
  assert.equal(firstLoginState(change, true), "password-change");
  assert.ok(isLightningHome(`${home}/?x=1`));
  assert.ok(!isLightningHome(`${home}-error`));
});

test("unknown or permanently loading pages fail closed without filling credentials", async () => {
  const page = fakePage([{ url: change, visible: false }]);
  await assert.rejects(
    completeScratchUserFirstLogin(page, credentials, {
      timeout: 30,
      intervals: [1]
    })
  );
  assert.equal(page.filled.length, 0);
});

test("post-submit login and password-error destinations do not pass", async () => {
  for (const destination of [change, `${origin}/login`, `${origin}/error`]) {
    const page = fakePage([{ url: change, visible: true }], destination);
    await assert.rejects(
      completeScratchUserFirstLogin(page, credentials, options),
      /not Lightning Home/
    );
  }
});
