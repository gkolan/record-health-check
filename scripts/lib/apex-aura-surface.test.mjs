import assert from "node:assert/strict";
import test from "node:test";

import { auraEnabledStaticMethods } from "./apex-aura-surface.mjs";

test("finds static Aura methods however their declaration is laid out", () => {
  const source = `
    @AuraEnabled
    public static String plain(Id recordId) { return null; }
    @AuraEnabled(cacheable=true)
    global static Map<String, List<Object>> cached() { return null; }
    @AuraEnabled
    @TestVisible
    public static void annotated() {}
    @AuraEnabled // Reached by the card.
    public static void commented() {}
    @AuraEnabled
    /* Reached by the card. */
    static public void reordered() {}
  `;

  assert.deepEqual(auraEnabledStaticMethods(source), [
    "plain",
    "cached",
    "annotated",
    "commented",
    "reordered"
  ]);
});

test("ignores Aura properties, instance members and commented-out declarations", () => {
  const source = `
    @AuraEnabled public String label { get; set; }
    @AuraEnabled
    public String describe() { return null; }
    // @AuraEnabled public static void retired() {}
    /* @AuraEnabled
       public static void alsoRetired() {} */
    public static void notExposed() {}
  `;

  assert.deepEqual(auraEnabledStaticMethods(source), []);
});
