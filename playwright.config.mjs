import { defineConfig, devices } from "@playwright/test";

const releasePageUrl = process.env.RHC_BROWSER_URL;
const retainedReleaseEvidence = Boolean(process.env.RHC_BROWSER_JSON);

export default defineConfig({
  testDir: "./tests/browser",
  fullyParallel: false,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  timeout: 120_000,
  expect: { timeout: 30_000 },
  reporter: retainedReleaseEvidence
    ? [["json", { outputFile: process.env.RHC_BROWSER_JSON }]]
    : process.env.CI
      ? [["github"], ["html", { open: "never" }]]
      : "list",
  use: {
    baseURL: releasePageUrl,
    // Raw captures can contain frontdoor session IDs and password setup steps.
    // The release runner publishes only redacted JSON and an escaped HTML view.
    screenshot: retainedReleaseEvidence ? "off" : "only-on-failure",
    trace: retainedReleaseEvidence ? "off" : "retain-on-failure",
    video: retainedReleaseEvidence ? "off" : "retain-on-failure"
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "firefox", use: { ...devices["Desktop Firefox"] } }
  ],
  outputDir: process.env.RHC_BROWSER_OUTPUT || "test-results/browser"
});
