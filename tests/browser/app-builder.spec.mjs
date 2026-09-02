import { expect, test } from "@playwright/test";

const builderUrl = process.env.RHC_BUILDER_URL;
const builderPageLabel = process.env.RHC_BUILDER_PAGE_LABEL;
const COMPONENT_SELECTOR = "c-record-health-check, rhc-record-health-check";

if (!builderUrl) {
  throw new Error(
    "RHC_BUILDER_URL is required; App Builder validation cannot skip."
  );
}
if (!builderPageLabel) {
  throw new Error(
    "RHC_BUILDER_PAGE_LABEL is required; App Builder validation cannot skip."
  );
}

async function builderCanvas(page) {
  await expect
    .poll(async () => {
      const counts = await Promise.all(
        page.frames().map((frame) =>
          frame
            .locator(COMPONENT_SELECTOR)
            .count()
            .catch(() => 0)
        )
      );
      return Math.max(0, ...counts);
    })
    .toBe(2);

  for (const frame of page.frames()) {
    if ((await frame.locator(COMPONENT_SELECTOR).count()) === 2) return frame;
  }
  throw new Error("App Builder canvas did not mount both RHC previews.");
}

async function lightningPageRow(page) {
  await expect
    .poll(async () => {
      const counts = await Promise.all(
        page.frames().map((frame) =>
          frame
            .getByRole("row")
            .filter({ hasText: builderPageLabel })
            .count()
            .catch(() => 0)
        )
      );
      return counts.reduce((total, count) => total + count, 0);
    })
    .toBe(1);

  for (const frame of page.frames()) {
    const row = frame.getByRole("row").filter({ hasText: builderPageLabel });
    if ((await row.count()) === 1) return row;
  }
  throw new Error("The App Builder release-gate page was not listed.");
}

test("keeps configured and unconfigured App Builder previews quiet", async ({
  page
}) => {
  const pageErrors = [];
  const recordHealthCheckApexRequests = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  page.on("request", (request) => {
    if (request.postData()?.includes("RecordHealthCheckController")) {
      recordHealthCheckApexRequests.push(request.url());
    }
  });
  await page.goto(builderUrl, { waitUntil: "domcontentloaded" });
  const pageRow = await lightningPageRow(page);
  const popupPromise = page
    .waitForEvent("popup", { timeout: 5000 })
    .catch(() => null);
  await pageRow.getByRole("link", { name: "Edit", exact: true }).click();
  const editorPage = (await popupPromise) ?? page;
  if (editorPage !== page) {
    editorPage.on("pageerror", (error) => pageErrors.push(error.message));
    editorPage.on("request", (request) => {
      if (request.postData()?.includes("RecordHealthCheckController")) {
        recordHealthCheckApexRequests.push(request.url());
      }
    });
  }

  const canvas = await builderCanvas(editorPage);
  const components = canvas.locator(COMPONENT_SELECTOR);
  await expect(components).toHaveCount(2);

  const configured = components.filter({
    hasText: "The configured health check will run when a record is available."
  });
  const unconfigured = components.filter({
    hasText: "Select a Check Set in the component properties."
  });
  await expect(configured).toHaveCount(1);
  await expect(unconfigured).toHaveCount(1);

  for (let sample = 0; sample < 60; sample += 1) {
    await expect(components.locator("lightning-spinner")).toHaveCount(0);
    await expect(components.locator(".slds-spinner_container")).toHaveCount(0);
    await expect(
      editorPage.locator(".slds-spinner_container:visible")
    ).toHaveCount(0);
    await editorPage.waitForTimeout(100);
  }

  await expect(configured.locator(".rhc-row")).toHaveCount(0);
  await expect(unconfigured.locator(".rhc-row")).toHaveCount(0);
  await expect(configured.getByRole("button", { name: /run/i })).toHaveCount(0);
  await expect(unconfigured.getByRole("button", { name: /run/i })).toHaveCount(
    0
  );
  await expect(
    editorPage.getByText("A Component Error has occurred")
  ).toHaveCount(0);
  await expect(editorPage.getByText("Invalid contextElement")).toHaveCount(0);
  expect(recordHealthCheckApexRequests).toEqual([]);
  expect(pageErrors).toEqual([]);
});
