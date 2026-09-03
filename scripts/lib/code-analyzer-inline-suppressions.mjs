const INLINE_MARKER =
  /code-analyzer-suppress|@SuppressWarnings|NOPMD|sfge-(?:disable|ignore)/i;
const CODE_ANALYZER_MARKER =
  /code-analyzer-suppress(?:-[a-z-]+)?\s+([^:]+):\s*(.+)$/i;
const APPROVED_APEX_WARNINGS =
  "@SuppressWarnings('PMD.IfStmtsMustUseBraces,PMD.IfElseStmtsMustUseBraces')";

export function inspectInlineSuppressions(file, source) {
  const entries = [];
  const errors = [];
  for (const [index, rawLine] of source.split(/\r?\n/).entries()) {
    const marker = rawLine.trim();
    if (!INLINE_MARKER.test(marker)) continue;

    entries.push({ file, marker });
    if (/code-analyzer-suppress/i.test(marker)) {
      const parsed = marker.match(CODE_ANALYZER_MARKER);
      if (!parsed) {
        errors.push(
          `${file}:${index + 1}: malformed Code Analyzer suppression`
        );
        continue;
      }
      if (parsed[1].trim().length < 3 || parsed[2].trim().length < 20) {
        errors.push(
          `${file}:${index + 1}: suppression requires a specific rule and a review reason of at least 20 characters`
        );
      }
      if (/\b(?:all|recommended|security|appexchange)\b/i.test(parsed[1])) {
        errors.push(
          `${file}:${index + 1}: broad inline suppression selectors are prohibited`
        );
      }
    } else if (marker.includes("@SuppressWarnings")) {
      if (marker !== APPROVED_APEX_WARNINGS) {
        errors.push(
          `${file}:${index + 1}: only the exact reviewed brace-style Apex warning suppression is permitted`
        );
      }
    } else {
      errors.push(
        `${file}:${index + 1}: legacy NOPMD/SFGE inline markers are prohibited; use a rule-specific Code Analyzer marker with a reason`
      );
    }
  }
  return { entries, errors };
}

export function compareInlineSuppressionInventory(actual, expected) {
  const canonical = (entries) =>
    [...entries]
      .map(({ file, marker }) => ({ file, marker }))
      .sort((left, right) =>
        `${left.file}\0${left.marker}`.localeCompare(
          `${right.file}\0${right.marker}`
        )
      );
  const actualCanonical = canonical(actual);
  const expectedCanonical = canonical(expected);
  return JSON.stringify(actualCanonical) === JSON.stringify(expectedCanonical)
    ? []
    : [
        "tracked inline-suppression inventory differs from source; review the change and regenerate the inventory"
      ];
}
