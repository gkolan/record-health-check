import assert from "node:assert/strict";
import test from "node:test";
import { releaseUpgradeBases, selectUpgradeBase } from "./release-upgrades.mjs";

test("upgrade coverage accepts only the exact immediately preceding release", () => {
  const stable = {
    version: "2.0.6.2",
    subscriberPackageVersionId: "04t000000000001AAA"
  };
  const matrix = {
    candidateVersion: "2.0.7.1",
    upgradeFromVersion: stable.version,
    upgradeBases: [stable]
  };
  assert.equal(releaseUpgradeBases(matrix, { stable }).length, 1);
  const published = {
    stable: {
      version: matrix.candidateVersion,
      subscriberPackageVersionId: "04t000000000003AAA"
    },
    previous: stable
  };
  assert.equal(releaseUpgradeBases(matrix, published).length, 1);
  assert.throws(() =>
    releaseUpgradeBases(matrix, { stable: published.stable })
  );
  assert.deepEqual(
    selectUpgradeBase(matrix, { stable }, stable.subscriberPackageVersionId),
    stable
  );
  assert.throws(() =>
    selectUpgradeBase(matrix, { stable }, "04t000000000003AAA")
  );
  assert.throws(() =>
    releaseUpgradeBases({ ...matrix, upgradeBases: [] }, { stable })
  );
  assert.throws(() =>
    releaseUpgradeBases(
      {
        ...matrix,
        upgradeBases: [
          stable,
          {
            version: "2.0.4.2",
            subscriberPackageVersionId: "04t000000000002AAA"
          }
        ]
      },
      { stable }
    )
  );
});
