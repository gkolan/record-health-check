import { expect } from "@playwright/test";

const COMPONENT_SELECTOR = "c-record-health-check, rhc-record-health-check";

function completedCounts(text) {
  const match = text?.match(/Completed Checks:\s*(\d+)\s*\/\s*(\d+)/);
  return match ? { complete: Number(match[1]), total: Number(match[2]) } : null;
}

async function expectAutomaticRunCompleted(page) {
  const automaticCard = page.locator(COMPONENT_SELECTOR).filter({
    hasText: "Automatic Account Review on Page Load"
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
  const phoneInput = page.getByLabel("Phone", { exact: true });
  if (await inlinePhoneEdit.isVisible().catch(() => false)) {
    await inlinePhoneEdit.click();
  } else {
    const recordEdit = page
      .getByRole("button", { name: "Edit", exact: true })
      .first();
    await recordEdit.click();
    const openedFromAction = await phoneInput
      .waitFor({ state: "visible", timeout: 5000 })
      .then(() => true)
      .catch(() => false);
    if (!openedFromAction) {
      // Salesforce occasionally paints the standard action before its Aura
      // handler is ready. Use the record's own edit route so this lifecycle
      // gate measures LDS refresh behavior instead of an action-bar race.
      const editLink = page.locator('a[href$="/edit"]').first();
      await expect(editLink).toBeVisible();
      await editLink.click();
    }
  }
  // Depending on Salesforce's current record-page shell, Edit can render as
  // a modal dialog or as inline page detail fields. The lifecycle contract is
  // the save notification and card refresh, not either shell presentation.
  await expect(phoneInput).toBeVisible();
  await phoneInput.fill("3125550199");
  auraRequestsAfterSave = 0;
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(phoneInput).toBeHidden();
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
