# Recorded AI drafts

The prompts in [Draft configuration with AI](../../docs/build-checks/draft-with-ai/) exist so that
an assistant returns Check configuration an administrator can actually save. This folder holds one
provider-neutral reference answer per Evaluation Type, and `npm run check:ai-prompts` validates
every one of them against
`Record_Health_Check__mdt` and `Record_Health_Check_Set__mdt`.

| File                     | Input                                                | What it proves                                        |
| ------------------------ | ---------------------------------------------------- | ----------------------------------------------------- |
| `requirement-<type>.txt` | The administrator's message, one per Evaluation Type | The requirement a reader would paste after the prompt |
| `reference-<type>.md`    | Reviewed provider-neutral answer                     | A saveable Check for that Evaluation Type             |

The gate reads the Check table the prompts require, then reports invented fields, Setup labels or
literal `N/A` stored where a deployable value belongs, fields the Evaluation Type does not use,
missing required fields, merge tokens on surfaces that reject them, and values past their field
length. It requires `FormulaResultType__c` on every draft, with `AUTO` as the portable default. A
draft that cannot be parsed at all is also a failure: the prompt asked for that table.

## The release gate

`npm run release:preflight` runs `check:ai-prompts` entirely offline. It checks prompt structure,
field names, stored picklist values, merge syntax, required capabilities, and the four reference
drafts. The gate requires exactly one `reference-<type>.md` fixture per Evaluation Type and rejects
missing or unexpected fixtures.

No provider SDK, live model call, paid account, or model credential is part of the release path.
After changing a prompt or metadata contract, update the relevant reference fixture through normal
review and run `npm run check:ai-prompts`. A reviewer may additionally paste the prompt into any
assistant, but that optional experiment is not release evidence and cannot block packaging.
