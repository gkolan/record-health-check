# Understand adaptive card styling

> [!NOTE]
> Use this page to understand how Record Health Check follows the active Salesforce design system without a per-component theme setting.

## One component placement

Add Record Health Check to a Lightning record page and select its Check Set. There is no Design
System property to maintain. The same placement works when the page uses established SLDS styling
or the Salesforce Cosmos theme.

Record Health Check uses supported semantic SLDS global styling hooks. In Cosmos, the current
surface, text, border, radius, spacing, and shadow hooks supply the visual treatment. Where a
semantic hook is unavailable, the stylesheet falls back to an established Lightning token and then
to a safe static value.

This approach avoids guessing the org theme from browser classes or undocumented runtime state.
Lightning base components continue to follow the design system selected by Salesforce.

## What remains consistent

The design system may change color, radius, spacing, and elevation. Record Health Check preserves:

- semantic structure and heading order;
- keyboard navigation and focus behavior;
- assistive labels and live-region announcements;
- Rule ordering, statuses, actions, and diagnostics;
- responsive behavior and record-page configuration.

## Verification checklist

After placing the card on a Lightning record page:

1. Open a matching record and confirm the card renders in the active org theme (established Lightning styling or Cosmos).
2. Confirm Pass, Fail, Skipped, Unable to Check, and System Error rows remain readable.
3. Confirm there is no Design System property on the component in Lightning App Builder.

After a Framework styling change (contributors only): run the SLDS linter and Jest suite.

## Related

- [Install and verify](../installation/02-install-and-verify.md)
- [Configure metadata](../metadata/README.md)
- [Troubleshoot with diagnostics](troubleshoot-with-show-diagnostics.md)
