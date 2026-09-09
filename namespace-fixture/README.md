# Separate-namespace Apex plugin fixture

This is the package-ready source for topology NS-03: an installed `rhc` package calling a global
plugin installed from a different managed namespace. It is deliberately independent of CPQ,
Advanced Approvals, subscriber fields, locale, currency, and time zone.

The tracked project file is a template because Salesforce namespaces and `04t` dependencies are
real registry assets, not names this repository can invent. Before use, a release owner supplies a
registered partner namespace and the exact 2.0.9 candidate ID in a private working copy. Creating
or publishing either package remains a release-owner action; this fixture does not perform it.

## Repeatable verification path

1. Copy `sfdx-project.json.template` to `sfdx-project.json` in this directory and replace both
   placeholders with the registered namespace and exact RHC candidate `04t`.
2. Create the fixture package and version in the authorized Dev Hub. The version must depend on
   the exact RHC candidate represented by the alias.
3. Install the RHC candidate and then the fixture candidate into an existing authorized subscriber
   org with no namespace of its own.
4. In a temporary copy of `subscriber-metadata`, replace the namespace placeholder in
   `rhc__Record_Health_Check.Partner_Namespace_Plugin.md-meta.xml`, then deploy that temporary copy.
5. Create an Account named `Partner Namespace Fixture` and evaluate
   `Partner_Namespace_Compatibility` through `rhc.RecordHealthCheck.evaluate` and the record card.
6. Require exactly one PASS with `PARTNER_NAMESPACE_PLUGIN_PASS`. Save both `04t` IDs, namespace,
   source commit, record ID, Apex test run, and card result.

The fixture package's own `RHCPartnerCompatibilityPluginTest` is a consumer-compilation test for
the complete global RHC surface it uses: interface, scope constructor and members, outcome factory,
value factory, fluent comparison, status, and reason. Its pass is necessary but not sufficient;
NS-03 is verified only after the installed-package public API and card call the explicitly
qualified partner class.

No NS-03 pass is currently claimed. A registered second namespace, a 2.0.9 candidate `04t`, and
release-owner authorization are still required to execute the install sequence.
