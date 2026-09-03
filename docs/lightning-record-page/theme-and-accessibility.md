# Theme and accessibility

> [!NOTE]
> You cannot select a Record Health Check theme. Skip this page unless the card looks inconsistent
> with the active Salesforce theme or you are validating a Salesforce UI change.

Use this guide to confirm theme, keyboard, and responsive behavior on an activated record page.

## Outcome

After this check, you will know whether one Record Health Check component placement follows the
Salesforce theme, remains usable with a keyboard, and adapts to the available page width. You will
also have confirmed that no separate component theme setting is required.

## No theme setting is required

Add Record Health Check to a Lightning record page and select the Check Set to display. You do not
choose a theme on the component. The card uses the theme applied by Salesforce, including standard
Lightning styling and the Salesforce Cosmos theme.

To review the active org theme, open **Setup → Themes and Branding**. A theme choice changes the
Salesforce experience; it does not add a separate Record Health Check setting.

For an administrator, this means the same component placement continues to work when the Salesforce
theme changes. You do not need to remove and add the component again or maintain separate Lightning
pages for different themes.

## What remains consistent

The theme may change colors, corner shapes, spacing, and shadows. The card must still preserve:

- semantic structure and heading order;
- keyboard navigation and focus behavior;
- assistive labels and live-region announcements;
- Check ordering, statuses, actions, and diagnostics;
- responsive behavior and record-page configuration.

## Verify the card on a Lightning record page

After adding the component and selecting a Check Set:

1. Open a record whose object matches the Check Set, such as an Account for an Account Check Set.
2. Run the health check and confirm that Passed, Needs attention, Skipped, Unable to Check, and
   System Error rows are readable.
3. Use the Tab key to move through **Run**, **Rerun**, result details, and action links. Confirm that
   the currently selected control has a visible focus outline.
4. Narrow the browser window or test the page on a supported mobile device. Confirm that text wraps
   and controls remain usable without horizontal scrolling.
5. Confirm there is no theme or Design System property to configure for Record Health Check in
   Lightning App Builder.

## If the card looks inconsistent

First confirm that the issue also appears with browser zoom at 100 percent and without a user-side
style extension. In Lightning App Builder, select the Record Health Check component and review its
documented properties; there is no CSS override or theme field to reset.

| Symptom | Review |
| --- | --- |
| One page has different spacing or width | The Lightning page region, neighboring components, and component-level CSS overrides |
| Text or status colors are difficult to read | The active org theme, supported SLDS styling hooks, and browser accessibility settings |
| Cosmos and standard Lightning styling look different | Compare readability, keyboard focus, reading order, and behavior. Exact colors and corner shapes can differ between themes. |

## Related

- [Install and verify](../install/install-in-a-sandbox.md)
- [Configure metadata](../reference/custom-metadata/README.md)
- [Troubleshoot with diagnostics](../diagnostics/browser-console.md)
