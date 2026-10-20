import { maskApexNonCode } from "./plugin-interface-boundary.mjs";

/** Names of the static @AuraEnabled methods declared in one Apex class source. */
export function auraEnabledStaticMethods(source) {
  // Comments are masked to whitespace, so a commented-out declaration is never
  // counted and a comment between the annotation and the method is skipped.
  return [
    ...maskApexNonCode(source).matchAll(
      /@AuraEnabled\b(?:\s*\([^)]*\))?(?:\s*@\w+(?:\s*\([^)]*\))?)*\s+((?:(?:global|public|private|protected|static|override|virtual)\s+)+)[\w<>,.\s]+?\s+(\w+)\s*\(/gi
    )
  ]
    .filter(([, modifiers]) => /\bstatic\b/i.test(modifiers))
    .map(([, , method]) => method);
}
