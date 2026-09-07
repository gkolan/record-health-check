import { expect } from "@playwright/test";
import { randomBytes } from "node:crypto";

export function createScratchUserNewPassword(
  currentPassword,
  entropy = randomBytes(12).toString("hex")
) {
  if (!currentPassword) {
    throw new Error("The current scratch-user password is required.");
  }
  const safeEntropy = String(entropy).replace(/[^A-Za-z0-9]/g, "");
  if (!safeEntropy) {
    throw new Error("Password entropy must contain a letter or number.");
  }
  const newPassword = `Rhc9!${safeEntropy.slice(0, 32)}zQ`;
  if (
    newPassword.includes(currentPassword) ||
    currentPassword.includes(newPassword)
  ) {
    throw new Error("The new scratch-user password must be independent.");
  }
  return newPassword;
}

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
  await current.pressSequentially(currentPassword, { delay: 1, timeout });
  await page
    .getByLabel(/^\s*\*?\s*New Password\s*\*?\s*$/i)
    .pressSequentially(newPassword, { delay: 1, timeout });
  await page
    .getByLabel(/^\s*\*?\s*Confirm New Password\s*\*?\s*$/i)
    .pressSequentially(newPassword, { delay: 1, timeout });
  await page
    .getByLabel(/^\s*\*?\s*New Security Question\s*\*?\s*$/i)
    .selectOption({ index: 1 }, { timeout });
  await page
    .getByLabel(/^\s*\*?\s*New Answer\s*\*?\s*$/i)
    .pressSequentially("Chicago", { delay: 1, timeout });
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
