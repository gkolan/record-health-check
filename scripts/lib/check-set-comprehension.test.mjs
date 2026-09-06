import assert from "node:assert/strict";
import test from "node:test";
import {
  comprehensionFindings,
  MAX_LABEL,
  PURPOSES,
  TIER_A,
  TIER_B,
  TIER_B_SETS
} from "./check-set-comprehension.mjs";

const subtitle =
  "A sentence long enough to say what the reader will actually see on this card.";
const card = (api, title, label = title) => ({ api, label, title, subtitle });
const check = (api, set, fields) => ({ api, set, fields: new Set(fields) });
const fullTierA = check("C", "Account_Query_Coverage", TIER_A);

test("every declared purpose is one the prefix table knows", () => {
  for (const [api, purpose] of Object.entries(PURPOSES)) {
    assert.ok(
      ["example", "coverage", "diagnostics", "review", "business"].includes(
        purpose
      ),
      `${api} has an unknown purpose ${purpose}`
    );
  }
  for (const set of TIER_B_SETS) {
    assert.ok(PURPOSES[set], `${set} is Tier B but is not declared`);
  }
});

test("an undeclared Check Set is reported rather than silently accepted", () => {
  const findings = comprehensionFindings(
    [card("Account_Brand_New", "Coverage: Something")],
    []
  );
  assert.match(
    findings.join("\n"),
    /not declared in the Check Set purpose table/
  );
});

test("a card titled for its mechanism instead of its kind is reported", () => {
  const findings = comprehensionFindings(
    [card("Account_Query_Coverage", "Icon-Only Run and Rerun")],
    []
  );
  assert.match(findings.join("\n"), /must start "Coverage:"/);
});

test("a business card may not borrow another kind's prefix", () => {
  const findings = comprehensionFindings(
    [card("Account_Data_Quality", "Diagnostics: Account Data Quality")],
    []
  );
  assert.match(findings.join("\n"), /must name the subject rather than start/);
});

test("two cards with the same title are reported once, naming both", () => {
  const findings = comprehensionFindings(
    [
      card("Account_Data_Quality", "Same Name"),
      card("Release_On_Load", "Same Name")
    ],
    []
  );
  assert.equal(findings.length, 1);
  assert.match(findings[0], /Release_On_Load and Account_Data_Quality/);
});

test("a subtitle too short to be a sentence is reported", () => {
  const findings = comprehensionFindings(
    [{ api: "Release_On_Load", title: "Automatic Run", subtitle: "On load." }],
    []
  );
  assert.match(findings.join("\n"), /Card Subtitle is 8 characters/);
});

test("an over-long title is reported with its length", () => {
  const findings = comprehensionFindings(
    [card("Release_On_Load", "A".repeat(61))],
    []
  );
  assert.match(findings.join("\n"), /Card Title is 61 characters/);
});

test("Tier A applies to every Check, on any kind of card", () => {
  const findings = comprehensionFindings(
    [],
    [check("C", "Account_Query_Coverage", ["CheckTitle__c"])]
  );
  assert.match(findings.join("\n"), /missing CheckDescription__c/);
});

test("Tier B applies only on the cards an administrator copies", () => {
  assert.deepEqual(comprehensionFindings([], [fullTierA]), []);
  const findings = comprehensionFindings(
    [],
    [check("C", "Account_Everyday_Use_Cases", TIER_A)]
  );
  assert.equal(findings.length, 1);
  for (const field of TIER_B) assert.match(findings[0], new RegExp(field));
});

test("a fully populated card produces no findings", () => {
  assert.deepEqual(
    comprehensionFindings(
      [card("Account_Query_Coverage", "Coverage: Query Check Operators")],
      [
        fullTierA,
        check("D", "Account_Everyday_Use_Cases", [...TIER_A, ...TIER_B])
      ]
    ),
    []
  );
});

test("a record label that reworded the title is reported", () => {
  const findings = comprehensionFindings(
    [
      card(
        "Example_Account_Query",
        "Example: Account Query Checks",
        "Example: Account Query"
      )
    ],
    [fullTierA]
  );
  assert.equal(findings.length, 1);
  assert.match(findings[0], /must be exactly it/);
});

test("a title too long to be a label may be cut short, but not reworded", () => {
  const long = "Coverage: Query Check Operators and Outcomes";
  assert.ok(long.length > MAX_LABEL);
  assert.deepEqual(
    comprehensionFindings(
      [card("Account_Query_Coverage", long, "Coverage: Query Check Operators")],
      [fullTierA]
    ),
    []
  );
  const findings = comprehensionFindings(
    [card("Account_Query_Coverage", long, "Coverage: Query Operators")],
    [fullTierA]
  );
  assert.equal(findings.length, 1);
  assert.match(findings[0], /must be the start of it/);
});
