import { expect } from "@playwright/test";

export function isLightningHome(url) {
  try {
    return /^\/lightning\/page\/home\/?$/.test(new URL(String(url)).pathname);
  } catch {
    return false;
  }
}

export function firstLoginState(url, passwordFieldVisible) {
  if (passwordFieldVisible) return "password-change";
  return isLightningHome(url) ? "home" : "pending";
}

export async function completeScratchUserFirstLogin(
  page,
  { currentPassword, newPassword },
  { timeout = 30_000, intervals = [100, 250, 500] } = {}
) {
  // Password inputs do not have the textbox ARIA role. Labels also avoid
  // depending on a heading that can arrive later than the redirect itself.
  const current = page.getByLabel(/^\s*\*?\s*Current Password\s*\*?\s*$/i);
  let state;
  await expect
    .poll(
      async () => {
        const visible = await current.isVisible();
        state = firstLoginState(page.url(), visible);
        return state;
      },
      {
        timeout,
        intervals,
        message: "Wait for the password-change form or Lightning Home"
      }
    )
    .not.toBe("pending");

  if (state === "home") return;
  if (!currentPassword || !newPassword)
    throw new Error("Scratch-user setup passwords are required.");
  await current.fill(currentPassword, { timeout });
  await page
    .getByLabel(/^\s*\*?\s*New Password\s*\*?\s*$/i)
    .fill(newPassword, { timeout });
  await page
    .getByLabel(/^\s*\*?\s*Confirm New Password\s*\*?\s*$/i)
    .fill(newPassword, { timeout });
  await page
    .getByLabel(/^\s*\*?\s*New Answer\s*\*?\s*$/i)
    .fill("Chicago", { timeout });
  await page
    .getByRole("button", { name: /change password/i })
    .click({ timeout });
  // Leaving ChangePassword or hiding its heading is not proof of success:
  // login, verification, and error pages must never qualify as ready.
  await page.waitForURL(isLightningHome, {
    timeout,
    waitUntil: "domcontentloaded"
  });
}
