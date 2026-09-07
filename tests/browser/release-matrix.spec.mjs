import { expect, test } from "@playwright/test";
import { exerciseRefreshAndNavigation } from "./lifecycle.mjs";

const COMPONENT_FAILURES = [
  "A Component Error has occurred",
  "Component failed to display",
  "Invalid contextElement",
  "Must be an HTMLElement or LightningElement"
];
const releasePageUrl = process.env.RHC_BROWSER_URL;
const securityMode = process.env.RHC_SECURITY_MODE;
const COMPONENT_SELECTOR = "c-record-health-check, rhc-record-health-check";

if (!releasePageUrl) {
  throw new Error(
    "RHC_BROWSER_URL is required; browser validation cannot skip."
  );
}
if (!["LWS", "Locker"].includes(securityMode)) {
  throw new Error("RHC_SECURITY_MODE must be LWS or Locker.");
}

function completedCounts(text) {
  const match = text?.match(/Completed Checks:\s*(\d+)\s*\/\s*(\d+)/);
  return match ? { complete: Number(match[1]), total: Number(match[2]) } : null;
}

// Spinners inside the card that are not the card's own load slot. Counted in
// one page-side pass so a spinner that settles mid-check cannot be read as a
// stray one.
function strayCardSpinners(components) {
  return components.evaluateAll((hosts) =>
    hosts.reduce((count, host) => {
      const root = host.shadowRoot ?? host;
      const spinners = root.querySelectorAll(
        "lightning-spinner, .slds-spinner_container"
      );
      return (
        count +
        [...spinners].filter((node) => !node.closest(".rhc-card-loading"))
          .length
      );
    }, 0)
  );
}

// Salesforce page-level loading overlays. Under Lightning Web Security the
// card's own spinner sits in a shadow root a document query does not reach;
// under Locker's synthetic shadow the component ancestor test excludes it.
function pageLevelSpinners(page) {
  return page.evaluate(
    () =>
      [...globalThis.document.querySelectorAll(".slds-spinner_container")]
        .filter((node) => node.getBoundingClientRect().height > 0)
        .filter(
          (node) =>
            !node.closest("c-record-health-check, rhc-record-health-check")
        ).length
  );
}

async function expectRunCompleted(card, expectedTotal) {
  await expect
    .poll(async () => {
      const counts = completedCounts(await card.textContent());
      return Boolean(
        counts &&
        counts.total === expectedTotal &&
        counts.complete === counts.total
      );
    })
    .toBe(true);
}

test("renders manual and on-load cards without a component or page-loading failure", async ({
  page
}, testInfo) => {
  await testInfo.attach("salesforce-security-mode", {
    body: securityMode,
    contentType: "text/plain"
  });

  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  await page.goto("", { waitUntil: "domcontentloaded" });
  const components = page.locator(COMPONENT_SELECTOR);
  await expect(components).toHaveCount(2);

  const manualCard = components.filter({
    hasText: "Example: Account Check Builder Guide"
  });
  const automaticCard = components.filter({
    hasText: "Automatic Account Review on Page Load"
  });

  await expect(manualCard).toHaveCount(1);
  await expect(automaticCard).toHaveCount(1);

  // The card's own load slot is the one spinner RHC may raise before a
  // deliberate click (docs/architecture/record-page-card-contract.md). Any
  // other spinner in the card, and any Salesforce page-level loading overlay,
  // is still a failure. Progress that follows a click is kept inside the
  // clicked action button and is checked separately below.
  for (let sample = 0; sample < 60; sample += 1) {
    expect(await strayCardSpinners(components)).toBe(0);
    expect(await pageLevelSpinners(page)).toBe(0);
    await page.waitForTimeout(100);
  }

  await expectRunCompleted(automaticCard, 4);
  const expectedPassed = Number(process.env.RHC_EXPECTED_AUTOMATIC_PASSED);
  expect([3, 4]).toContain(expectedPassed);
  await expect(automaticCard).toContainText(`${expectedPassed} Passed`);
  if (expectedPassed === 3) await expect(automaticCard).toContainText("1 Info");
  await expect(
    automaticCard.locator(
      ".rhc-status-icon--unable, .rhc-status-icon--system-error"
    )
  ).toHaveCount(0);
  await expect(automaticCard.getByRole("button", { name: /run/i })).toHaveCount(
    0
  );

  const runButton = manualCard.getByRole("button", { name: /^Run$/ });
  await expect(runButton).toBeEnabled();
  await runButton.click();
  await expectRunCompleted(manualCard, 25);

  // The load slot hands over and disappears; it must not outlive the load.
  await expect(components.locator(".rhc-card-loading")).toHaveCount(0);

  await exerciseRefreshAndNavigation(page);

  for (const failure of COMPONENT_FAILURES) {
    await expect(page.getByText(failure, { exact: false })).toHaveCount(0);
  }
  expect(pageErrors).toEqual([]);
});
