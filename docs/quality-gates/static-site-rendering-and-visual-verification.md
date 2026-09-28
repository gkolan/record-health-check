# Verify static-site rendering and visual integrity

Prevent documentation and site-infrastructure changes from shipping broken generated HTML or
unusable layouts. The repository maintains articles as Markdown, transforms them into Astro
content, and publishes static HTML. A valid Markdown file is therefore only the first input to the
reader-facing result.

Published page: [Static-site rendering and visual verification](https://docs.recordhealthcheck.com/quality-gates/static-site-rendering-and-visual-verification/).

The guidance below records the failure modes discovered during the complete rendered-site review
on September 26, 2026, the controls added afterward, and the evidence required for future changes.
It prevents every maintainer or coding agent from having to rediscover the same boundaries.

## Why source checks were not enough

Source-level formatting, Markdown structure, and link checks remain necessary, but they do not
observe the generated browser document. The content passes through several independent boundaries:

1. A maintainer edits canonical Markdown under `docs/`.
2. `site/scripts/prepare-content.mjs` rewrites links, removes the source title, creates frontmatter,
   and converts supported GitHub alerts to Starlight callouts.
3. Astro and Starlight parse the prepared content and generate static HTML under `site/dist/`.
4. `site/src/lib/accessible-task-lists.mjs` repairs generated task-list semantics after the build.
5. Browser JavaScript, CSS, fonts, images, responsive layout, and accessibility semantics determine
   the final reader experience.

A source file can be perfectly formatted at boundary 1 and still be wrong at boundaries 3 through 5. For example, a blank line inside a long Markdown table is syntactically harmless to a formatter
but ends the table. Later rows then appear as literal pipe-delimited prose in the generated page.
The quality gate must therefore inspect the final HTML, not infer it from source.

## Lessons from the complete rendered-site review

The review built 160 routes and captured each route at desktop and mobile sizes, producing 320
full-page screenshots. It found three distinct classes of defects and one evidence-handling risk.

| Lesson                                | Observed failure                                                                                                     | Durable response                                                                                                                                           |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Inspect generated output              | Five rows after a blank line escaped a long Markdown table and rendered as literal `\| value \|` text                | `check:rendered` scans every generated page for raw Markdown patterns outside code examples and real HTML tables                                           |
| Escape table-cell delimiters          | An inline code example containing `\| value \|` split its surrounding lesson table during this guide's first build   | Escape literal pipes inside Markdown table cells, then verify the generated table rather than trusting the formatter                                       |
| Preserve heading order                | A page moved directly from its page title to a level-three example heading                                           | The generated-output gate rejects a heading increase of more than one level                                                                                |
| Test generated accessibility          | GitHub-style task lists produced disabled checkboxes without accessible names on five pages                          | A build integration adds an `aria-label` from the visible checklist item, with a regression test and generated-output check                                |
| Keep the auditor, not only its output | The first browser-audit script lived under ignored `reports/`, so a future checkout would not receive it             | The reusable auditor is tracked at `site/scripts/audit-rendered-pages.mjs`; only timestamped evidence remains ignored                                      |
| Separate defects from transport noise | One localhost asset request reset during a complete run even though the page and asset were valid                    | Preserve the original manifest, rerun the exact affected route at both viewports, and retain both results instead of deleting or silently editing evidence |
| Visual review remains human work      | Automated checks can measure overflow and broken assets but cannot decide whether a page is pleasant or easy to scan | The browser audit creates a gallery, and the reviewer must inspect every screenshot when the complete audit is required                                    |

These lessons apply to the whole static site. Do not fix only the page where a symptom first
appears when the converter, component, or stylesheet can affect sibling pages.

## Required verification by change type

Use the strongest row that matches the change. When several rows apply, satisfy all of them.

| Change                                                         | Required commands                                                                                        | Required review                                                                   |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Text-only change to one article                                | `npm run check:docs`, `npm run check:docs:site`                                                          | Read the complete source page and its generated page                              |
| New page, renamed page, or navigation change                   | `npm run check:docs`, `npm run check:docs:links`, `npm run check:docs:site`, `npm run audit:docs:render` | Confirm sidebar placement, previous and next navigation, and both viewports       |
| Markdown preparation or conversion change                      | `npm run check:docs:site`, `npm run audit:docs:render`                                                   | Review every screenshot because all articles share the converter                  |
| Astro, Starlight, or site dependency update                    | `npm run check:docs:site`, `npm run audit:docs:render`, then the complete `npm run ci:gates`             | Review every screenshot, browser error, asset request, and responsive state       |
| Global component, CSS, typography, width, or responsive change | `npm run check:docs:site`, `npm run audit:docs:render`                                                   | Review every desktop and mobile screenshot, including long tables and code blocks |
| Fix for a newly discovered rendering defect                    | Add a failing regression first, then run `npm run check:docs:site` and the applicable browser audit      | Confirm the regression fails without the fix and passes with it                   |

`npm run ci:gates` remains the complete pull-request authority. The focused commands shorten the
feedback loop; they do not replace the full source-gate run before pull-request handoff.

Record Health Check Custom Metadata fixtures are not applicable to this repository-only site
behavior. The generated-HTML fixture and browser screenshot manifest are the equivalent executable
evidence.

## What the CI gate checks

`npm run check:docs:site` performs four stages in order:

1. Runs the documentation-site contract and regression tests.
2. Prepares all canonical articles and builds the static site.
3. Verifies every internal page and fragment link.
4. Runs `site/scripts/check-rendered-output.mjs` against every generated HTML page.

The final stage delegates page inspection to `site/src/lib/rendered-output.mjs`. It fails when a
generated page contains any of these conditions:

- no `<main>` element or no visible main content;
- anything other than one main level-one heading on a normal page;
- a heading-level jump such as level one directly to level three;
- an empty heading;
- visible Markdown fences, GitHub alert markers, links, headings, tables, or MDX imports and exports;
- a generated task-list checkbox without `aria-label`, `aria-labelledby`, or `title`;
- an anchor without a non-empty `href`; or
- visible `undefined` or `[object Object]` output.

Code samples and real generated tables are deliberately excluded from raw-Markdown matching. A
page is allowed to teach Markdown syntax inside a code element; it is not allowed to expose that
syntax as ordinary reader-facing prose.

The gate reads every HTML file in `site/dist/`. A new page automatically joins the inspection set,
so contributors do not maintain a separate route allowlist.

## Run and review the complete browser audit

From the repository root, install the pinned dependencies and run:

```bash
npm ci
npm ci --prefix site
npm run audit:docs:render
```

The command performs its own production build, starts an isolated local static server, opens a
headless Chromium browser, and visits every generated route at these viewports:

| Viewport | Size        | Purpose                                                                    |
| -------- | ----------- | -------------------------------------------------------------------------- |
| Desktop  | 1440 × 1000 | Sidebar, article, table of contents, wide tables, and full desktop spacing |
| Mobile   | 390 × 844   | Narrow navigation, wrapping, touch-width content, and horizontal overflow  |

For each viewport and route, the auditor:

- waits for the page and network to become idle;
- waits for document fonts;
- records browser console errors, uncaught page errors, and failed local requests;
- identifies broken images and horizontal document overflow;
- applies every generated-output structural check; and
- writes a full-page PNG screenshot.

Evidence is written to a timestamped directory:

```text
reports/docs-render-audit/<timestamp>/
├── desktop/
├── mobile/
├── index.html
└── manifest.json
```

Open `index.html` and review every card. A green `PASS` label means the automated observations were
clean; it does not replace visual inspection. At minimum, verify:

- headings are readable and remain associated with their content;
- tables have not become prose, clipped, or unusably narrow;
- code blocks remain distinct and scroll without widening the entire page;
- callouts, task lists, screenshots, and inline links retain their intended meaning;
- the sidebar and table of contents do not cover the article;
- long labels and URLs wrap without overlap;
- footer actions remain reachable; and
- the mobile page has no unexpected horizontal scroll.

The manifest is the machine-readable record. Confirm that `pageCount` matches the build, that
`screenshotCount` is twice the page count, and that `issuePageCount` is zero.

## Rerun one or more affected routes

Use `AUDIT_ROUTES` only to investigate or confirm a finding after a complete run. Supply the exact
comma-separated built routes, including leading and trailing slashes:

```bash
AUDIT_ROUTES=/architecture/apex-implementation/,/build-checks/add-fix-link/ \
  npm run audit:docs:render
```

A targeted run does not replace the required complete run. Keep both manifests. If a browser or
localhost transport error disappears on retry, describe it as a clean targeted retry after a
transient failure. Do not rewrite the original result as though the failure never occurred.

If a route supplied through `AUDIT_ROUTES` does not exist, the auditor selects no matching page.
Inspect the printed `PAGES` and `SCREENSHOTS` counts so an empty selection is never mistaken for a
successful verification.

## Interpret failures without weakening the guard

Use the failure category to choose the next action:

| Finding                      | First place to inspect                                                 | Required response                                                                      |
| ---------------------------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Raw Markdown table           | Blank lines, row widths, and table delimiters in the canonical article | Correct the table source and add or preserve a regression fixture                      |
| Raw callout marker           | `transformGitHubAlerts` and the source blockquote shape                | Correct the supported conversion or source syntax; do not hide the marker with CSS     |
| Heading jump                 | Canonical heading levels and generated component headings              | Restore the semantic sequence rather than styling a lower-level heading to look larger |
| Unnamed checkbox             | Task-list post-processing and the visible list-item label              | Preserve an accessible name derived from meaningful visible text                       |
| Anchor without destination   | Generated component or transformed Markdown link                       | Supply a real destination or remove the nonfunctional control                          |
| Broken image or failed asset | Public asset copy, generated path, and server response                 | Fix the asset pipeline and rerun the affected route at both viewports                  |
| Horizontal overflow          | Wide tables, code blocks, long tokens, and global width rules          | Contain the specific content without hiding information or disabling useful scrolling  |
| Browser error                | Console stack, failed request, and relevant component script           | Correct the runtime failure; do not downgrade console errors in the auditor            |

When the checker itself reports a false positive, create one valid and one invalid fixture before
changing it. The valid fixture defines what must remain allowed. The invalid fixture preserves the
failure the checker exists to catch.

## Keep the lesson visible to future agents

The durable information is intentionally split by ownership:

| Owner                                                                                   | What it preserves                                                              | How removal is detected                                                                                             |
| --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------- |
| Root `AGENTS.md`                                                                        | Mandatory commands, change triggers, and the requirement to review the gallery | `documentation-site.test.mjs` requires the rendering-contract section and commands                                  |
| `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`, `.cursor/rules/agents.mdc` | Pointers that make the root agreement the single agent source of truth         | `check:docs` fails if a pointer is missing or no longer points to `AGENTS.md`                                       |
| This page                                                                               | Detailed rationale, procedures, evidence interpretation, and troubleshooting   | The documentation-site regression requires this page, its critical headings, commands, public URL, and owning links |
| `documentation-standard.md`                                                             | The general rule for reviewing generated documentation                         | Normal documentation structure and link gates                                                                       |
| Generated-output checker                                                                | Fast inspection of every built page in every CI run                            | `check:docs:site`, which is declared in the shared source-gate list                                                 |
| Browser auditor                                                                         | Reproducible desktop and mobile evidence for site-wide changes                 | The agent contract and this page require the tracked command for specified change types                             |

Agents receive the root `AGENTS.md` at session start. The model-specific files are short pointers,
not competing copies, so a rule change has one authoritative location. Do not duplicate this full
procedure into every pointer file; duplication would create several stale versions of the same
contract.

Local `internal/agent-notes.md` is for environment facts or decisions that are not visible in the
repository. Do not place this rendering contract there. A local note is not available to CI,
contributors, or fresh clones.

## Add a regression when a new failure is found

Treat a new documentation-rendering failure like a product defect:

1. Save the exact route, viewport, generated snippet, and screenshot that demonstrate the problem.
2. Identify the lowest stable boundary that reproduces it: source transform, generated HTML, browser
   runtime, or responsive layout.
3. Add a focused test or fixture before changing the implementation.
4. Run the test against the broken state and confirm it fails for the observed reason.
5. Implement the smallest correction at the owning boundary.
6. Run the focused test and `npm run check:docs:site` to green.
7. Run `npm run audit:docs:render` when the defect or fix can affect multiple pages or visual layout.
8. Review the complete gallery when a full audit is required.
9. Update this page when the incident establishes a reusable lesson, new failure category, or changed
   evidence requirement.
10. Record the red result, green result, commands, route count, screenshot count, and evidence path in
    the pull request.

Do not make a test assert implementation details that can change without affecting readers. Assert
the generated contract: usable content, correct structure, accessible controls, working assets, and
stable layout.

## Completion checklist

Before completing a documentation or site-rendering change, confirm every applicable item:

- [ ] Canonical source lives under `docs/`; generated content under `site/src/content/docs/` was not
      edited as a second source of truth.
- [ ] Every affected canonical page was read from title through final related link.
- [ ] `npm run check:docs` passes.
- [ ] `npm run check:docs:site` builds and inspects every generated page.
- [ ] Internal links and fragments pass after generation.
- [ ] A new defect has a red-before-green regression at the lowest stable boundary.
- [ ] `npm run audit:docs:render` was run when conversion, navigation, global presentation, responsive
      behavior, or dependencies changed.
- [ ] The complete gallery was reviewed when the browser audit was required.
- [ ] The manifest route count matches the build and contains two screenshots per page.
- [ ] Any targeted retry is retained alongside, not substituted for, the complete-run evidence.
- [ ] Pull-request verification distinguishes source, generated HTML, browser, and hosted evidence.
- [ ] The complete CI source-gate list passes before the branch is described as CI-ready.

## Related

- [Documentation standard](./documentation-standard.md)
- [Regression testing standard](./regression-testing-standard.md)
- [Quality gates](./README.md)
- [Contributing](../contributing/README.md)
- [Source development](../contributing/source-development.md)
- [Documentation site implementation](../../site/README.md)
