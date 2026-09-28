# Record Health Check documentation site

This is the public Record Health Check documentation site. It is a static Astro Starlight site
intended for Vercel. `docs/` is the canonical content source and the public UI does not use version
branding.

Published site: [docs.recordhealthcheck.com](https://docs.recordhealthcheck.com/). The public
[static-site rendering and visual verification guide](https://docs.recordhealthcheck.com/quality-gates/static-site-rendering-and-visual-verification/)
owns the conversion lessons, complete audit procedure, and evidence checklist.

## Local development

```bash
npm ci --prefix site
npm run dev --prefix site
```

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
| Deployment                     | Vercel produces a static site with clean trailing-slash URLs                         | `vercel.json` and static build                               |

Record Health Check Custom Metadata fixtures are not applicable: this feature changes only the
repository documentation renderer and has no Salesforce runtime behavior. The static build and
site-contract tests are its executable fixtures.
