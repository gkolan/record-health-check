import { expect } from "@playwright/test";

const COMPONENT_SELECTOR = "c-record-health-check, rhc-record-health-check";

function completedCounts(text) {
  const match = text?.match(/Completed Checks:\s*(\d+)\s*\/\s*(\d+)/);
  return match ? { complete: Number(match[1]), total: Number(match[2]) } : null;
}

async function expectAutomaticRunCompleted(page) {
  const automaticCard = page.locator(COMPONENT_SELECTOR).filter({
    hasText: "Automated Account Data Quality and Customer Readiness Review"
  });
  await expect(automaticCard).toHaveCount(1);
  await expect
    .poll(async () => {
      const counts = completedCounts(await automaticCard.textContent());
      return Boolean(counts && counts.complete === 4 && counts.total === 4);
    })
    .toBe(true);
  await expect(automaticCard.locator("lightning-spinner")).toHaveCount(0);
  await expect(automaticCard.locator(".slds-spinner_container")).toHaveCount(0);
}

export async function exerciseRefreshAndNavigation(page) {
  const secondAccountId = process.env.RHC_SECOND_ACCOUNT_ID;
  const secondAccountName = process.env.RHC_SECOND_ACCOUNT_NAME;
  if (!secondAccountId || !secondAccountName) {
    throw new Error(
      "RHC_SECOND_ACCOUNT_ID and RHC_SECOND_ACCOUNT_NAME are required for lifecycle validation."
    );
  }

  let auraRequestsAfterSave = 0;
  const countAuraRequest = (request) => {
    if (request.method() === "POST" && request.url().includes("/aura")) {
      auraRequestsAfterSave += 1;
    }
  };
  page.on("request", countAuraRequest);

  const inlinePhoneEdit = page.locator('button[title="Edit Phone"]').first();
  if (await inlinePhoneEdit.isVisible().catch(() => false)) {
    await inlinePhoneEdit.click();
  } else {
    await page
      .getByRole("button", { name: "Edit", exact: true })
      .first()
      .click();
  }
  const dialog = page.getByRole("dialog");
  await expect(dialog).toBeVisible();
  await dialog.getByLabel("Phone", { exact: true }).fill("3125550199");
  auraRequestsAfterSave = 0;
  await dialog.getByRole("button", { name: "Save", exact: true }).click();
  await expect(dialog).toBeHidden();
  await expect.poll(() => auraRequestsAfterSave).toBeGreaterThanOrEqual(2);
  await expectAutomaticRunCompleted(page);
  page.off("request", countAuraRequest);

  const origin = new URL(page.url()).origin;
  await page.goto(`${origin}/lightning/o/Account/list?filterName=Recent`, {
    waitUntil: "domcontentloaded"
  });
  const navigationEntriesBeforeClick = await page.evaluate(
    () => performance.getEntriesByType("navigation").length
  );
  await page
    .getByRole("link", { name: secondAccountName, exact: true })
    .first()
    .click();
  await expect(page).toHaveURL(new RegExp(`/Account/${secondAccountId}/view`));
  const navigationEntriesAfterClick = await page.evaluate(
    () => performance.getEntriesByType("navigation").length
  );
  expect(navigationEntriesAfterClick).toBe(navigationEntriesBeforeClick);
  await expect(page.locator(COMPONENT_SELECTOR)).toHaveCount(2);
  await expectAutomaticRunCompleted(page);
}
