# Languages, locale, and translated text

> [!NOTE]
> This page explains which text Salesforce can translate, which values use the running user's
> locale, and which Check text an administrator must maintain in the required language.

Language and locale are related but different:

- **Language** controls translated labels, such as a translated picklist label.
- **Locale** controls how Salesforce displays numbers and dates, such as `70,000.50` or `70.000,50`.
- **Time zone** controls the date and time shown for a Date/Time value.

Record Health Check uses the settings of the user who runs the Check.

## What Record Health Check can translate

The package includes Salesforce Custom Labels for:

- **Yes** and **No**; and
- the comparison wording shown between Found and Expected, such as **to equal**, **at least**, and
  **to contain all of**.

An administrator can translate these package Custom Labels with Salesforce Translation Workbench.
The package currently supplies the `en_US` values; your org must supply any additional translations.

In Setup, enter `Translation Language Settings` in Quick Find and enable the required language.
Then open **Translate**, select the language and the **Custom Labels** setup component, and search
the installed Record Health Check labels. Translate the Yes, No, and comparison labels used by the
card; do not change their API names.

Status API values such as `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` do not change
by language. Automation must use these stable API values, not wording shown to a user.

## What Salesforce formats for each user

| Result value | What the user sees |
| --- | --- |
| Number, Currency, Percent, or Ratio as Percent | The user's decimal mark and digit-grouping style |
| Date | The user's Salesforce date format |
| Date/Time | The user's Salesforce date, time, and time-zone settings |
| Picklist value | The translated picklist label when the org has one; otherwise the available Salesforce label |
| Checkbox or Boolean | The translated Record Health Check **Yes** or **No** Custom Label |
| Currency in a single-currency org | The currency symbol where Salesforce can provide it |
| Currency in a multiple-currency org | The ISO currency code, such as `USD` or `EUR` |

Example: two users can run the same Check against the same amount. One might see `70,000.50`; the
other might see `70.000,50`. The Check result remains the same because formatting happens after the
comparison.

See [Display value format](../contracts/display-value-format.md) for every supported format.

## Which Check text is not translated automatically?

Text entered in Record Health Check Custom Metadata is ordinary text. Translation Workbench does
not create a different version for each user language.

This includes:

- Card Title and Card Subtitle;
- Run and Rerun button labels;
- Check Title and Check Description;
- Failure Message, Fix Message, Unable to Evaluate Message, and Applicability Not Met Message; and
- Action Label.

For example, if **Failure Message** contains `Enter the Account's billing country`, every user sees
that sentence in English unless your team chooses a different configuration for that audience.

## Plan a Check Set for users in more than one language

Choose an approach before rollout:

| Approach | When it fits | What the administrator maintains |
| --- | --- | --- |
| One shared language | Everyone can work in the same business language | One Check Set |
| Separate Check Sets by language | Different groups require fully translated titles and messages | One Check Set per language, plus a clear way to place the correct Check Set on the record page used by each group |
| Custom user interface | Language must be selected dynamically for each user | Your own component or automation that uses stable result fields and supplies translated wording |

Test the chosen record-page assignments and visibility rules with a user from every intended
language group. Record Health Check does not choose a Check Set automatically from `User.LanguageLocaleKey`.
In Lightning App Builder, place the language-specific component on the relevant app or record-page
activation and use component visibility where your design can identify the intended audience.

## Comparisons do not use translated display text

Record Health Check compares Salesforce values, not the translated words shown on screen. For
example, a Check against the Account `Industry` picklist compares its stored API value. A translated
picklist label can change what the user reads, but it does not change `PASS` or `FAIL`.

This also means a translation must not be placed in **Expected Fixed Value** when the Check needs a
picklist API value. Use the stored value required by the field and let Salesforce translate the
display label.

For example, if Account **Industry** shows a translated label for the stored `Technology` value,
enter `Technology` in **Expected Fixed Value**, not the translated screen text.

Before rollout, go to **Setup → Users → Users**, open representative users, and confirm their
Language, Locale, and Time Zone. Log in as or use a sandbox test user for each supported combination
and verify the card on its activated record page.

## Merge tokens do not translate a sentence

A merge token inserts a value into the surrounding message. It does not translate the message
itself.

```text
Review {!record.Name fallback="this Account"} before approval.
```

The Account name is inserted, but `Review` and `before approval` remain exactly as the administrator
wrote them. Result tokens such as `{!rhcResult.foundValue}` use the already formatted display value.
See [Merge tokens](../contracts/merge-tokens.md) for available tokens and fallback behavior.

## Related

- [Display value format](../contracts/display-value-format.md)
- [Merge tokens](../contracts/merge-tokens.md)
- [Compatibility requirements](compatibility.md)
- [Configure Check Sets and Checks](../../guides/configure-check-sets-and-checks.md)
