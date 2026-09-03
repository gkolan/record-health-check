import { expect, test } from "@playwright/test";

const restrictedUrl = process.env.RHC_RESTRICTED_BROWSER_URL;
const COMPONENT_SELECTOR = "c-record-health-check, rhc-record-health-check";

if (!restrictedUrl) {
  throw new Error(
    "RHC_RESTRICTED_BROWSER_URL is required; restricted-persona validation cannot skip."
  );
}

function completedCounts(text) {
  const match = text?.match(/Completed Checks:\s*(\d+)\s*\/\s*(\d+)/);
  return match ? { complete: Number(match[1]), total: Number(match[2]) } : null;
}

async function expectCompleted(card, total) {
  await expect
    .poll(async () => {
      const counts = completedCounts(await card.textContent());
      return counts?.complete === total && counts.total === total;
    })
    .toBe(true);
}

test("runs safely for a Card User without diagnostic access", async ({
  page
}) => {
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  await page.goto(restrictedUrl, { waitUntil: "domcontentloaded" });

  const components = page.locator(COMPONENT_SELECTOR);
  await expect(components).toHaveCount(2);
  const manualCard = components.filter({
    hasText: "Example: Account Check Builder Guide"
  });
  const automaticCard = components.filter({
    hasText: "Automated Account Data Quality and Customer Readiness Review"
  });
  await expectCompleted(automaticCard, 4);
  const expectedPassed = Number(process.env.RHC_EXPECTED_AUTOMATIC_PASSED);
  expect([3, 4]).toContain(expectedPassed);
  await expect(automaticCard).toContainText(`${expectedPassed} Passed`);
  if (expectedPassed === 3) await expect(automaticCard).toContainText("1 Info");
  await expect(
    automaticCard.locator(
      ".rhc-status-icon--unable, .rhc-status-icon--system-error"
    )
  ).toHaveCount(0);

  const runButton = manualCard.getByRole("button", { name: /^Run$/ });
  await expect(runButton).toBeEnabled();
  await runButton.click();
  await expectCompleted(manualCard, 25);

  await expect(components.locator("lightning-spinner")).toHaveCount(0);
  await expect(components.locator(".slds-spinner_container")).toHaveCount(0);
  await expect(page.getByText("Administrator detail:")).toHaveCount(0);
  await expect(page.getByText("A Component Error has occurred")).toHaveCount(0);
  await expect(page.getByText("Invalid contextElement")).toHaveCount(0);
  expect(pageErrors).toEqual([]);
});
