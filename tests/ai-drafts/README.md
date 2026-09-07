# Recorded AI drafts

The prompts in [Draft configuration with AI](../../docs/build-checks/draft-with-ai/) exist so that
an inexpensive model returns Check configuration an administrator can actually save. That claim is
only worth what a model really produces, so this folder holds one recorded answer per Evaluation
Type and `npm run check:ai-prompts` re-validates every one of them against
`Record_Health_Check__mdt` and `Record_Health_Check_Set__mdt`.

| File                     | Input                                                | What it proves                                                |
| ------------------------ | ---------------------------------------------------- | ------------------------------------------------------------- |
| `requirement-<type>.txt` | The administrator's message, one per Evaluation Type | The requirement a reader would paste after the prompt         |
| `<model>-<type>.md`      | That model's complete answer                         | The prompt produced a saveable Check for that Evaluation Type |

The gate reads the Check table the prompts require, then reports invented fields, Setup labels
stored where a stored value belongs, fields the Evaluation Type does not use, missing required
fields, merge tokens on surfaces that reject them, and values past their field length. A draft that
cannot be parsed at all is also a failure: the prompt asked for that table.

## The release gate

`npm run release:preflight` runs `check:ai-model-drafts`, which calls the lowest-cost model once per
Evaluation Type against the prompts in that commit, saves the answers here, and validates them. It
needs `ANTHROPIC_API_KEY` and fails without one: a live call is the only way to test what the model
really does, so a release that cannot make the call does not get to skip the claim.

`recorded.json` names, for each Evaluation Type, the model that answered and a fingerprint of the
exact prompt block it answered. `npm run check:ai-prompts` compares those fingerprints with the
prompts in the working tree, so editing a prompt turns its recording into evidence about an older
prompt and fails the gate until it is re-recorded. That is what keeps the claim tied to the code
being released rather than to whatever the prompts said when someone last ran the model.

The lowest-cost model is declared once, as `LOWEST_COST_MODEL` in
[`scripts/lib/ai-draft-validation.mjs`](../../scripts/lib/ai-draft-validation.mjs). Evidence from a
more capable model is rejected: it would make the gate easier to pass and prove less.

## Re-record after changing a prompt

```bash
ANTHROPIC_API_KEY=... npm run check:ai-model-drafts
```

To try a different model beside the recorded one, name it:

```bash
ANTHROPIC_API_KEY=... node scripts/release/draft_with_model.mjs --type query --model <model id>
```

The file name records which model answered, so an older or cheaper model's evidence sits beside the
current one rather than replacing it.

Do not hand-edit a recorded draft. It is evidence of what a model returned; correcting it by hand
hides the prompt defect it found. Fix the prompt and record the answer again.
