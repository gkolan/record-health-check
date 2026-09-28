# Record Health Check documentation site

This is the public Record Health Check documentation site. It is a static Astro Starlight site
designed to publish from GitHub Actions to Cloudflare Pages. `docs/` is the canonical content source
and the public UI does not use version branding.

Published site: [docs.recordhealthcheck.com](https://docs.recordhealthcheck.com/). The public
[static-site rendering and visual verification guide](https://docs.recordhealthcheck.com/quality-gates/static-site-rendering-and-visual-verification/)
owns the conversion lessons, complete audit procedure, and evidence checklist.

## Local development

```bash
npm ci --prefix site
npm run dev --prefix site
```

To verify the same production artifact that Cloudflare serves:

```bash
npm run build --prefix site
npm run check:links --prefix site
npm run check:rendered --prefix site
npm run check:seo --prefix site
npm run preview --prefix site -- --host 127.0.0.1 --port 4321
```

Then open `http://127.0.0.1:4321/`. The SEO check inspects every generated page plus the sitemap,
robots directives, social image, JSON-LD, and agent discovery files.

## Cloudflare Pages deployment

The `Deploy documentation to Cloudflare Pages` workflow deploys `site/dist` after all documentation
site gates pass on the documentation source branch. Configure the GitHub `documentation-production`
environment with:

- secret `CLOUDFLARE_API_TOKEN` scoped to Cloudflare Pages edits;
- secret `CLOUDFLARE_ACCOUNT_ID` containing the target account ID; and
- repository variable `CLOUDFLARE_PAGES_PROJECT` containing the existing Pages project name.

Attach `docs.recordhealthcheck.com` as the Pages custom domain after the first successful deployment.
The Pages project should not also use Cloudflare's Git integration; GitHub Actions is the single
deployment owner and supplies the immutable, already-verified `site/dist` artifact.

The preparation step generates `site/src/content/docs/` from the canonical Markdown and copies
public images. Both outputs are ignored so the published article text has one source of truth.

## Plausible analytics

Plausible is optional and is added only when `PLAUSIBLE_SCRIPT_URL` is present during the build.
After adding `docs.recordhealthcheck.com` to Plausible, copy the personalized script URL shown under
**Site settings → General → Site installation** and add it to the hosting provider as a production
environment variable:

```text
PLAUSIBLE_SCRIPT_URL=https://plausible.io/js/pa-XXXXX.js
```

Leave the variable unset for local development and untracked preview builds. In Plausible, enable
outbound link tracking to measure the Sandbox install, Production install, GitHub, correction, and
page-source actions without adding click handlers to the documentation site.

## Acceptance scenarios

| Journey                        | Required outcome                                                                     | Automated evidence                                           |
| ------------------------------ | ------------------------------------------------------------------------------------ | ------------------------------------------------------------ |
| First visit                    | Product purpose plus Sandbox, Production, and GitHub actions are immediately visible | `documentation-site.test.mjs` and static build               |
| Find an answer                 | Search and task-based navigation include canonical documentation only                | Static build and generated-content assertions                |
| Correct an article             | Every rendered article has a page-specific GitHub correction link and source link    | Global footer override contract test                         |
| Prevent conversion regressions | Every built page rejects raw Markdown and invalid generated structure                | `npm run check:docs:site`                                    |
| Review site-wide presentation  | Every route is captured at desktop and mobile sizes                                  | `npm run audit:docs:render`                                  |
| Narrow screen                  | Navigation, action groups, and wide tables remain usable                             | Responsive CSS; browser regression coverage is the next gate |
| Deployment                     | Cloudflare Pages serves the verified static site with clean trailing-slash URLs      | GitHub workflow and static build                             |
| Search and sharing             | Every public page has canonical, social, structured, and agent-readable metadata     | `npm run check:seo --prefix site`                            |

Record Health Check Custom Metadata fixtures are not applicable: this feature changes only the
repository documentation renderer and has no Salesforce runtime behavior. The static build and
site-contract tests are its executable fixtures.
