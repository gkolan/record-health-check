import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import test from "node:test";

import {
  GITHUB_REPOSITORY_URL,
  PRODUCTION_INSTALL_URL,
  SANDBOX_INSTALL_URL,
  createDocumentationIssueUrl
} from "../../site/src/lib/site-links.mjs";

const repositoryRoot = new URL("../../", import.meta.url);

async function readRepositoryFile(path) {
  return readFile(new URL(path, repositoryRoot), "utf8");
}

async function listMarkdownFiles(directory) {
  const entries = await readdir(new URL(directory, repositoryRoot), {
    withFileTypes: true
  });
  const files = await Promise.all(
    entries.map((entry) => {
      const path = `${directory}${entry.name}`;
      if (entry.isDirectory()) return listMarkdownFiles(`${path}/`);
      return entry.isFile() && entry.name.endsWith(".md") ? [path] : [];
    })
  );
  return files.flat().sort();
}

test("landing page exposes the primary product actions", async () => {
  const homePage = await readRepositoryFile("site/src/content/home.mdx");

  assert.equal(
    GITHUB_REPOSITORY_URL,
    "https://github.com/gkolan/record-health-check"
  );
  assert.equal(
    SANDBOX_INSTALL_URL,
    "https://recordhealthcheck.com/install/sandbox"
  );
  assert.equal(
    PRODUCTION_INSTALL_URL,
    "https://recordhealthcheck.com/install/production"
  );
  assert.match(homePage, /Install in Sandbox/);
  assert.match(homePage, /Install in Production/);
  assert.doesNotMatch(homePage, /View on GitHub/);
  const heroActions = homePage.match(/hero:[\s\S]*?actions:([\s\S]*?)---/);
  assert.ok(heroActions, "Expected the landing page to define hero actions");
  assert.equal(heroActions[1].match(/^\s+- text:/gm)?.length, 2);
  assert.match(
    heroActions[1],
    /Install in Production[\s\S]*?variant:\s*secondary/
  );
});

test("Plausible analytics is optional and configured at deployment time", async () => {
  const [astroConfig, siteReadme] = await Promise.all([
    readRepositoryFile("site/astro.config.mjs"),
    readRepositoryFile("site/README.md")
  ]);

  assert.match(astroConfig, /PLAUSIBLE_SCRIPT_URL/);
  assert.match(astroConfig, /plausible\.init/);
  assert.match(siteReadme, /Plausible/);
  assert.match(siteReadme, /outbound link/i);
});

test("every public page has social, search, and agent discovery metadata", async () => {
  const [astroConfig, pageHead, prepareContent, rootPackage, sitePackage] =
    await Promise.all([
      readRepositoryFile("site/astro.config.mjs"),
      readRepositoryFile("site/src/components/PageHead.astro"),
      readRepositoryFile("site/scripts/prepare-content.mjs"),
      readRepositoryFile("package.json"),
      readRepositoryFile("site/package.json")
    ]);

  assert.match(
    astroConfig,
    /Head:\s*["']\.\/src\/components\/PageHead\.astro["']/
  );
  assert.match(pageHead, /name="robots"/);
  assert.match(pageHead, /property="og:image"/);
  assert.match(pageHead, /name="twitter:card"/);
  assert.match(pageHead, /application\/ld\+json/);
  assert.match(pageHead, /href="\/llms\.txt"/);
  assert.match(prepareContent, /writeAgentDiscovery\(sourceFiles\)/);
  assert.match(sitePackage, /"check:seo":\s*"node scripts\/check-seo\.mjs"/);
  assert.match(rootPackage, /npm run check:seo --prefix site/);
});

test("GitHub Actions verifies and deploys the static site to Cloudflare Pages", async () => {
  const workflow = await readRepositoryFile(
    ".github/workflows/deploy-docs-cloudflare.yml"
  );

  assert.match(workflow, /branches:\s*\[["']docs-\?["']\]/);
  assert.match(workflow, /npm run check:seo --prefix site/);
  assert.match(workflow, /cloudflare\/wrangler-action@v4/);
  assert.match(workflow, /pages deploy site\/dist/);
  assert.match(workflow, /--branch=\$\{\{ github\.ref_name \}\}/);
  assert.match(workflow, /secrets\.CLOUDFLARE_API_TOKEN/);
  assert.match(workflow, /secrets\.CLOUDFLARE_ACCOUNT_ID/);
  assert.match(workflow, /vars\.CLOUDFLARE_PAGES_PROJECT/);
});

test("canonical documentation links may reference the published documentation host", async () => {
  const externalLinkCheck = await readRepositoryFile(
    "scripts/release/check_documentation_external_links.mjs"
  );

  assert.match(externalLinkCheck, /["']docs\.recordhealthcheck\.com["']/);
});

test("landing page keeps decorative chrome restrained", async () => {
  const [astroConfig, homePage, footer, styles] = await Promise.all([
    readRepositoryFile("site/astro.config.mjs"),
    readRepositoryFile("site/src/content/home.mdx"),
    readRepositoryFile("site/src/components/ArticleFooter.astro"),
    readRepositoryFile("site/src/styles/custom.css")
  ]);

  assert.match(astroConfig, /collapsed:\s*true/);
  assert.doesNotMatch(homePage, /icon:/);
  assert.doesNotMatch(homePage, /<Card\b/);
  assert.doesNotMatch(homePage, /Built around common tasks/);
  assert.doesNotMatch(footer, /<Icon\b/);
  assert.doesNotMatch(footer, /Improve this documentation/);
  assert.doesNotMatch(footer, /<aside class="docs-feedback"/);
  assert.match(footer, /<footer class="site-footer">/);
  assert.match(footer, /Record Health Check/);
  assert.match(footer, /Maintained by/);
  assert.match(footer, /Gautam Kolan/);
  assert.match(footer, /Apache 2\.0/);
  assert.match(footer, /\/start-here\/what-it-does\//);
  assert.match(styles, /--site-container-width:\s*80rem/);
  assert.match(styles, /header\.header\s*>\s*\.header/);
  assert.match(
    styles,
    /header\.header\s*\{[\s\S]*padding-inline:\s*max\([\s\S]*--site-container-width[\s\S]*--sl-content-pad-x/
  );
  assert.match(styles, /\.main-frame/);
  assert.match(
    styles,
    /html\[data-has-hero\]:not\(\[data-has-sidebar\]\)[\s\S]*--sl-content-width:\s*var\(--site-container-width\)/
  );
});

test("site chrome labels the docs, keeps search rightmost, and places theme controls in the footer", async () => {
  const [astroConfig, header, footer] = await Promise.all([
    readRepositoryFile("site/astro.config.mjs"),
    readRepositoryFile("site/src/components/SiteHeader.astro"),
    readRepositoryFile("site/src/components/ArticleFooter.astro")
  ]);

  assert.match(
    astroConfig,
    /Header:\s*["']\.\/src\/components\/SiteHeader\.astro["']/
  );
  assert.match(astroConfig, /title:\s*["']Docs\.RecordHealthCheck["']/);
  assert.match(header, />Docs\.RecordHealthCheck<\/span>/);
  assert.doesNotMatch(header, /class="separator"/);
  assert.match(header, /<Icon name="github"/);
  assert.match(header, />GitHub<\/span>/);
  assert.doesNotMatch(header, /ThemeSelect/);
  assert.ok(header.indexOf("github-link") < header.lastIndexOf("<Search"));
  assert.match(footer, /ThemeSelect/);
  assert.match(
    footer,
    /<div class="footer-heading">[\s\S]*<strong>Record Health Check<\/strong>[\s\S]*<ThemeSelect \/>/
  );
});

test("nested sidebar links have enough vertical breathing room", async () => {
  const styles = await readRepositoryFile("site/src/styles/custom.css");

  assert.match(
    styles,
    /\.sidebar-pane nav\[aria-label=["']Main["']\] ul ul a\s*\{[\s\S]*padding-block:\s*0\.45rem/
  );
});

test("side navigation does not show competing scroll tracks", async () => {
  const styles = await readRepositoryFile("site/src/styles/custom.css");

  assert.match(
    styles,
    /\.sidebar-pane,\s*\.right-sidebar\s*\{[\s\S]*scrollbar-width:\s*none/
  );
  assert.match(
    styles,
    /\.sidebar-pane::-webkit-scrollbar,\s*\.right-sidebar::-webkit-scrollbar\s*\{[\s\S]*display:\s*none/
  );
});

test("the on-page table of contents uses a narrower desktop column", async () => {
  const styles = await readRepositoryFile("site/src/styles/custom.css");

  assert.match(styles, /--site-toc-width:\s*16rem/);
  assert.match(
    styles,
    /\.right-sidebar-container\s*\{[\s\S]*--sl-sidebar-width:\s*var\(--site-toc-width\)/
  );
  assert.match(
    styles,
    /html\[data-has-sidebar\]\[data-has-toc\] \.main-pane\s*\{[\s\S]*var\(--site-toc-width\)/
  );
});

test("generated documentation renders GitHub alerts as native callouts", async () => {
  const [prepareContent, generatedPage, generatedFiles] = await Promise.all([
    readRepositoryFile("site/scripts/prepare-content.mjs"),
    readRepositoryFile(
      "site/src/content/docs/start-here/choose-how-checks-run.md"
    ),
    listMarkdownFiles("site/src/content/docs/")
  ]);
  const generatedContent = await Promise.all(
    generatedFiles.map(readRepositoryFile)
  );

  assert.match(prepareContent, /function transformGitHubAlerts/);
  assert.match(prepareContent, /transformGitHubAlerts\(withoutTitle\)/);
  assert.doesNotMatch(generatedPage, /> \[!NOTE\]/);
  assert.match(generatedPage, /:::note[\s\S]*Use this page to choose/);
  assert.doesNotMatch(generatedPage, /\]\([^)\s]+\.md(?:#[^)]+)?\)/);
  assert.match(
    generatedPage,
    /\]\(\/lightning-record-page\/configure-the-component\/\)/
  );
  for (const [index, content] of generatedContent.entries()) {
    assert.doesNotMatch(
      content,
      /^> \[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]/m,
      `Expected ${generatedFiles[index]} to use a native Starlight callout`
    );
  }
});

test("rendered task-list checkboxes inherit the checklist item as an accessible name", async () => {
  const { labelTaskListCheckboxes } =
    await import("../../site/src/lib/accessible-task-lists.mjs");
  const html = labelTaskListCheckboxes(
    '<li class="task-list-item"><input type="checkbox" disabled> Confirm the <code>URL</code> is safe.</li>'
  );

  assert.match(
    html,
    /<input type="checkbox" disabled aria-label="Confirm the URL is safe\.">/
  );
  assert.match(html, /Confirm the <code>URL<\/code> is safe\./);
});

test("built documentation rejects raw Markdown and structural rendering regressions", async () => {
  const { renderedOutputIssues } =
    await import("../../site/src/lib/rendered-output.mjs");

  const valid = `<!doctype html><html><body><main><h1>Guide</h1><h2>Steps</h2>
    <ul><li class="task-list-item"><input type="checkbox" disabled aria-label="Confirm setup"> Confirm setup</li></ul>
    <pre><code>| Markdown examples remain valid in code |</code></pre></main></body></html>`;
  assert.deepEqual(renderedOutputIssues(valid, "/guide/"), []);

  const broken = `<!doctype html><html><body><main><h1>Guide</h1><h3>Details</h3>
    <p>| Last table row | rendered as prose |</p>
    <ul><li class="task-list-item"><input type="checkbox" disabled> Confirm setup</li></ul>
    <a>Missing destination</a><h4></h4><p>[Broken](./target)</p></main></body></html>`;
  const issues = renderedOutputIssues(broken, "/guide/");

  assert.ok(issues.some((issue) => issue.includes("heading jump 1→3")));
  assert.ok(issues.some((issue) => issue.includes("raw Markdown table")));
  assert.ok(issues.some((issue) => issue.includes("raw Markdown link")));
  assert.ok(
    issues.some((issue) => issue.includes("unnamed task-list checkbox"))
  );
  assert.ok(issues.some((issue) => issue.includes("anchor without href")));
  assert.ok(issues.some((issue) => issue.includes("empty heading")));
});

test("agent guidance makes rendered-site verification a session-level contract", async () => {
  const agents = await readRepositoryFile("AGENTS.md");

  assert.match(agents, /^## Static documentation rendering contract$/m);
  assert.match(agents, /npm run check:docs:site/);
  assert.match(agents, /npm run audit:docs:render/);
  assert.match(agents, /docs\/quality-gates\/documentation-standard\.md/);
});

test("rendering lessons are detailed, public, and linked from every owning guide", async () => {
  const [lesson, astroConfig, qualityGates, siteReadme, agents] =
    await Promise.all([
      readRepositoryFile(
        "docs/quality-gates/static-site-rendering-and-visual-verification.md"
      ),
      readRepositoryFile("site/astro.config.mjs"),
      readRepositoryFile("docs/quality-gates/README.md"),
      readRepositoryFile("site/README.md"),
      readRepositoryFile("AGENTS.md")
    ]);

  for (const heading of [
    "## Why source checks were not enough",
    "## Lessons from the complete rendered-site review",
    "## Required verification by change type",
    "## What the CI gate checks",
    "## Run and review the complete browser audit",
    "## Keep the lesson visible to future agents",
    "## Add a regression when a new failure is found",
    "## Completion checklist",
    "## Related"
  ]) {
    assert.match(lesson, new RegExp(`^${heading}$`, "m"));
  }
  assert.match(lesson, /npm run check:docs:site/);
  assert.match(lesson, /npm run audit:docs:render/);
  assert.match(lesson, /AUDIT_ROUTES/);
  assert.match(
    lesson,
    /https:\/\/docs\.recordhealthcheck\.com\/quality-gates\/static-site-rendering-and-visual-verification\//
  );
  assert.match(
    astroConfig,
    /section\(["']Quality gates["'],\s*["']quality-gates["']\)/
  );
  assert.match(
    qualityGates,
    /static-site-rendering-and-visual-verification\.md/
  );
  assert.match(siteReadme, /https:\/\/docs\.recordhealthcheck\.com\//);
  assert.match(agents, /static-site-rendering-and-visual-verification\.md/);
});

test("article pages have section identity and scannable next steps", async () => {
  const [astroConfig, articleTitle, styles] = await Promise.all([
    readRepositoryFile("site/astro.config.mjs"),
    readRepositoryFile("site/src/components/ArticleTitle.astro"),
    readRepositoryFile("site/src/styles/custom.css")
  ]);

  assert.match(
    astroConfig,
    /PageTitle:\s*["']\.\/src\/components\/ArticleTitle\.astro["']/
  );
  assert.match(articleTitle, /class="section-label"/);
  assert.match(articleTitle, /id="_top"/);
  assert.match(styles, /\.sl-heading-wrapper:has\(h2#next-steps\) \+ ul/);
  assert.match(styles, /grid-template-columns:\s*repeat\(auto-fit/);
  assert.match(
    styles,
    /\.sl-heading-wrapper:has\(h2#next-steps\) \+ ul a::after/
  );
  assert.match(styles, /min-height:\s*5\.25rem/);
});

test("homepage hero explains the product and keeps its actions focused on installation", async () => {
  const [astroConfig, homePage, hero] = await Promise.all([
    readRepositoryFile("site/astro.config.mjs"),
    readRepositoryFile("site/src/content/home.mdx"),
    readRepositoryFile("site/src/components/SiteHero.astro")
  ]);

  assert.match(
    astroConfig,
    /Hero:\s*["']\.\/src\/components\/SiteHero\.astro["']/
  );
  assert.match(homePage, /A coach on every Salesforce record/);
  assert.match(hero, /Open Source/);
  assert.match(hero, /Apache 2\.0/);
  assert.match(hero, /What looks good/);
  assert.match(hero, /What needs attention/);
  assert.match(hero, /What to do next/);
  assert.doesNotMatch(hero, /View Slides/);
  assert.doesNotMatch(hero, /View Demo/);
  assert.doesNotMatch(hero, /Coming soon/);
  assert.match(hero, /\.actions\s*\{[\s\S]*display:\s*flex/);
  const heroActionLinkStyles =
    hero.match(/\.actions :global\(a\)\s*\{([\s\S]*?)\}/)?.[1] ?? "";
  assert.doesNotMatch(heroActionLinkStyles, /width:\s*100%/);
  assert.match(hero, /border-radius:\s*0\.5rem/);
  assert.doesNotMatch(hero, /Learn your way/);
  assert.doesNotMatch(homePage, /RHC_LOGO/);
  assert.match(
    homePage,
    /Example_SLDS_2_Account_Relationship_Risk_Screenshot\.png/
  );
});

test("homepage groups tasks, resources, the guided path, and examples into distinct sections", async () => {
  const [homePage, homeSection, resourceLinks, examples] = await Promise.all([
    readRepositoryFile("site/src/content/home.mdx"),
    readRepositoryFile("site/src/components/HomeSection.astro"),
    readRepositoryFile("site/src/components/ResourceLinks.astro"),
    readRepositoryFile("site/src/components/UseCaseExamples.astro")
  ]);

  assert.match(homePage, /Choose what you want to do/);
  assert.match(homePage, /title="Explore the ecosystem"/);
  assert.match(homePage, /The fastest path to a working Check/);
  assert.match(homePage, /title="See it solve real Salesforce problems"/);
  assert.equal(homePage.match(/<HomeSection\b/g)?.length, 4);
  assert.match(homePage, /tone="neutral"/);
  assert.match(homePage, /tone="accent"/);
  assert.ok(
    homePage.indexOf('id="fastest-path"') < homePage.indexOf('id="examples"') &&
      homePage.indexOf('id="examples"') <
        homePage.indexOf('id="choose-your-path"') &&
      homePage.indexOf('id="choose-your-path"') <
        homePage.indexOf('id="ecosystem"'),
    "The homepage should flow from onboarding to examples, documentation, then future resources"
  );
  assert.doesNotMatch(homePage, /suggest a documentation update/);
  assert.match(homeSection, /padding-block:\s*clamp\(3rem, 5vw, 4\.5rem\)/);
  assert.match(homeSection, /box-shadow:\s*0 0 0 100vmax/);
  assert.match(homeSection, /clip-path:\s*inset\(0 -100vmax\)/);
  assert.match(resourceLinks, /record-health-check-extensions/);
  assert.match(resourceLinks, /Recipes repository/);
  assert.match(resourceLinks, /View Slides/);
  assert.match(resourceLinks, /View Demo/);
  assert.equal(resourceLinks.match(/Coming soon/g)?.length, 3);
  assert.match(resourceLinks, /aria-disabled="true"/);
  assert.match(resourceLinks, /min-height:\s*8\.5rem/);
  assert.equal(examples.match(/evaluationType:/g)?.length, 4);
  assert.match(examples, /Verify with a formula/);
  assert.match(examples, /Verify with a query/);
  assert.match(examples, /Compare two queries/);
  assert.match(examples, /Verify with Apex/);
  assert.match(
    examples,
    /order: 1,[\s\S]*?evaluationType: 'Verify with a formula'/
  );
  assert.match(
    examples,
    /order: 2,[\s\S]*?evaluationType: 'Verify with a query'/
  );
  assert.match(
    examples,
    /order: 3,[\s\S]*?evaluationType: 'Compare two queries'/
  );
  assert.match(examples, /order: 4,[\s\S]*?evaluationType: 'Verify with Apex'/);
  assert.match(
    examples,
    /examples\.sort\(\(first, second\) => first\.order - second\.order\)/
  );
  assert.match(examples, /<details class="example-card" open=\{index === 0\}>/);
  assert.match(examples, /AccountStrategicReadinessCheck/);
  assert.match(examples, /Lists overlap/);
  assert.match(examples, /COUNT\(\)/);
  assert.match(examples, /BillingCity = Parent\.BillingCity/);
  assert.match(examples, /\['Display: Found Formula', 'BillingCity'\]/);
  assert.match(
    examples,
    /\['Display: Expected Formula', 'Parent\.BillingCity'\]/
  );
});

test("homepage avoids repeating the product name after the hero establishes context", async () => {
  const [homePage, guidedPath, resourceLinks] = await Promise.all([
    readRepositoryFile("site/src/content/home.mdx"),
    readRepositoryFile("site/src/components/GuidedPath.astro"),
    readRepositoryFile("site/src/components/ResourceLinks.astro")
  ]);

  assert.doesNotMatch(homePage, /See what Record Health Check can solve/);
  assert.doesNotMatch(homePage, /extending Record Health Check/);
  assert.doesNotMatch(homePage, /title="New to Record Health Check"/);
  assert.match(homePage, /title="Start with the basics"/);
  assert.doesNotMatch(guidedPath, /What Record Health Check does/);
  assert.match(guidedPath, /Understand what it does/);
  assert.doesNotMatch(resourceLinks, /introduce Record Health Check/);
  assert.doesNotMatch(resourceLinks, /Watch Record Health Check/);
});

test("homepage uses spacing and surfaces instead of decorative borders", async () => {
  const [hero, examples, footer, homeSection, resourceLinks] =
    await Promise.all([
      readRepositoryFile("site/src/components/SiteHero.astro"),
      readRepositoryFile("site/src/components/UseCaseExamples.astro"),
      readRepositoryFile("site/src/components/ArticleFooter.astro"),
      readRepositoryFile("site/src/components/HomeSection.astro"),
      readRepositoryFile("site/src/components/ResourceLinks.astro")
    ]);

  const licenseStyles = hero.match(/\.license\s*\{([\s\S]*?)\}/)?.[1] ?? "";
  const previewStyles =
    hero.match(/\.product-preview\s*\{([\s\S]*?)\}/)?.[1] ?? "";
  const footerStyles =
    footer.match(/\.site-footer\s*\{([\s\S]*?)\}/)?.[1] ?? "";
  const linkCardStyles =
    homeSection.match(
      /\.section-content :global\(\.sl-link-card\)\s*\{([\s\S]*?)\}/
    )?.[1] ?? "";
  const resourceCardStyles =
    resourceLinks.match(/\.resource-card\s*\{([\s\S]*?)\}/)?.[1] ?? "";
  const exampleCardStyles =
    examples.match(/\.example-card\s*\{([\s\S]*?)\}/)?.[1] ?? "";

  assert.doesNotMatch(licenseStyles, /border:/);
  assert.match(licenseStyles, /background:/);
  assert.doesNotMatch(previewStyles, /border:/);
  assert.doesNotMatch(footerStyles, /border-top:/);
  assert.doesNotMatch(examples, /border-top:/);
  assert.doesNotMatch(examples, /border-bottom:/);
  assert.doesNotMatch(examples, /border-inline-end:/);
  assert.doesNotMatch(examples, /border-inline-start:/);
  assert.match(
    examples,
    /<div class="examples not-content">/,
    "The custom accordions must opt out of Starlight's bordered prose details style"
  );
  assert.match(examples, /\.configuration dl > div[\s\S]*background:/);
  assert.match(
    homeSection,
    /\.tone-accent[\s\S]*--section-background:\s*var\(--sl-color-bg\)/
  );
  assert.match(linkCardStyles, /border:\s*0 !important/);
  assert.match(linkCardStyles, /box-shadow:\s*none !important/);
  assert.doesNotMatch(resourceCardStyles, /box-shadow:/);
  assert.doesNotMatch(exampleCardStyles, /box-shadow:/);
  assert.doesNotMatch(resourceLinks, /var\(--sl-color-accent-low\)/);
});

test("homepage examples explain the concept without duplicating full reference content", async () => {
  const examples = await readRepositoryFile(
    "site/src/components/UseCaseExamples.astro"
  );

  assert.doesNotMatch(examples, />What the Check evaluates</);
  assert.doesNotMatch(examples, />Expected behavior</);
  assert.match(examples, /example\.configuration\s*\.filter/);
  assert.match(examples, /configurationHighlights/);
  assert.match(examples, /View full configuration/);
  assert.doesNotMatch(examples, /Open the complete example/);
  assert.doesNotMatch(examples, /Open the complete configuration/);
  assert.doesNotMatch(examples, /Open the full address-alignment example/);
  assert.match(examples, />Found and expected</);
  assert.doesNotMatch(examples, />How it decides</);
  assert.equal(examples.match(/foundExpression:/g)?.length, 4);
  assert.equal(examples.match(/expectedExpression:/g)?.length, 4);
  assert.equal(examples.match(/foundValue:/g)?.length, 4);
  assert.equal(examples.match(/expectedValue:/g)?.length, 4);
  assert.doesNotMatch(examples, /decisionExpression:/);
  assert.equal(examples.match(/decisionExplanation:/g)?.length, 4);
  assert.match(examples, /foundExpression: 'BillingCity'/);
  assert.match(examples, /expectedExpression: 'Parent\.BillingCity'/);
  assert.match(examples, /<code>\{example\.foundExpression\}<\/code>/);
  assert.match(examples, /<code>\{example\.expectedExpression\}<\/code>/);
  assert.doesNotMatch(examples, /Found ≤ Expected/);
  assert.doesNotMatch(examples, /Found overlaps Expected/);
  assert.doesNotMatch(examples, /Found ≥ Expected/);
  assert.doesNotMatch(examples, /align-self:\s*start/);
  assert.match(
    examples,
    /account-check-builder-guide\/#check-30-billing-address-matches-the-parent-bill-to-account/
  );
  assert.match(
    examples,
    /\.configuration dl > div[\s\S]*grid-template-columns:\s*1fr/
  );
  assert.match(examples, /@media \(max-width:\s*63\.99rem\)/);
});

test("landing page turns the guided path into three focused stages", async () => {
  const [homePage, guidedPath] = await Promise.all([
    readRepositoryFile("site/src/content/home.mdx"),
    readRepositoryFile("site/src/components/GuidedPath.astro")
  ]);

  assert.match(homePage, /import GuidedPath/);
  assert.match(homePage, /<GuidedPath \/>/);
  assert.deepEqual(
    [...guidedPath.matchAll(/stage:\s*'(\d+)'/g)].map((match) => match[1]),
    ["01", "02", "03"]
  );
  assert.equal([...guidedPath.matchAll(/href:\s*'/g)].length, 6);
  assert.doesNotMatch(guidedPath, /border:/);
  assert.doesNotMatch(guidedPath, /box-shadow:/);
});

test("landing and article feedback copy state the positive user outcome", async () => {
  const [homePage, footer] = await Promise.all([
    readRepositoryFile("site/src/content/home.mdx"),
    readRepositoryFile("site/src/components/ArticleFooter.astro")
  ]);

  assert.match(homePage, /Choose what you want to do/);
  assert.doesNotMatch(homePage, /not browsing folders/i);
  assert.doesNotMatch(homePage, /without blocking/i);
  assert.match(footer, /Improve this page/);
  assert.doesNotMatch(footer, /View source/);
  assert.doesNotMatch(footer, /createSourceUrl/);
  assert.doesNotMatch(footer, /unclear or incorrect/i);
});

test("every documentation page uses direct task-focused structural copy", async () => {
  const pages = await listMarkdownFiles("docs/");
  const issues = [];
  const negativeFramingHeading =
    /^#{1,2}\s+(?:What .+ (?:is not|does not)|If .+ (?:does not|fails?)|When .+ (?:is wrong|is not enough)|Features not tested.+|They are not mutually exclusive|These actions do not.+|What is never.+|Actions .+ must not.+|Integration tests \(not shipped\)).*$/gim;

  for (const page of pages) {
    const markdown = await readRepositoryFile(page);
    const opening = markdown.split("\n").slice(0, 20).join("\n");
    if (/^>\s+On this page,/im.test(markdown)) {
      issues.push(`${page}: remove the narrated 'On this page' opener`);
    }
    if (/^(?:This (?:page|guide|reference)|Use this page)\b/im.test(opening)) {
      issues.push(`${page}: lead with the reader's task or outcome`);
    }
    for (const match of markdown.matchAll(negativeFramingHeading)) {
      if (/^## If it does not work$/i.test(match[0])) continue;
      issues.push(
        `${page}: reframe heading '${match[0].replace(/^#+\s+/, "")}'`
      );
    }
  }

  assert.equal(issues.join("\n"), "");
});

test("documentation issue links preserve page-specific context", () => {
  const issueUrl = new URL(
    createDocumentationIssueUrl({
      title: "Configure a query check",
      pageUrl: "https://docs.recordhealthcheck.com/build-checks/query/",
      sourcePath: "docs/build-checks/query.md"
    })
  );

  assert.equal(
    `${issueUrl.origin}${issueUrl.pathname}`,
    "https://github.com/gkolan/record-health-check/issues/new"
  );
  assert.equal(issueUrl.searchParams.get("template"), "documentation.yml");
  assert.equal(
    issueUrl.searchParams.get("title"),
    "Docs: Configure a query check"
  );
  assert.equal(
    issueUrl.searchParams.get("page"),
    "https://docs.recordhealthcheck.com/build-checks/query/"
  );
  assert.equal(
    issueUrl.searchParams.get("source"),
    "docs/build-checks/query.md"
  );
});

test("every article receives the global correction action", async () => {
  const [astroConfig, footer] = await Promise.all([
    readRepositoryFile("site/astro.config.mjs"),
    readRepositoryFile("site/src/components/ArticleFooter.astro")
  ]);

  assert.match(
    astroConfig,
    /Footer:\s*["']\.\/src\/components\/ArticleFooter\.astro["']/
  );
  assert.match(footer, /createDocumentationIssueUrl/);
  assert.match(footer, /<a href=\{issueUrl\}>Improve this page<\/a>/);
});

test("the public site is canonical and excludes historical documentation trees", async () => {
  const prepareScript = await readRepositoryFile(
    "site/scripts/prepare-content.mjs"
  );

  assert.match(
    prepareScript,
    /const sourceRoot = path\.join\(repositoryRoot, "docs"\)/
  );
  assert.match(
    prepareScript,
    /sourcePath !== path\.join\(sourceRoot, "README\.md"\)/
  );
});

test("the documentation issue form captures actionable correction details", async () => {
  const issueForm = await readRepositoryFile(
    ".github/ISSUE_TEMPLATE/documentation.yml"
  );

  assert.match(issueForm, /id:\s*page/);
  assert.match(issueForm, /id:\s*source/);
  assert.match(issueForm, /id:\s*correction/);
  assert.match(issueForm, /id:\s*suggested/);
});
