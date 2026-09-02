import { expect, test } from "@playwright/test";

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
  const heading = page.getByRole("heading", { name: "Change Your Password" });
  if (!(await heading.isVisible())) {
    await expect(page).toHaveURL(/\/lightning\/page\/home/);
    return;
  }

  await page
    .getByRole("textbox", { name: /^\* Current Password$/ })
    .pressSequentially(currentPassword);
  await page
    .getByRole("textbox", { name: /^\* New Password$/ })
    .pressSequentially(newPassword);
  await page
    .getByRole("textbox", { name: /^\* Confirm New Password$/ })
    .pressSequentially(newPassword);
  await page
    .getByRole("textbox", { name: /^\* New Answer$/ })
    .pressSequentially("Chicago");
  const submit = page.getByRole("button", { name: /change password/i });
  await expect(submit).toBeEnabled();
  await submit.click();

  await expect(heading).toBeHidden();
  await expect(page).not.toHaveURL(/ChangePassword|changepassword/i);
});
