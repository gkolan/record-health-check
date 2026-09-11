import { expect, test } from "@playwright/test";

const COMPONENT_SELECTOR = "c-record-health-check, rhc-record-health-check";
const CARD_TITLE = "Coverage: URL Story Inline Links";

if (!process.env.RHC_BROWSER_URL) {
  throw new Error(
    "RHC_BROWSER_URL is required; URL-story browser validation cannot skip."
  );
}

async function openFixture(page, recordId) {
  if (recordId) {
    const origin = new URL(page.url()).origin;
    await page.goto(`${origin}/lightning/r/Account/${recordId}/view`, {
      waitUntil: "domcontentloaded"
    });
  }
  const card = page.locator(COMPONENT_SELECTOR).filter({ hasText: CARD_TITLE });
  await expect(card).toHaveCount(1);
  const run = card.getByRole("button", { name: /^(Run|Rerun)$/ });
  await expect(run).toBeEnabled();
  await run.click();
  await expect(card).toContainText("Completed Checks: 3 / 3");
  return card;
}

function checkRow(card, label) {
  return card.locator(".rhc-row").filter({ hasText: label });
}

function foundValue(row) {
  return row.locator(".rhc-cmp__key", { hasText: /^Found$/ }).locator("../..");
}

async function decoration(link) {
  return link.evaluate((node) => {
    const style = globalThis.getComputedStyle(node);
    return {
      line: style.textDecorationLine,
      style: style.textDecorationStyle
    };
  });
}

test("renders and operates the complete URL story", async ({
  page
}, testInfo) => {
  await testInfo.attach("salesforce-security-mode", {
    body: process.env.RHC_SECURITY_MODE ?? "UNSPECIFIED",
    contentType: "text/plain"
  });
  await page.goto("", { waitUntil: "domcontentloaded" });
  const card = await openFixture(page);

  const structured = checkRow(card, "Structured Apex links");
  const structuredFound = foundValue(structured);
  const links = structuredFound.locator(".rhc-inline-link");
  await expect(links).toHaveCount(9);
  await expect(structuredFound.locator("br")).toHaveCount(2);
  await expect(structuredFound).toContainText("Step 1:");
  await expect(structuredFound).toContainText("Step 2:");
  await expect(structuredFound).toContainText("Step 3:");
  const stepTop = await Promise.all(
    ["Step 1", "Step 2", "Step 3"].map(async (label) =>
      structuredFound
        .getByRole("link", { name: new RegExp(`^${label}`) })
        .evaluate((node) => node.getBoundingClientRect().top)
    )
  );
  expect(stepTop[1]).toBeGreaterThan(stepTop[0]);
  expect(stepTop[2]).toBeGreaterThan(stepTop[1]);

  for (const anchor of await links.all()) {
    await expect(anchor).toHaveAttribute("target", "_blank");
    await expect(anchor).toHaveAttribute("rel", "noopener noreferrer");
    await expect(anchor).toHaveAttribute("aria-label", /new tab/i);
  }

  await page.mouse.move(0, 0);
  expect((await decoration(links.nth(0))).line).toBe("none");
  await structured.hover({ position: { x: 2, y: 2 } });
  expect(await decoration(links.nth(0))).toEqual({
    line: "underline",
    style: "dotted"
  });
  await links.nth(0).hover();
  expect(await decoration(links.nth(0))).toEqual({
    line: "underline",
    style: "solid"
  });
  expect(await decoration(links.nth(1))).toEqual({
    line: "underline",
    style: "dotted"
  });
  await links.nth(0).focus();
  expect((await decoration(links.nth(0))).style).toBe("solid");

  const firstHref = await links.nth(0).getAttribute("href");
  const popupPromise = page.waitForEvent("popup");
  await links.nth(0).click();
  const popup = await popupPromise;
  await expect(popup).toHaveURL(new RegExp(firstHref.replaceAll("/", "\\/")));
  await popup.close();

  const legacy = checkRow(card, "Legacy Apex multiline text");
  const legacyFound = foundValue(legacy);
  await expect(legacyFound.locator(".rhc-inline-link")).toHaveCount(0);
  await expect(legacyFound.locator("br")).toHaveCount(1);
  await expect(legacyFound).toContainText("Step 1 - Payment Term Approvals");
  await expect(legacyFound).toContainText("Step 2 - Finance Approval");

  const metadata = checkRow(card, "Metadata-authored links");
  await expect(
    metadata.getByRole("link", { name: /Approval guide/ })
  ).toHaveCount(1);
  const action = metadata.getByRole("link", {
    name: "View account",
    exact: true
  });
  await expect(action).toHaveCount(1);

  for (const variable of [
    "RHC_MISSING_DESTINATION_ID",
    "RHC_UNSAFE_DESTINATION_ID",
    "RHC_HEALTHY_UNSAFE_DESTINATION_ID"
  ]) {
    const recordId = process.env[variable];
    if (!recordId) throw new Error(`${variable} is required.`);
    const fallbackCard = await openFixture(page, recordId);
    const fallbackRow = checkRow(fallbackCard, "Metadata-authored links");
    await expect(fallbackRow).toContainText("Approval guide");
    await expect(
      fallbackRow.getByRole("link", { name: /Approval guide/ })
    ).toHaveCount(0);
    await expect(fallbackRow.locator(".rhc-inline-link")).not.toHaveCount(0);
  }
});
