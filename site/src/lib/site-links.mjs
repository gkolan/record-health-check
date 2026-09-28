export const GITHUB_REPOSITORY_URL =
  "https://github.com/gkolan/record-health-check";
export const MAINTAINER_URL = "https://github.com/gkolan";
export const LICENSE_URL = `${GITHUB_REPOSITORY_URL}/blob/main/LICENSE`;
export const SANDBOX_INSTALL_URL =
  "https://recordhealthcheck.com/install/sandbox";
export const PRODUCTION_INSTALL_URL =
  "https://recordhealthcheck.com/install/production";

/**
 * Creates the prefilled correction form used by every documentation page.
 * GitHub issue-form field IDs are valid URL query parameters.
 */
export function createDocumentationIssueUrl({ title, pageUrl, sourcePath }) {
  const url = new URL(`${GITHUB_REPOSITORY_URL}/issues/new`);
  url.searchParams.set("template", "documentation.yml");
  url.searchParams.set("title", `Docs: ${title}`);
  url.searchParams.set("page", pageUrl);
  url.searchParams.set("source", sourcePath);
  return url.href;
}
