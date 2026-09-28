import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import accessibleTaskLists from "./src/lib/accessible-task-lists.mjs";

const section = (label, directory) => ({
  label,
  collapsed: true,
  items: [{ autogenerate: { directory, collapsed: true } }]
});

const plausibleScriptUrl = process.env.PLAUSIBLE_SCRIPT_URL?.trim();
const plausibleHead = plausibleScriptUrl
  ? [
      {
        tag: "script",
        attrs: {
          async: true,
          src: plausibleScriptUrl
        }
      },
      {
        tag: "script",
        content:
          "window.plausible=window.plausible||function(){(plausible.q=plausible.q||[]).push(arguments)},plausible.init=plausible.init||function(options){plausible.o=options||{}};plausible.init();"
      }
    ]
  : [];

export default defineConfig({
  site: "https://docs.recordhealthcheck.com",
  integrations: [
    accessibleTaskLists(),
    starlight({
      title: "Docs.RecordHealthCheck",
      description:
        "Install, configure, operate, and extend Record Health Check for Salesforce.",
      favicon: "/assets/img/RHC_LOGO-96.png",
      customCss: ["./src/styles/custom.css"],
      head: plausibleHead,
      components: {
        Head: "./src/components/PageHead.astro",
        Header: "./src/components/SiteHeader.astro",
        Hero: "./src/components/SiteHero.astro",
        PageTitle: "./src/components/ArticleTitle.astro",
        Footer: "./src/components/ArticleFooter.astro"
      },
      social: [
        {
          icon: "github",
          label: "Record Health Check on GitHub",
          href: "https://github.com/gkolan/record-health-check"
        }
      ],
      sidebar: [
        section("Start here", "start-here"),
        section("Step-by-step guide", "step-by-step-guide"),
        section("Install", "install"),
        section("Build Checks", "build-checks"),
        section("Lightning record page", "lightning-record-page"),
        section("Examples", "examples"),
        section("Flow guides", "flow-guides"),
        section("Save results", "save-results"),
        section("Diagnostics", "diagnostics"),
        section("Production operations", "production-operations"),
        section("Developer guides", "developer-guides"),
        section("Architecture", "architecture"),
        section("Reference", "reference"),
        section("FAQs", "faqs"),
        section("Quality gates", "quality-gates"),
        section("Contributing", "contributing")
      ],
      lastUpdated: true,
      credits: false
    })
  ]
});
