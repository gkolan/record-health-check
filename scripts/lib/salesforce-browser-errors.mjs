export function isKnownFirefoxBuilderShellErrors(browserName, errors) {
  const firstStack = errors?.[0]?.stack ?? "";
  return (
    browserName === "firefox" &&
    errors.length >= 2 &&
    errors[0].name === "uncaught exception" &&
    errors[0].message === "Object" &&
    firstStack.includes("_getServerData") &&
    /https:\/\/[^/\s)]+\.static\.lightning\.force\.com\/[^\s)]*\/apppart\d+-\d+\.js:\d+:\d+/.test(
      firstStack
    ) &&
    errors
      .slice(1)
      .every(
        (error) =>
          error.name === "uncaught exception" &&
          error.message === "Object" &&
          error.stack?.trim() === "uncaught exception: Object"
      )
  );
}
