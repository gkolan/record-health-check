# Reference: Localization

> [!NOTE]
> On this page, learn what Record Health Check translates automatically through Salesforce
> Translation Workbench, what an administrator must translate by hand, and why comparisons never
> change based on the running user's language.

Use this page when planning a multi-language rollout, or when two users report seeing the same Rule
in different wording and you need to know whether that is expected.

## Two kinds of text, two owners

| Text | Owner | Translatable through Translation Workbench |
| --- | --- | --- |
| Framework labels: status words, operator phrases, Boolean Yes/No wording | Record Health Check (Custom Labels) | Yes |
| Administrator-authored Rule content: Check Title, Card Title, Failure Message, Fix Message, Action Label | The org's administrator (plain text fields) | No, not automatically. An org that needs multiple languages must author or translate this content itself |

Framework-owned wording ships as Salesforce Custom Labels, which Translation Workbench can translate
without touching a Rule's logic. Administrator-authored fields are ordinary Custom Metadata text
fields; Salesforce does not translate their content for you, and a Rule has only one
`FailureMessage__c` value regardless of who is reading it. See
[Display value format: Locale](../contracts/03-display-value-format.md#locale) for the boundary between
these two categories in the rendering pipeline.

## What is locale-aware automatically

Display value formatting reads the **running user's** locale, time zone, and language at the moment
a Rule evaluates, not the author's locale and not a fixed org default.

| Display element | Locale-aware behavior |
| --- | --- |
| Number, Currency, Percent, Ratio as Percent | Grouping separators and decimal marks follow the running user's locale (`70,000` vs `70.000`) |
| Date, Date/Time | Rendered in the running user's locale date/time format |
| Currency symbol vs ISO code | Symbol in a single-currency org, ISO code in a multi-currency org, independent of language |
| Picklist labels | Rendered in the running user's language when Salesforce has a translated label for that value |
| Boolean Yes/No, operator phrases | Framework Custom Labels; translated per the org's Translation Workbench configuration |

Two users viewing the same Rule result at the same moment can see different formatted text for
Found and Expected while the underlying value and the Pass/Fail outcome stay identical. That is
expected: formatting is a presentation concern layered on top of a comparison that already
finished. See [Display value format](../contracts/03-display-value-format.md) for every formatting rule.

## Comparisons always use API values, never labels

Pass/Fail decisions compare the raw values Salesforce returns, such as a picklist's stored API
value, never the translated label a user happens to see. A Rule that compares `Industry` to
`Technology` compares the API value `Technology`, regardless of which language label a French or
German user sees on their own screen. This is what makes a Rule's outcome stable across every
language the org supports.

## What an administrator must translate by hand

Salesforce Translation Workbench does not translate values inside Custom Metadata text fields. If a
multi-language org needs a Rule's message to read correctly in more than one language, choose one
of these approaches:

| Approach | Trade-off |
| --- | --- |
| Author the message in the org's dominant language and accept it will not localize | Simplest; acceptable when most users share one language |
| Create parallel Check Sets or Rules per language and route by profile, permission set, or page assignment | More configuration, but every user gets a fully native message; no Framework support required |
| Have the Rule author write English (or another shared language) and rely on the record's own locale-aware Found/Expected formatting to carry most of the meaning | Reduces, but does not remove, the need for translated prose |

Record Health Check ships no built-in mechanism for translating administrator-authored message
content per running-user language, because that content is business policy the org owns, not
Framework behavior.

## Merge tokens and localization

Merge tokens insert live Salesforce values into a message; they do not translate the surrounding
template text. `{!record.Name}` resolves to whatever the field holds regardless of language, and a
result token such as `{!rhcResult.foundValue}` already contains the display-formatted (and
therefore locale-aware) text produced by the rules in
[Display value format](../contracts/03-display-value-format.md). Add a quoted `fallback` when a token
might be blank in some languages' data, for example
`{!record.Name fallback="this record"}`, so the completed sentence still reads correctly. See
[Reference: Merge tokens](../contracts/02-merge-tokens.md) for the complete token contract.

## Related

- [Display value format](../contracts/03-display-value-format.md)
- [Reference: Merge tokens](../contracts/02-merge-tokens.md)
- [Reference: Compatibility](04-compatibility.md)
- [Configure Check Sets and Rules](../../guides/03-configure-check-sets-and-rules.md)
