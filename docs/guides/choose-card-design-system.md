# How the card follows your Salesforce theme

> [!NOTE]
> On this page, learn why Record Health Check has no theme setting and verify that the card is
> readable and usable on your Lightning record page.

## What you will confirm

You will confirm that one Record Health Check component placement follows the Salesforce theme,
remains usable with a keyboard, and adapts to the available page width. No separate component theme
setting is required.

## No theme setting is required

Add Record Health Check to a Lightning record page and select the Check Set to display. You do not
choose a theme on the component. The card uses the theme applied by Salesforce, including standard
Lightning styling and the Salesforce Cosmos theme.

For an administrator, this means the same component placement continues to work when the Salesforce
theme changes. You do not need to remove and add the component again or maintain separate Lightning
pages for different themes.

For a contributor, the component uses supported Salesforce Lightning Design System (SLDS) styling
hooks for surfaces, text, borders, corners, spacing, and shadows. When a specific hook is not
available, its stylesheet uses a supported Lightning value or a safe fallback.

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
2. Run the health check and confirm that Passed, Needs attention, Skipped, Unable to check, and
   System error rows are readable.
3. Use the Tab key to move through **Run**, **Rerun**, result details, and action links. Confirm that
   the currently selected control has a visible focus outline.
4. Narrow the browser window or test the page on a supported mobile device. Confirm that text wraps
   and controls remain usable without horizontal scrolling.
5. Confirm there is no theme or Design System property to configure for Record Health Check in
   Lightning App Builder.

If you contribute a styling change to this repository, run the SLDS linter and Jest tests before
submitting it.

## If the card looks inconsistent

| Symptom | Review |
| --- | --- |
| One page has different spacing or width | The Lightning page region, neighboring components, and component-level CSS overrides |
| Text or status colors are difficult to read | The active org theme, supported SLDS styling hooks, and browser accessibility settings |
| Cosmos and standard Lightning styling look different | Compare readability, keyboard focus, reading order, and behavior. Exact colors and corner shapes can differ between themes. |
| A code change no longer follows the Salesforce theme | Contributors should replace hard-coded visual values with supported SLDS styling hooks and keep a safe fallback. |

## Related

- [Install and verify](../installation/install-and-verify.md)
- [Configure metadata](../metadata/README.md)
- [Troubleshoot with diagnostics](troubleshoot-with-show-diagnostics.md)
