import { expect, test } from "@playwright/test";

// Guards the two record-page card contracts described in
// docs/architecture/record-page-card-contract.md against the real Lightning
// runtime. The Jest suite covers the same behavior against jsdom, where no
// stylesheet is applied and no Apex is called, so neither the painted card
// body nor the configuration reread can be proven there.

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

/**
 * Measures the painted card regions. A header-only card reports a body whose
 * height stops at the bottom of its header, which is the failure this guards.
 */
async function cardRegions(card) {
  return card.evaluate((host) => {
    const root = host.shadowRoot ?? host;
    const body = root.querySelector(".rhc-body");
    const header = root.querySelector(".rhc-header");
    if (!body || !header) {
      return { bodyFound: Boolean(body), headerFound: Boolean(header) };
    }
    const bodyBox = body.getBoundingClientRect();
    const headerBox = header.getBoundingClientRect();
    const painted = [...body.children]
      .filter((node) => !node.classList.contains("rhc-header"))
      .filter((node) => node.getBoundingClientRect().height > 0)
      .map((node) => node.className);
    return {
      bodyFound: true,
      headerFound: true,
      headerHeight: headerBox.height,
      bodyHeight: bodyBox.height,
      contentHeight: bodyBox.height - headerBox.height,
      painted
    };
  });
}

async function expectPaintedBody(card, label) {
  await expect
    .poll(async () => (await cardRegions(card)).bodyFound, {
      message: `${label}: card body never appeared`
    })
    .toBe(true);
  const regions = await cardRegions(card);
  expect(regions.headerFound, `${label}: card header is missing`).toBe(true);
  // The header alone must never account for the whole card.
  expect(
    regions.contentHeight,
    `${label}: header-only card, painted body content: ${JSON.stringify(regions.painted)}`
  ).toBeGreaterThan(0);
  expect(
    regions.painted.length,
    `${label}: card body has no painted child below the header`
  ).toBeGreaterThan(0);
}

// One test per spec file: the gate supplies a single-use frontdoor URL, so a
// second test in this file would navigate with a consumed one-time password.
test("keeps a painted body and rereads configuration on Rerun", async ({
  page
}, testInfo) => {
  await testInfo.attach("salesforce-security-mode", {
    body: securityMode,
    contentType: "text/plain"
  });

  const definitionRequests = [];
  page.on("request", (request) => {
    const requestBody = request.postData();
    if (requestBody && requestBody.includes("getCheckDefinitions")) {
      definitionRequests.push(request.url());
    }
  });

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

  // Sample repeatedly while the page settles. A header-only frame is a defect
  // even when the finished card looks correct, so a single assertion after
  // load would not catch it.
  for (let sample = 0; sample < 25; sample += 1) {
    await expectPaintedBody(manualCard, `manual card, sample ${sample}`);
    await expectPaintedBody(automaticCard, `automatic card, sample ${sample}`);
    await page.waitForTimeout(200);
  }

  const runButton = manualCard.getByRole("button", { name: /^Run$/ });
  await expect(runButton).toBeEnabled();
  await runButton.click();

  for (let sample = 0; sample < 20; sample += 1) {
    await expectPaintedBody(
      manualCard,
      `manual card running, sample ${sample}`
    );
    await page.waitForTimeout(200);
  }

  await expect(manualCard).toContainText("Completed Checks: 25 / 25");
  await expectPaintedBody(manualCard, "manual card, run complete");

  const afterFirstRun = definitionRequests.length;
  expect(
    afterFirstRun,
    "the card never requested Check Set definitions"
  ).toBeGreaterThan(0);

  // A Rerun must ask the server for configuration again rather than replaying
  // the definitions captured when the page loaded. A console record tab can
  // stay open for days, so replaying them silently hides a Setup edit.
  await manualCard.getByRole("button", { name: /^Rerun$/ }).click();
  await expect
    .poll(() => definitionRequests.length, {
      message: "Rerun did not request Check Set definitions again"
    })
    .toBeGreaterThan(afterFirstRun);

  await expect(manualCard).toContainText("Completed Checks: 25 / 25");
  await expectPaintedBody(manualCard, "manual card, after Rerun");
});
