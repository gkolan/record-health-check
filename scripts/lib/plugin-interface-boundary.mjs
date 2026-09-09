/** Masks Apex comments and string literals while preserving source offsets. */
export function maskApexNonCode(source) {
  let masked = "";
  let index = 0;
  let state = "code";

  while (index < source.length) {
    const character = source[index];
    const next = source[index + 1];

    if (state === "code" && character === "/" && next === "/") {
      masked += "  ";
      index += 2;
      state = "line-comment";
      continue;
    }
    if (state === "code" && character === "/" && next === "*") {
      masked += "  ";
      index += 2;
      state = "block-comment";
      continue;
    }
    if (state === "code" && character === "'") {
      masked += " ";
      index++;
      state = "string";
      continue;
    }
    if (state === "line-comment") {
      masked += character === "\n" ? "\n" : " ";
      index++;
      if (character === "\n") state = "code";
      continue;
    }
    if (state === "block-comment") {
      if (character === "*" && next === "/") {
        masked += "  ";
        index += 2;
        state = "code";
      } else {
        masked += character === "\n" ? "\n" : " ";
        index++;
      }
      continue;
    }
    if (state === "string") {
      if (character === "\\" && next !== undefined) {
        masked += next === "\n" ? " \n" : "  ";
        index += 2;
      } else {
        masked += character === "\n" ? "\n" : " ";
        index++;
        if (character === "'") state = "code";
      }
      continue;
    }

    masked += character;
    index++;
  }

  return masked;
}

function findLine(source, offset) {
  return source.slice(0, offset).split("\n").length;
}

function prohibitedInterfacePredicates(source, label) {
  const findings = [];
  for (const match of source.matchAll(
    /\binstanceof\s+RecordHealthCheckPlugin\b/g
  )) {
    findings.push(
      `${label}:${findLine(source, match.index)}: plugin compatibility must use the protected guarded cast, not instanceof.`
    );
  }
  return findings;
}

/** Verifies the two dynamic plugin-loading boundaries retain their safe shape. */
export function checkPluginInterfaceBoundaries({
  dispatchSource,
  resolverSource
}) {
  const dispatch = maskApexNonCode(dispatchSource);
  const resolver = maskApexNonCode(resolverSource);
  const findings = [
    ...prohibitedInterfacePredicates(
      dispatch,
      "RecordHealthCheckPluginDispatch.cls"
    ),
    ...prohibitedInterfacePredicates(
      resolver,
      "RecordHealthCheckApexPluginResolver.cls"
    )
  ];

  const constructionFailure = dispatch.search(
    /\bif\s*\(\s*constructionFailure\s*!=\s*null\s*\)/
  );
  const guardedCast = dispatch.search(
    /\btry\s*\{\s*return\s*\(\s*RecordHealthCheckPlugin\s*\)\s*instance\s*;\s*\}\s*catch\s*\(\s*TypeException\s+\w+\s*\)\s*\{\s*return\s+null\s*;\s*\}/s
  );
  if (
    guardedCast < 0 ||
    constructionFailure < 0 ||
    guardedCast < constructionFailure
  ) {
    findings.push(
      "RecordHealthCheckPluginDispatch.cls: instantiate must cast only after constructor failure and side-effect handling, catching only TypeException around the cast."
    );
  }

  if (/\bObject\s+instance\b/.test(resolver)) {
    findings.push(
      "RecordHealthCheckApexPluginResolver.cls: keep the validated plugin typed as RecordHealthCheckPlugin through the cache handoff."
    );
  }
  if (/\.newInstance\s*\(/.test(resolver)) {
    findings.push(
      "RecordHealthCheckApexPluginResolver.cls: plugin construction must go through RecordHealthCheckPluginDispatch.instantiate."
    );
  }
  if (
    !/RecordHealthCheckPluginDispatch\s*\.\s*instantiate\s*\(/.test(resolver)
  ) {
    findings.push(
      "RecordHealthCheckApexPluginResolver.cls: resolver must retain the protected dispatcher construction boundary."
    );
  }

  return findings;
}
