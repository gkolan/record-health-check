import { test } from "@playwright/test";
import { completeScratchUserFirstLogin } from "../../scripts/lib/salesforce-first-login.mjs";

const setupUrl = process.env.RHC_RESTRICTED_SETUP_URL;
const currentPassword = process.env.RHC_RESTRICTED_CURRENT_PASSWORD;
const newPassword = process.env.RHC_RESTRICTED_NEW_PASSWORD;

if (!setupUrl || !currentPassword || !newPassword) {
  throw new Error(
    "The restricted setup URL, current password, and new password are required."
  );
}

test("completes mandatory first login for the restricted scratch user", async ({
  page
}) => {
  test.setTimeout(60000);
  await page.goto(setupUrl, { waitUntil: "domcontentloaded" });
  await completeScratchUserFirstLogin(page, { currentPassword, newPassword });
});
