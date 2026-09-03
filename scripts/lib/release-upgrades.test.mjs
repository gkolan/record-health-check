import assert from "node:assert/strict";
import test from "node:test";
import { releaseUpgradeBases, selectUpgradeBase } from "./release-upgrades.mjs";

test("upgrade coverage includes exact stable and legacy IDs without accepting arbitrary versions", () => {
  const stable = {
    version: "2.0.6.2",
    subscriberPackageVersionId: "04t000000000001AAA"
  };
  const legacy = {
    version: "2.0.4.2",
    subscriberPackageVersionId: "04t000000000002AAA"
  };
  const matrix = {
    candidateVersion: "2.0.7.1",
    upgradeFromVersion: stable.version,
    upgradeBases: [stable, legacy]
  };
  assert.equal(releaseUpgradeBases(matrix, { stable }).length, 2);
  const published = {
    stable: {
      version: matrix.candidateVersion,
      subscriberPackageVersionId: "04t000000000003AAA"
    },
    previous: stable
  };
  assert.equal(releaseUpgradeBases(matrix, published).length, 2);
  assert.throws(() =>
    releaseUpgradeBases(matrix, { ...published, previous: legacy })
  );
  assert.throws(() =>
    releaseUpgradeBases(matrix, { stable: published.stable })
  );
  assert.deepEqual(
    selectUpgradeBase(matrix, { stable }, legacy.subscriberPackageVersionId),
    legacy
  );
  assert.throws(() =>
    selectUpgradeBase(matrix, { stable }, "04t000000000003AAA")
  );
  assert.throws(() =>
    releaseUpgradeBases({ ...matrix, upgradeBases: [legacy] }, { stable })
  );
  assert.throws(() =>
    releaseUpgradeBases(
      { ...matrix, upgradeBases: [stable, stable] },
      { stable }
    )
  );
});
