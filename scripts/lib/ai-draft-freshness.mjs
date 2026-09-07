/**
 * Decides whether the recorded low-cost-model evidence still describes the
 * prompts in the working tree.
 *
 * The release contract is that the cheapest model an administrator can reach
 * produces saveable Check configuration from the current prompts. Recorded
 * answers prove that only for the prompt they were recorded from, so an edit to
 * a prompt makes its recording evidence of nothing. Comparing fingerprints
 * turns that into a failure a release cannot walk past: re-record with
 * `npm run check:ai-model-drafts`, which calls the model for real.
 *
 * This runs offline. The live call belongs to the recording script; this only
 * refuses to believe a recording that no longer matches its prompt.
 */

/**
 * Reports recordings that are missing, stale, or made with the wrong model.
 *
 * @param {{recordings: Record<string, {file: string, model: string,
 *   promptSha256: string}>}} manifest The recorded evidence manifest.
 * @param {Map<string, string>} fingerprints Evaluation Type slug to the
 *   fingerprint of the prompt block in the working tree.
 * @param {string} lowestCostModel The model the release gate holds prompts to.
 * @param {(file: string) => boolean} exists Whether a recorded file is present.
 * @returns {string[]} Human-readable problems.
 */
export function freshnessProblems(
  manifest,
  fingerprints,
  lowestCostModel,
  exists
) {
  const problems = [];
  const recordings = manifest?.recordings ?? {};
  for (const [type, fingerprint] of fingerprints) {
    const recording = recordings[type];
    if (!recording) {
      problems.push(
        `No ${lowestCostModel} recording for the ${type} prompt; run ` +
          `npm run check:ai-model-drafts`
      );
      continue;
    }
    if (recording.model !== lowestCostModel) {
      problems.push(
        `The ${type} recording is from ${recording.model}, not the ` +
          `lowest-cost model ${lowestCostModel}; a more capable model proves ` +
          `less about the prompt`
      );
    }
    if (!exists(recording.file)) {
      problems.push(
        `tests/ai-drafts/${recording.file} is recorded in recorded.json but ` +
          `missing from the folder`
      );
      continue;
    }
    if (recording.promptSha256 !== fingerprint) {
      problems.push(
        `The ${type} prompt changed since ${recording.file} was recorded on ` +
          `${recording.recordedAt ?? "an unrecorded date"}; re-record it with ` +
          `npm run check:ai-model-drafts before releasing`
      );
    }
  }
  for (const type of Object.keys(recordings)) {
    if (!fingerprints.has(type)) {
      problems.push(
        `recorded.json describes ${type}, which is not an Evaluation Type ` +
          `prompt; remove the stale recording`
      );
    }
  }
  return problems;
}
