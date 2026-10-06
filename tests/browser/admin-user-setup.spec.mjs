import { test } from "@playwright/test";
import { completeScratchUserFirstLogin } from "../../scripts/lib/salesforce-first-login.mjs";

const setupUrl = process.env.RHC_ADMIN_SETUP_URL;
if (!setupUrl) throw new Error("RHC_ADMIN_SETUP_URL is required.");

test("acknowledges maintenance before administrator browser validation", async ({
  page
}) => {
  await page.goto(setupUrl, { waitUntil: "domcontentloaded" });
  await completeScratchUserFirstLogin(page, {});
});
